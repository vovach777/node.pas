unit np.HttpConnect;

interface
 uses np.core, np.EventEmitter, np.httpParser, Generics.Collections, sysUtils,
      np.buffer, np.url, np.OpenSSL, np.http_parser, np.common;

 const
  ev_BeforeProcess = 1;
  ev_HeaderLoaded  = 2;
//  ev_ContentUpdated = 3;
  ev_Complete = 4;
  ev_connected = 5;
  ev_disconnected = 6;
  ev_error = 7;
  ev_destroy = 8;
  ev_connecting = 9;


 type
    THttpConnect = class;
    TBaseHttpRequest = class(TEventEmitter)
    private
       lostConnectObjectHandler : IEventHandler;
       req : TStringBuilder;
       fCookieCount: integer;
       isGet: Boolean;
       isPending: Boolean;
       isInQueue: Boolean;
       isDone: Boolean;
       //isPaused: Boolean;
       initState: (isWantBeginHeader,isWantEndHeader,isWantCookieEnd, isRdy);
    protected
    public
       request: BufferRef;
       protocol: Utf8String;
       statusCode: integer; //<0 internal reason
       statusReason: Utf8string;
       ResponseHeader: THTTPHeader;
       ResponseContent: BufferRef;
       connect: THttpConnect;
       ConnectionOwner: Boolean;
       ReqMethod : string;
       ReqPath:   string;
//       CompleteReaction: TCompleteReaction;
       procedure beginHeader(const method: string; const path: string; AkeepAlive:Boolean=true);
       procedure addHeader(const name:string; const value: string);
         procedure beginCookie;
           procedure addCookie(const name:string; const value: string);
         procedure endCookie;
       procedure endHeader(const content: BufferRef; const contentType:string);overload;
       procedure endHeader; overload;
       procedure ClearResponse;
       constructor Create(Aconnect: THttpConnect);
       destructor Destroy; override;
       procedure resume; //reuse request object again
       procedure done;   //request do not need anymore (default before ev_complete)
       procedure autoDone;
    end;

    THttpConnect = class(TEventEmitter)
    private
      Fctx: TSSL_CTX;
      FSSL : TSSL;
      Fin_bio : TBIO;
      Fout_bio: TBIO;
      Fis_init_finished: integer;
      FSSLData : TBytes;
      FData : BufferRef;
      queue: TQueue<TBaseHttpRequest>;
      con : INPTCPConnect;
      Isshutdown: Boolean;
      IsConnected: Boolean;
      isHandshake: Boolean;
      onTimeout: INPTimer;
      Fsettings : Thttp_parser_settings;
      FParser: Thttp_parser;
      Flast_header_name: string;
      Flast_header_value: string;
//      isFin: Boolean;
      procedure CheckConnect;
      procedure ProcessRequest;
      procedure do_handshake;
      procedure do_shutdown;
      procedure onPlainData(const chunk:BufferRef);
      procedure onSSLData(const chunk:BufferRef);
      procedure InternalClose;
      procedure Request(req: TBaseHttpRequest);
      procedure on_message_begin;
//      procedure on_url(const s : string);
      procedure on_status(const s : string);
      procedure on_header_field;
      procedure on_headers_complete;
      procedure on_body(const ABuf : BufferRef);
      procedure on_message_complete;
    public
      url : TURL;
      function  _GET(const Apath: string): TBaseHttpRequest;
      constructor Create(const BaseURL: string);
      procedure Shutdown;
      destructor Destroy; override;
    end;

implementation
  uses np.ut, np.netEncoding;

   function tos(const at:PAnsiChar; len: SiZE_t) : string;
   begin
      SetString(result,at,len);
   end;

   function _on_message_begin( parser: PHttp_parser) : integer; cdecl;
   begin
     THttpConnect( parser.data ).on_message_begin;
     result := 0;
   end;

//   function _on_url(parser: PHttp_parser; const at: PAnsiChar; len:SIZE_T) : integer; cdecl;
//   begin
//     THttpConnect( parser.data ).on_url(  TURL._DecodeURL( tos(at,len) ) );
//     result := 0;
//   end;

   function _on_status(parser: PHttp_parser; const at: PAnsiChar; len:SIZE_T) : integer; cdecl;
   begin
     THttpConnect(parser.data).on_status( tos(at,len) );
     result := 0;
   end;

   function _on_header_field(parser: PHttp_parser; const at: PAnsiChar; len:SIZE_T) : integer; cdecl;
   begin
   //  outputdebugStr('on_header_field "%s"', [tos(at,len)]);
     THttpConnect(  parser.data ).Flast_header_name := LowerCase( tos(at,len) );
     result := 0;
   end;

   function _on_header_value(parser: PHttp_parser; const at: PAnsiChar; len:SIZE_T) : integer; cdecl;
   begin
    // outputdebugStr('on_header_value "%s"', [tos(at,len)]);
     with THttpConnect(  parser.data ) do
     begin
   //    outputdebugStr('| %s = %s',[ Flast_header_name, tos(at,len) ] );
       //FHeaders.addSubFields( Flast_header_name,  tos(at,len) );
       Flast_header_value := tos(at,len);
       on_header_field();
       Flast_header_name := '';
       Flast_header_value := '';
     end;
     result := 0;
   end;

   function _on_headers_complete( parser: PHttp_parser) : integer; cdecl;
   begin
     THttpConnect(  parser.data ).on_headers_complete;
     result := 0;
   end;

   function _on_body(parser: PHttp_parser; const at: PAnsiChar; len:SIZE_T) : integer; cdecl;
   begin
     THttpConnect(  parser.data ).on_body( BufferRef.CreateWeakRef(at,len) );
     result := 0;
   end;

   function _on_message_complete( parser: PHttp_parser) : integer; cdecl;
   begin
     //outputdebugStr('on_message_complete');
     THttpConnect(  parser.data ).on_message_complete();
     result := 0;
   end;

//   function _on_chunk_header( parser: PHttp_parser) : integer; cdecl;
//   begin
//     //outputdebugStr('on_chunk_header');
//     result := 0;
//   end;
//
//   function _on_chunk_complete( parser: PHttp_parser) : integer; cdecl;
//   begin
//     //outputdebugStr('on_chunk_complete');
//     result := 0;
//   end;


{ TBaseHttpRequest }

constructor THttpConnect.Create(const BaseURL: string);
var
   onSd : IEventHandler;
begin
  loop.addTask;
  inherited Create();
  queue:= TQueue<TBaseHttpRequest>.Create;
  url.Parse(BaseURL);
  onSd := loop.once(ev_loop_shutdown,
     procedure
     begin
       shutdown;
     end);
  once(ev_destroy,
       procedure
       begin
         onSd.remove;
         onSd := nil;
         if onTimeout <> nil then
         begin
           onTimeout.Clear;
           onTimeout := nil;
         end;

       end);
  http_parser_settings_init(FSettings);
  FSettings.on_message_begin := _on_message_begin;
//  FSettings.on_url := _on_url;
  FSettings.on_status := _on_status;
  FSettings.on_header_field := _on_header_field;
  FSettings.on_header_value := _on_header_value;
  FSettings.on_headers_complete := _on_headers_complete;
  FSettings.on_body := _on_body;
  FSettings.on_message_complete := _on_message_complete;
//  FSettings.on_chunk_header := _on_chunk_header;
//  FSettings.on_chunk_complete := _on_chunk_complete;
  http_parser_init(FParser, HTTP_RESPONSE);
  FParser.data := self;

//  fltc := 0;
//  fltd := 0;
//  on_(ev_connected,
//        procedure
//        begin
//          fltc := CurrentTimestamp;
//        end);
//  on_(ev_disconnected,
//       procedure
//       begin
//         fltd := CurrentTimestamp;
//       end );

end;

{ TBaseHttpRequest }


procedure TBaseHttpRequest.addHeader(const name: string; const value: string);
begin
  if initState = isWantCookieEnd then
    endCookie;
  if initState = isWantEndHeader then
    req.Append(name).Append(': ').Append(value).Append(#13).Append(#10);
end;

procedure TBaseHttpRequest.autoDone;
begin
  once(ev_Complete,
        procedure
        begin
           done;
        end);
end;

procedure TBaseHttpRequest.beginCookie;
begin
  assert( fCookieCount = 0 );
end;

procedure TBaseHttpRequest.beginHeader(const method: string; const path: string; AkeepAlive:Boolean);
begin
  ClearResponse;
  assert(assigned(connect));
  ReqMethod := method;
  initState := isWantEndHeader;
  isGet := method = 'GET';
  req.Clear;
  req.Append(method).Append(' ');
  if path = '' then
     ReqPath  := '/'
  else
     ReqPath := TNetEncoding.URL.Encode( path );

  req.Append(ReqPath);
  req.Append(' HTTP/1.1').Append(#13).Append(#10);

  addHeader('Host', connect.Url.HttpHost);
  if AkeepAlive  then
    addHeader('Connection', 'keep-alive')
  else
    addHeader('Connection', 'close');
  initState := isWantEndHeader;
end;

procedure TBaseHttpRequest.ClearResponse;
begin
  FreeAndNil(ResponseHeader);
  ResponseContent := Buffer.Null;
  protocol := '';
  statusCode := 0;
  statusReason := '';
  fCookieCount := 0;
end;

constructor TBaseHttpRequest.Create(Aconnect: THttpConnect);
begin
  inherited Create();
  //CompleteReaction := crFree;
  req := TStringBuilder.Create;
  connect := AConnect;
  lostConnectObjectHandler := connect.once(ev_destroy,
               procedure
               begin
                 connect := nil;
                 isPending := false;
                 isInQueue := false;
                 done;
               end);
//  resume;
end;

destructor TBaseHttpRequest.Destroy;
begin
  assert(not isPending);
  lostConnectObjectHandler.remove;
  FreeAndNil(req);
  FreeAndNil(ResponseHeader);
  emit(ev_destroy);
  inherited;
end;


procedure TBaseHttpRequest.done;
begin
//  assert(isPending = false);
  IsDone := true;
  if not isInQueue then
     NextTick(
         procedure
         begin
            Free;
         end);

end;

procedure TBaseHttpRequest.addCookie(const name, value: string);
begin
  if name = '' then
    exit;
  if fCookieCount > 0 then
  begin
    if initState <> isWantCookieEnd then
      exit;
    req.Append('; ');
  end
  else
  begin
    if initState <> isWantEndHeader then
      exit;
    initState := isWantCookieEnd;
    req.Append('Cookie: ');
  end;
  inc(fCookieCount);
  req.Append(name).Append('=').Append(value);
end;

procedure TBaseHttpRequest.endCookie;
begin
  if initState = isWantCookieEnd then
  begin
    req.Append(#13).append(#10);
    initState := isWantEndHeader;
  end;
end;


procedure TBaseHttpRequest.endHeader;
begin
  endHeader(Buffer.Null,'');
end;

procedure TBaseHttpRequest.resume;
begin
  if not isDone and
    not isPending then
     connect.Request(self);
end;

procedure TBaseHttpRequest.endHeader(const content: BufferRef; const contentType:string);
begin
  if initState = isWantCookieEnd then
     endCookie;

  if initState <> isWantEndHeader then
    exit;

  if contentType <> '' then
     addHeader('Content-Type', contentType);

  if (Content.length > 0) or (not isGet)  then
    addHeader('Content-Length',IntToStr( Content.length) );

  req.Append(#13).append(#10);

  request := Buffer.Create( [Buffer.Create( req.ToString, CP_USASCII ), Content] );
  initState := isRdy;
end;


procedure THttpConnect.onPlainData(const chunk: BufferRef);
var
  req: TBaseHttpRequest;
  header: BufferRef;
begin
  if (chunk.length > 0) then
    http_parser_execute(FParser,Fsettings,PAnsiChar( chunk.ref ), chunk.length);

//  if queue.Count = 0 then
//    exit;
//  req := queue.Peek;
//  assert( req.isPending );
//
//
////  if not req.isPending then
////  begin
////     req.ClearResponse;
////     req.isPending := true;
////  end;
//
//  if req.ResponseHeader <> nil then
//   optimized_append(req.ResponseContent,chunk)
//  else
//  begin
//    optimized_append(Fdata,chunk);
//    if not CheckHttpAnswer(Fdata,req.protocol,req.statusCode,req.statusReason, header, req.ResponseContent) then
//      exit;
//    req.ResponseHeader := THTTPHeader.Create(header);
//    req.emit(ev_HeaderLoaded, req);
//    Fdata.length := 0;
//  end;
//  if req.ConnectionOwner then
//  begin
//    if req.ResponseContent.length > 0 then
//      req.emit(ev_ContentUpdated, @req.ResponseContent);
//  end
//  else
//  if req.ResponseContent.length >= req.ResponseHeader.ContentLength then
//  begin
//     req.ResponseContent.length := req.ResponseHeader.ContentLength;
//     req.isPending := false;
//     queue.Dequeue;
//     req.isInQueue := false;
//     if not req.isDone then
//     begin
//       req.emit(ev_Complete, req);
//     end
//     else
//       req.free;
//     ProcessRequest; //Check next request
//  end;
end;

procedure THttpConnect.onSSLData(const chunk: BufferRef);
var
  nbytes : integer;
begin
  try
    repeat
    nbytes := BIO_write(Fin_bio,chunk.ref,chunk.length);
    assert( nbytes > 0);
    chunk.TrimL(nbytes);
    if isHandshake then
    begin
      do_handshake;
      if Fis_init_finished = 1 then
      begin
        isHandshake := false;
        FData.length := 0;
        IsConnected := true;
        emit(ev_connected, self);
        ProcessRequest;
      end;
    end;
    if not isHandshake then
    begin
      repeat
        nbytes := SSL_read(FSSL,@FSSLData[0],length(FSSLData));
        if nbytes <= 0 then
          break;
        //optimized_append(FData, BufferRef.CreateWeakRef(@FSSLData[0],nbytes));
        onPlainData(BufferRef.CreateWeakRef(@FSSLData[0],nbytes));
      until false;
    end;
    until chunk.length = 0;
  except
    con.Clear;
  end;
end;

procedure THttpConnect.on_body(const ABuf: BufferRef);
var
  req : TBaseHttpRequest;
begin
  if (queue.Count >0) then
  begin
    req := queue.Peek;
    optimized_append( req.ResponseContent, ABuf);
  end;
end;

procedure THttpConnect.on_headers_complete;
var
  req : TBaseHttpRequest;
begin
  OutputDebugStr('on_headers_complete');
  if (queue.Count >0) then
  begin
    req := queue.Peek;
    req.ResponseHeader.parse(Buffer.Null);
    req.emit(ev_HeaderLoaded, req);
  end;
end;

procedure THttpConnect.on_header_field;
var
  req : TBaseHttpRequest;
begin
  OutputDebugStr('on_header_field %s=%s',[Flast_header_name, Flast_header_value]);
  if (queue.Count >0) then
  begin
    req := queue.Peek;
    if assigned( req.ResponseHeader ) then
       req.ResponseHeader.addSubFields( Flast_header_name, Flast_header_value );
  end;
end;

procedure THttpConnect.on_message_begin;
var
  req : TBaseHttpRequest;
begin
   Flast_header_name := '';
   Flast_header_value := '';
   OutputDebugStr('on_message_begin');
  if (queue.Count >0) then
  begin
    req := queue.Peek;
    if assigned( req.ResponseHeader ) then
      req.ResponseHeader.Clear
    else
      req.ResponseHeader := THTTPHeader.Create(Buffer.Null);
  end;

end;

procedure THttpConnect.on_message_complete;
var
  req : TBaseHttpRequest;
begin
   OutputDebugStr('on_message_complete');
   if queue.Count > 0 then
   begin
     req := queue.Peek;
     req.isPending := false;
     queue.Dequeue;
     req.isInQueue := false;
     if not req.isDone then
     begin
       req.emit(ev_Complete, req);
     end
     else
       req.free; //no one interest with reques...
     ProcessRequest; //Check next request
   end;
end;

procedure THttpConnect.on_status(const s: string);
var
  req : TBaseHttpRequest;
begin
   if queue.Count > 0 then
   begin
     req := queue.Peek;
     req.statusCode := ord ( http_parser_get_status_code( FParser ) );
     req.statusReason := s;
     req.protocol := Format('HTTP/%u.%u',[ FParser.http_major, FParser.http_minor ]);
   OutputDebugStr(Format('on_status: %u %s (%s)',[req.statusCode, req.statusReason, req.protocol]));
   end;
end;

//procedure THttpConnect.on_url(const s: string);
//begin
//   OutputDebugStr('on_url: '+s);
//end;

procedure THttpConnect.Request(req: TBaseHttpRequest);
begin
   if (not IsShutdown) and (not req.isInQueue) then
   begin
         queue.Enqueue(req);
         req.isInQueue := true;
         begin
           NextTick(
             procedure
             begin
                   ProcessRequest;
             end);
         end;
  end;
end;

destructor THttpConnect.Destroy;
begin
  Isshutdown := true;
  if assigned(con) then
  begin
    con.setOnConnect(nil);
    con.SetonClose(nil);
    con.setOnError(nil);
    con.setOnData(nil);
    con.setOnEnd(nil);
    if assigned(con) then
       do_shutdown;
    con.Clear;
    InternalClose;
  end;
  emit(ev_destroy,self);
//  while queue.Count > 0 do
//  begin
//    req := queue.Dequeue;
//    req.isPending := false;
//    req.isInQueue := false;
//    req.isDone := true;
//    req.emit(ev_Complete);
//    req.connect := nil;
//    if req.CompleteReaction = crFree then
//       req.Free;
//  end;
  freeAndNil(queue);
  if assigned(FCtx) then
  begin
    SSL_CTX_free(Fctx);
    Fctx := nil;
  end;
  inherited;
  loop.removeTask;
end;

procedure THttpConnect.CheckConnect;
var
  closeBadly : boolean;
begin
  if (not Isshutdown) and (not assigned(con)) and (queue.Count > 0) and not assigned(onTimeout) then
  begin
    if url.Schema = 'https' then
    begin
      if not assigned(Fctx) then
      begin
        Fctx := SSL_CTX_new( TLS_client_method());
        assert(assigned(Fctx));
        SSL_CTX_set_verify(FCTX, SSL_VERIFY_NONE, nil);
      end;
    end
    else
    if url.Schema <> 'http' then
      raise ENotSupportedException.CreateFmt('unknown url schema: "%s"',[url.Schema]);
    emit(ev_connecting,self);
    http_parser_init(FParser, HTTP_RESPONSE);
    FParser.data := self;


    closeBadly := false;
    con := TNPTCPStream.CreateConnect;
    con.set_nodelay(true);
//    con.bind(url.HostName,url.Port);
    con.SetonClose(
        procedure
        var
          delay : Boolean;
        begin
          delay := not IsConnected or closeBadly;
          InternalClose;
          if (queue.Count > 0) and (queue.Peek.ConnectionOwner) then
             Shutdown
          else
          begin
            if delay then
            begin
               onTimeout := SetTimeout(
                   procedure
                   begin
                     onTimeout := nil;
                     CheckConnect;
                   end, 100);
               onTimeout.unref;
            end
            else
              CheckConnect;
          end;
        end);
    con.setOnError(
        procedure (err:PNPError)
        begin
          closeBadly := true;
          emit(ev_error, @err);
        end
       );

    if assigned(Fctx) then
    begin
      con.setOnConnect(
        procedure
        begin
            isConnected:=true;
            isHandshake:=true;
            Fin_bio := BIO_new(BIO_s_mem());
            assert(Fin_bio <> nil);
            BIO_set_mem_eof_return(Fin_bio,-1);
            Fout_bio := BIO_new(BIO_s_mem());
            assert(Fout_bio <> nil);
            BIO_set_mem_eof_return(Fout_bio,-1);
            FSSL  := SSL_new(FCtx);
            assert(assigned( FSSL ) );
            SSL_set_connect_state(FSSL);
            SSL_set_bio(FSSL, Fin_bio, Fout_bio);
            setLength( FSSLData, 4096);
            con.setOnData(
              procedure (data:PBufferRef)
              begin
                onSSLData(data^);
              end);
            do_handshake;
        end);
    end
    else
    begin
      con.setOnConnect(
          procedure
          begin
            con.setOnData(
            procedure (data:PBufferRef)
            begin
              onPlainData(data^);
            end);
            IsConnected := true;
            emit(ev_connected,self);
            Fdata.length := 0;
            ProcessRequest;
          end);
    end;
    con.connect(url.HostName,url.Port);
  end;
end;

procedure THttpConnect.ProcessRequest;
var
  req : TBaseHttpRequest;
  nbytes : integer;
begin
  if Isshutdown then
   exit;
  if not IsConnected then
  begin
      CheckConnect;
      exit;
  end;
  while (not Isshutdown) and (queue.Count > 0) do
  begin
      req := queue.Peek;
      if req.isPending then
          exit;
      req.ClearResponse;
      assert(assigned(req));
      req.emit(ev_BeforeProcess); //dymanic request handler
      emit( ev_BeforeProcess, req);
      if req.isDone then
      begin
          queue.Dequeue;
          continue;
      end;
      if req.request.length = 0 then //error dynamic request
      begin
        queue.Dequeue;
        req.statusCode := -1;
        req.statusReason := 'no request header';
        req.isPending := false;
        req.isInQueue := false;
        req.emit(ev_Complete);
        continue;
      end;
      req.isPending := true;
      if assigned(FSSL) then
      begin
        nbytes := SSL_write(Fssl,req.request.ref, req.request.length);
        assert( nbytes = req.request.length);
        repeat
          nbytes := BIO_read(Fout_bio, @FSSLData[0] , length(FSSLData));
          if nbytes <= 0 then
            break;
          con.write(BufferRef.CreateWeakRef( @FSSLData[0], nbytes) );
        until false;
      end
      else
      begin
        con.write( req.request );
        ///req.request := Buffer.Null;
      end;
      exit;
  end;
end;


procedure THttpConnect.Shutdown;
begin
  if not IsShutdown then
  begin
    IsShutdown := true;
    loop.NextTick(
      procedure
        begin
          free;
        end);
  end;
end;

function THttpConnect._GET(const Apath: string): TBaseHttpRequest;
begin
   result := TBaseHttpRequest.Create(self);
   result.beginHeader('GET',Apath);
   result.endHeader();
   result.resume;
end;

procedure THttpConnect.do_handshake;
var
  err : integer;
  nbytes : integer;
begin
  if Fis_init_finished <> 1 then
  begin
    Fis_init_finished := SSL_do_handshake(Fssl);
    if  Fis_init_finished <> 1 then
    begin
       err := SSL_get_error(Fssl, Fis_init_finished);
       //WriteLn(Format('handshake error: %d',[err]));
       if Fis_init_finished = 0 then
       begin
         //WriteLn(Format('fatal code:%d',[err]));
         abort;
       end;
       if err = SSL_ERROR_WANT_READ then
       begin
//                      len := BIO_read(Fout_bio,@FSSLData[0],length(FSSLData));
//                      assert(len > 0);
//                      write(@FSSLData[0],len);
       end
       else
       if err = SSL_ERROR_WANT_WRITE then
       begin
         //WriteLn('SSL_ERROR_WANT_WRITE');
       end
       else
         abort;
    end
    else
    begin
    end;
  end;
  repeat
    nbytes := BIO_read(Fout_bio,@FSSLData[0],length(FSSLData));
    if nbytes <= 0 then
      break;
    con.write(BufferRef.CreateWeakRef( @FSSLData[0],nbytes) );
  until false;
end;

procedure THttpConnect.do_shutdown;
var
  res : integer;
  len : integer;
begin
  if isConnected then
  begin
    if assigned(FSSL) then
    begin
      res := SSL_shutdown(Fssl);
      if res = 0 then
        res := SSL_shutdown(Fssl);
  //    if res < 0 then
  //      Rescode := SSL_get_error(FSSL,res);
      repeat
         len := BIO_read(Fout_bio,@FSSLData[0],length(FSSLData));
         if len <= 0 then
         begin
           break;
         end;
         con.write(BufferRef.CreateWeakRef( @FSSLData[0],len) );
       until false;
       con.setOnData(nil);
       con.shutdown(nil);
    end
    else
    begin
      con.setOnData(nil);
      con.shutdown(nil);
    end;
  end;
  con.Clear;
end;

procedure THttpConnect.InternalClose;
begin
   if http_message_needs_eof(FParser) <> 0 then
      http_parser_execute(FParser,Fsettings,nil,0);

  ClearTimer( onTimeout );

  if isConnected then
  begin
     emit(ev_disconnected,self);
  end;
  if assigned(con) then
  begin
    con := nil;
    Fis_init_finished := 0;
    isConnected := false;
    Fdata.length := 0;
    if assigned(Fssl) then
      SSL_free(Fssl);
    Fssl := nil;
  end;
end;

{ THttpRequest }


end.

