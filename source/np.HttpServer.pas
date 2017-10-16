unit np.HttpServer;

interface
  uses sysUtils, np.Core, np.httpParser, np.url, np.buildData, np.buffer,
        np.HttpUt, np.OpenSSL, np.libuv;

  type
     IHttpRequest = interface
     ['{F951A32E-8461-4B71-9270-A37CA57899E9}']
        function GetReqBody : BufferRef;
        function GetReqPath : Utf8string;
        function GetReqMethod : Utf8string;
        function GetReqHeaders : THTTPHeader;
        property Body : BufferRef read GetReqBody;
        property Path : Utf8string read GetReqPath;
        property Method : Utf8string read GetReqMethod;
        property Headers: THTTPHeader read GetReqHeaders;
     end;

     IHttpResponse = interface
     ['{21A7E87B-CC5A-45CB-A9F5-5C64EF696AB5}']
        procedure writeHeader(code:Integer);
        procedure addHeader(const name: Utf8string; value: Utf8string);
        procedure finish(data: BufferRef);
     end;

     IHttpClient = interface(INPTCPStream)
     ['{59E92408-C62D-4463-AAA1-C759CD776159}']
        procedure setOnRequest(proc: TProc);
     end;

     IHttpServer = interface(INPTCPServer)
     ['{FE95B0AB-BBD4-4BB3-8B59-55842AFEDE98}']
         procedure setOnRequest( aOnReq: TProc<IHttpRequest, IHttpResponse> );
         procedure setTimeout(value: int64);
         function getTimeout : int64;
         property timeout : int64 read GetTimeout write SetTimeout;
     end;


     THttpServer = class(TNPTCPServer, IHttpServer)
     private
        FOnRequest : TProc<IHttpRequest, IHttpResponse>;
        FTimeout : int64;
        Fctx : TSSL_CTX;
         procedure setTimeout(value: int64);
         function getTimeout : int64;
         procedure setOnRequest( aOnReq: TProc<IHttpRequest, IHttpResponse> );
     public
        constructor Create(const addr : string; port : word; isSec:Boolean; const certFn,keyFn:Utf8String);
        destructor Destroy; override;
     end;

implementation

type
     THttpClient = class(TNPTCPStream, IHttpClient, IHttpRequest, IHttpResponse)
     type
       TParseState = (psHeader,psBody,psProcess, psUpgrade);
     private
        FKeepAlive : Boolean;
        Fstate : TParseState;
        FMethod : Utf8string;
        FUri : Utf8string;
        FProtocol : Utf8string;
        FHeaders : THTTPHeader;
        FOnRequest : TProc;
        FBody : bufferRef;
        FResponse: TBuildData;
        FBuf : BufferRef;
        FTimeout: INPTimer;
        FTimeoutValue : int64;
        FSSL : TSSL;
        Fin_bio : TBIO;
        Fout_bio: TBIO;
        Fis_init_finished: integer;
        FSSLData : TBytes;
        procedure InitTimeout;
        procedure writeHeader(code:Integer);
        procedure addHeader(const name: Utf8string; value: Utf8string);
        procedure finish(data: BufferRef);
        function ProcessNext : Boolean;
        procedure processBuf;
        procedure setOnRequest(proc: TProc);
        procedure onClose; override;
        procedure do_handshake;
        procedure do_shutdown;
        function GetReqBody : BufferRef;
        function GetReqPath : Utf8string;
        function GetReqMethod : Utf8string;
        function GetReqHeaders : THTTPHeader;
     public
        constructor Create( server: INPTCPServer; Actx : TSSL_CTX);
        destructor Destroy;override;
     end;


{ THttpServer }

constructor THttpServer.Create(const addr: string; port: word; isSec:Boolean; const certFn,keyFn:Utf8String);
begin
  inherited Create;
  if isSec then
  begin
    Fctx := SSL_CTX_new( tls_server_method());
    SSL_CTX_set_verify(FCTX, SSL_VERIFY_NONE, nil);
    assert(assigned( Fctx ) );


    assert( SSL_CTX_use_certificate_file(Fctx, @certFn[1], X509_FILETYPE_PEM) = 1);
    assert( SSL_CTX_use_PrivateKey_file(FCtx,  @keyFn[1],  X509_FILETYPE_PEM) = 1);
    assert(SSL_CTX_check_private_key(Fctx) = 1);
  end;
  bind(addr,port);
  set_simultaneous_accepts(true);
  set_nodelay(true);
  listen(UV_DEFAULT_BACKLOG);
  setOnClient(
         procedure (server: INPTCPServer)
         var
           c : IHttpClient;
         begin
           c := THttpClient.Create(server, Fctx);
           c.unref; //client droped if server shutdown
           c.setOnRequest(
               procedure
               begin
                  if assigned(FonRequest) then
                    FonRequest(c as IHttpRequest,c as IHttpResponse);
               end
            );
         end);
end;

destructor THttpServer.Destroy;
begin
  if assigned(FCtx)  then
     SSL_CTX_free(Fctx);
  inherited;
end;

function THttpServer.getTimeout: int64;
begin
  result := FTimeout;
end;

procedure THttpServer.setOnRequest(aOnReq: TProc<IHttpRequest, IHttpResponse>);
begin
  FOnRequest := aOnReq;
end;

procedure THttpServer.setTimeout(value: int64);
begin
  Ftimeout := value;
end;

{ THttpClient }

procedure THttpClient.addHeader(const name: Utf8string; value: Utf8string);
begin
//   if assigned(FResponse) then
//   begin
     FResponse.append(name).append(': ').append(value).append(#13#10);
//   end
end;

//function ssl_verify_peer : integer; cdecl;
//begin
//   result := 1;
//end;

constructor THttpClient.Create(server: INPTCPServer; Actx : TSSL_CTX);
//var
//  KEY_PASSWD : PAnsiChar;
begin
  if assigned(Actx) then
  begin
    Fin_bio := BIO_new(BIO_s_mem());
    assert(Fin_bio <> nil);
    BIO_set_mem_eof_return(Fin_bio,-1);
    Fout_bio := BIO_new(BIO_s_mem());
    assert(Fout_bio <> nil);
    BIO_set_mem_eof_return(Fout_bio,-1);
    FSSL  := SSL_new(ACtx);
    assert(assigned( FSSL ) );
    SSL_set_accept_state(FSSL);
    SSL_set_bio(FSSL, Fin_bio, Fout_bio);
    setLength( FSSLData, 4096);
    do_handshake;
  end;

  Fbuf := Buffer.Null;
  FHeaders := THTTPHeader.Create(Buffer.Null);
  Fstate := psHeader;
  FTimeoutValue := (server as IHttpServer).Timeout;
  InitTimeout;
   inherited CreateClient(server);
  if assigned(Actx) then
  begin
    setOnData(
      procedure (data: PByte; Len:Cardinal)
      var
        nbytes : integer;
      begin
       try
        repeat
        nbytes := BIO_write(Fin_bio,data,len);
        assert( nbytes > 0);
        inc(data, nbytes);
        dec(len,  nbytes);
        do_handshake;
        if Fis_init_finished = 1 then
        begin
//          if FState = psFin then
//            exit;
          repeat
            nbytes := SSL_read(FSSL,@FSSLData[0],length(FSSLData));
            if nbytes <= 0 then
              break;
            optimized_append(FBuf, BufferRef.CreateWeakRef(@FSSLData[0],nbytes));
          until false;
          processBuf;
        end;
        until len = 0;
        except
          Clear;
        end;
      end)
  end
  else
  begin
    setOnData(
      procedure (data: PByte; Len:Cardinal)
      begin
        optimized_append(FBuf, BufferRef.CreateWeakRef(data,Len));
        processBuf;
      end);

  end;

end;

destructor THttpClient.Destroy;
begin
  //FreeAndNil(FResponse);
  FreeAndNil(FHeaders);
  if assigned(FSSL) then
  begin
    SSL_free(FSSL);
    FSSL := nil;
  end;
  inherited;
end;

procedure THttpClient.do_handshake;
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
    write(@FSSLData[0],nbytes);
  until false;

end;

procedure THttpClient.do_shutdown;
var
  res : integer;
  len : integer;
begin
  if assigned(FSSL) then
  begin
    res := SSL_shutdown(Fssl);
    if res = 0 then
      res := SSL_shutdown(Fssl);
    repeat
       len := BIO_read(Fout_bio,@FSSLData[0],length(FSSLData));
       if len <= 0 then
       begin
         break;
       end;
       write(@FSSLData[0],len);
     until false;
  end;
  setOnData(nil);
  shutdown(nil);
end;

procedure THttpClient.finish(data: BufferRef);
var
 len,nbytes : integer;
 buf : BufferRef;
begin
  if FState = psProcess then
  begin
    if FKeepAlive then
      addHeader('Connection','keep-alive');
    addHeader('Content-Length',IntToStr(data.length));
    FResponse.append(#13#10);
    FResponse.append(data); //WriteBuffer(data.ref^,data.length);
//    write(FResponse.Memory,FResponse.Position);
    if assigned(FSSL) then
    begin
      nbytes := SSL_write(Fssl,FResponse.buf.ref, FResponse.buf.length);
      assert( nbytes = FResponse.buf.length);
      FResponse.buf.length := 0; //reset
      buf := FResponse.buf.maximalize;
      repeat
        len := BIO_read(Fout_bio,buf.ref,buf.length);
        if len <= 0 then
          break;
        write(buf.ref, len);
      until false;
    end
    else
    begin
      write( FResponse.buf.ref, FResponse.buf.length );
      FResponse.buf.length := 0; //reset
    end;
    if not FKeepAlive then
    begin
      do_shutdown;
//      FState := psFin;
//      shutdown(nil);
    end
    else
    begin
      Fstate := psHeader;
      setImmediate(
        procedure
        begin
         processBuf;
        end);
    end;
  end;
end;

function THttpClient.GetReqBody: BufferRef;
begin
  result := FBody;
end;

function THttpClient.GetReqHeaders: THTTPHeader;
begin
  result := FHeaders;
end;

function THttpClient.GetReqMethod: Utf8string;
begin
  result := FMethod;
end;

function THttpClient.GetReqPath: Utf8string;
begin
  result := FUri;
end;

procedure THttpClient.InitTimeout;
begin
  if assigned(FTimeout) then
  begin
    FTimeout.Clear;
    FTimeout := nil;
  end;
  if FTimeoutValue > 0 then
  begin
    FTimeout := SetTimeout(
      procedure
      begin
        do_shutdown;
      end, FTimeoutValue);
  end;
end;

procedure THttpClient.onClose;
begin
  FOnRequest := nil;
  if assigned( FTimeout ) then
  begin
    FTimeout.Clear;
    FTimeout := nil;
  end;
  inherited;
end;

procedure THttpClient.processBuf;
begin
   while ProcessNext do;
end;

function THttpClient.ProcessNext : Boolean;
var
  content : BufferRef;
  headers : BufferRef;
begin
  result := false;
  if FState = psUpgrade then
  begin

  end;

  if FState = psProcess then
    exit;

    //check header
    if FState = psHeader then
    begin
      if CheckHttpRequest(Fbuf,FMethod,FUri,FProtocol, headers, content) then
      begin
        FHeaders.clear;
        FHeaders.parse(headers);
        FState := psBody;
        FBuf := content;
        FKeepAlive := sameText( FHeaders.Fields['connection'], 'keep-alive');
      end
      else
        exit;
    end;
    //check content
    if Fstate = psBody then
    begin
      if Fbuf.length >= FHeaders.ContentLength  then
      begin
        FState := psProcess;
        FBody := Fbuf.slice(0, FHeaders.ContentLength);
        Fbuf.TrimL( FHeaders.ContentLength );
        //now buffer rdy for new request, but we must wait process complete to reuse client object
        if assigned( FOnRequest ) then
        begin
           FOnRequest();
           InitTimeout;
        end
        else
        begin
          do_shutdown;
        end;
      end;
    end;
   result := (FState = psHeader) and (FBuf.length > 0);
end;

procedure THttpClient.setOnRequest(proc: TProc);
begin
  FOnRequest := proc;
end;
{
function THttpClient.switchProtocol: INPStream;
var
 len,nbytes : integer;
 buf : BufferRef;
begin
  result := self;
  if FState = psProcess then
  begin
    if assigned(FTimeout) then
    begin
      FTimeout.Clear;
      FTimeout := nil;
    end;
//    write(FResponse.Memory,FResponse.Position);
    if assigned(FSSL) then
    begin
      nbytes := SSL_write(Fssl,FResponse.buf.ref, FResponse.buf.length);
      assert( nbytes = FResponse.buf.length);
      FResponse.buf.length := 0; //reset
      buf := FResponse.buf.maximalize;
      repeat
        len := BIO_read(Fout_bio,buf.ref,buf.length);
        if len <= 0 then
          break;
        write(buf.ref, len);
      until false;
    end
    else
    begin
      write( FResponse.buf.ref, FResponse.buf.length );
      FResponse.buf.length := 0; //reset
    end;
    Fstate := psUpgrade;
      mainLoop.setImmediate(
        procedure
        begin
         processBuf;
        end);
    end;
  end;
end;
}
procedure THttpClient.writeHeader(code: Integer);
begin
  FResponse.buf.length := 0;
  FResponse.append(FProtocol);
  FResponse.append(' ');
  FResponse.append(IntToStr(code));
  FResponse.append(' ');
  FResponse.append(ResponseText(Code));
  FResponse.append(#13#10);
end;

end.
