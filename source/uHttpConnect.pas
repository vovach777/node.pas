unit uHttpConnect; {experimental}

interface
 uses duv.tcp,duv.tcp.client, np.httpParser, Generics.Collections, sysUtils,
      np.buffer, np.url, np.OpenSSL, duv.types;

 const
  ev_BeforeProcess = 1;
  ev_HeaderLoaded  = 2;
  ev_ContentUpdated = 3;
  ev_Complete = 4;

 type
    THttpConnect = class;
    TCompleteReaction = (crNothing, crFree, crReuse);
    TBaseHttpRequest = class(TEventEmmiter)
    private
       req : TStringBuilder;
       fCookieCount: integer;
       isGet: Boolean;
       initState: (isWantBeginHeader,isWantEndHeader,isWantCookieEnd, isRdy);
    protected
       procedure onBeforeProcess; virtual;
       procedure onHeaderLoaded; virtual;
       procedure onContentUpdated; virtual;
       procedure onComplete; virtual;
    public
       request: BufferRef;
       protocol: Utf8String;
       statusCode: integer; //<0 internal reason
       statusReason: Utf8string;
       ResponseHeader: THTTPHeader;
       ResponseContent: BufferRef;
       connect: THttpConnect;
       ReqMethod : string;
       ReqPath:   string;
       CompleteReaction: TCompleteReaction;
       procedure beginHeader(const method: string; const path: string; AkeepAlive:Boolean=true);
       procedure addHeader(const name:string; const value: string);
         procedure beginCookie;
           procedure addCookie(const name:string; const value: string);
         procedure endCookie;
       procedure endHeader(const content: BufferRef; const contentType:string);overload;
       procedure endHeader; overload;
       constructor Create(Aconnect: THttpConnect);
       destructor Destroy; override;
    end;

    THttpRequest = class(TBaseHttpRequest)
    end;

    THttpConnect = class
    private
      Fctx: TSSL_CTX;
      FSSL : TSSL;
      Fin_bio : TBIO;
      Fout_bio: TBIO;
      Fis_init_finished: integer;
      FSSLData : TBytes;
      FData : BufferRef;
      queue: TQueue<TBaseHttpRequest>;
      con : IDUVTCPConnect;
      Isshutdown: Boolean;
      IsConnected: Boolean;
      isHandshake: Boolean;
//      isFin: Boolean;
      procedure CheckConnect;
      procedure ProcessRequest;
      procedure do_handshake;
      procedure do_shutdown;
      procedure onPlainData(const chunk:BufferRef);
      procedure onSSLData(const chunk:BufferRef);
      procedure InternalClose;
    public
      url : TURL;
      constructor Create(const BaseURL: string);
      procedure Request(req: TBaseHttpRequest); overload;
      procedure Request(doReq: TProc<THttpRequest>); overload;
      procedure Shutdown;
      destructor Destroy; override;
    end;

implementation
  uses np.ut, np.netEncoding, np.MainLoop;

{ TBaseHttpRequest }

constructor THttpConnect.Create(const BaseURL: string);
begin
//  application.addTask;
  queue:= TQueue<TBaseHttpRequest>.Create;
  url.Parse(BaseURL);
end;

{ TBaseHttpRequest }


procedure TBaseHttpRequest.addHeader(const name: string; const value: string);
begin
  if initState = isWantCookieEnd then
    endCookie;
  if initState = isWantEndHeader then
    req.Append(name).Append(': ').Append(value).Append(#13).Append(#10);
end;

procedure TBaseHttpRequest.beginCookie;
begin
  assert( fCookieCount = 0 );
end;

procedure TBaseHttpRequest.beginHeader(const method: string; const path: string; AkeepAlive:Boolean);
begin
  assert(assigned(connect));
  ReqMethod := method;
  ReqPath  := path;
  initState := isWantEndHeader;
  FreeAndNil(ResponseHeader);
  ResponseContent := Buffer.Null;
  protocol := '';
  statusCode := 0;
  fCookieCount := 0;
  isGet := method = 'GET';
  req.Clear;
  req.Append(method).Append(' ');
  if path = '' then
     req.Append('/')
  else
     req.Append(TNetEncoding.URL.Encode( path ));
  req.Append(' HTTP/1.1').Append(#13).Append(#10);

  addHeader('Host', connect.Url.HttpHost);
  if AkeepAlive  then
    addHeader('Connection', 'keep-alive')
  else
    addHeader('Connection', 'close');
  initState := isWantEndHeader;
end;

constructor TBaseHttpRequest.Create(Aconnect: THttpConnect);
begin
  inherited Create(mainLoop);
  req := TStringBuilder.Create;
  connect := AConnect;
end;

destructor TBaseHttpRequest.Destroy;
begin
  FreeAndNil(req);
  FreeAndNil(ResponseHeader);
  inherited;
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

procedure TBaseHttpRequest.onBeforeProcess;
begin
  id := ev_BeforeProcess;
  execute;
end;

procedure TBaseHttpRequest.onComplete;
begin
//  CompleteReaction := crFree;
//  connect := nil;
  id := ev_Complete;
  execute;
end;

procedure TBaseHttpRequest.onContentUpdated;
begin
  id := ev_ContentUpdated;
  execute;
end;

procedure TBaseHttpRequest.onHeaderLoaded;
begin
  id := ev_HeaderLoaded;
  execute;
end;

procedure THttpConnect.onPlainData(const chunk: BufferRef);
var
  req: TBaseHttpRequest;
  header: BufferRef;
  cr: TCompleteReaction;
begin
  if queue.Count = 0 then
    exit;
  req := queue.Peek;
  if req.ResponseHeader <> nil then
   optimized_append(req.ResponseContent,chunk)
  else
  begin
    optimized_append(Fdata,chunk);
    if not CheckHttpAnswer(Fdata,req.protocol,req.statusCode,req.statusReason, header, req.ResponseContent) then
      exit;
    req.ResponseHeader := THTTPHeader.Create(header);
    req.onHeaderLoaded;
    Fdata.length := 0;
  end;
  if req.ResponseContent.length >= req.ResponseHeader.ContentLength then
  begin
     req.ResponseContent.length := req.ResponseHeader.ContentLength;
     req.CompleteReaction := crFree;
     req.onComplete;
     case req.CompleteReaction of
       crFree:
          queue.Dequeue.Free;
       crReuse:;
       else
          queue.Dequeue;
     end;
     ProcessRequest;
  end;
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

procedure THttpConnect.Request(req: TBaseHttpRequest);
begin
  queue.Enqueue(req);
  if (not IsShutdown) and (queue.Count=1) then
    ProcessRequest;
end;

destructor THttpConnect.Destroy;
var
  req: TBaseHttpRequest;
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
  while queue.Count > 0 do
  begin
    req := queue.Dequeue;
    req.CompleteReaction := crFree;
    req.onComplete;
    req.connect := nil;
    if req.CompleteReaction = crFree then
       req.Free;
  end;
  freeAndNil(queue);
  if assigned(FCtx) then
  begin
    SSL_CTX_free(Fctx);
    Fctx := nil;
  end;
//  application.removeTask;
  inherited;
end;

procedure THttpConnect.CheckConnect;
begin
  if (not Isshutdown) and (not assigned(con)) and (queue.Count > 0) then
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
    con := TDUVTCPStream.CreateConnect(mainLoop);
    con.set_nodelay(true);
//    con.bind(url.HostName,url.Port);
    con.SetonClose(
        procedure
        begin
          InternalClose;
          CheckConnect;
        end);

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
              procedure (data: PByte; Len:Cardinal)
              begin
                onSSLData(BufferRef.CreateWeakRef(data,len));
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
            procedure (data:PByte;Len:Cardinal)
            begin
              onPlainData(BufferRef.CreateWeakRef(data,len));
            end);
            IsConnected := true;
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
  if (not Isshutdown) and (queue.Count > 0) then
  begin
    if IsConnected then
    begin
      req := queue.Peek;
      req.onBeforeProcess;
      if req.request.length = 0 then
      begin
        req.statusCode := -1;
        req.statusReason := 'no request header';
        req.CompleteReaction := crFree;
        req.onComplete();
        case req.CompleteReaction of
           crFree:
             queue.Dequeue.Free;
           crReuse:
             mainLoop.SetImmediate(
                 procedure
                 begin
                   ProcessRequest;
                  end );
           else
             queue.Dequeue;
        end;
      end
      else
      begin
          if assigned(FSSL) then
          begin
            nbytes := SSL_write(Fssl,req.request.ref, req.request.length);
            assert( nbytes = req.request.length);
            repeat
              nbytes := BIO_read(Fout_bio, @FSSLData[0] , length(FSSLData));
              if nbytes <= 0 then
                break;
              con.write(@FSSLData[0], nbytes);
            until false;
          end
          else
          begin
            con.write( req.request.ref, req.request.length );
            req.request := Buffer.Null;
          end;
      end;
    end
    else
      CheckConnect;
  end;
end;

procedure THttpConnect.Request(doReq: TProc<THttpRequest>);
var
  req: THttpRequest;
begin
  req := THttpRequest.Create(self);
  req.add(
     procedure
     begin
       doReq( req );
     end);
   Request(req);
end;

procedure THttpConnect.Shutdown;
begin
  IsShutdown := true;
  free;
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
    con.write(@FSSLData[0],nbytes);
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
         con.write(@FSSLData[0],len);
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

