program ex08_httpServer;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  np.core,
  np.HttpServer,
  np.Buffer,
  np.URL;

  procedure main(const addr: string; port: word);
  var
     server : IHttpServer;
  begin
    {$IFDEF HTTPS}
    server := THttpServer.Create(addr,port,true,'server.cert','server.key');
    {$ELSE}
    server := THttpServer.Create(addr,port,false,'','');
    {$ENDIF}
    WriteLn('Listen: ', addr,':',port);

    server.setOnRequest(
       procedure (req : IHttpRequest; resp: IHttpResponse )
       var
         msg : string;
       begin
          if SameText( req.Path, '/exit') then
          begin
            msg := 'Goodbye';
            setTimeout(
             procedure
             begin
               loop.terminate;
             end,1000);
          end
          else
            msg := 'Hello';
          resp.writeHeader(200);
          resp.addHeader('Server','Node.pas example');
          resp.addHeader('Content-Type', 'text/html; charset=utf-8');
          resp.finish(
                Buffer.Create(
                Format('<h1>%s, %s!</h1><p>PATH: %s</p><h2>Request headers</h2><pre>%s</pre>----<br><b>/exit</b> to close server',
                      [
                      msg,
                      (req as INPTCPStream).getpeername,
                      req.Path, req.Headers.ToString]))
          );
       end );
  end;
begin
  try
    NextTick(
        procedure
        begin
           main('0.0.0.0',9000);
        end);
    loopHere;
    WriteLn('Terminated');
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
