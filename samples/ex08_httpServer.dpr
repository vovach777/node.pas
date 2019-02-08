program ex08_httpServer;
{$DEFINE HTTPS}
{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  np.core,
  np.HttpServer,
  np.Buffer,
  np.JSON,
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
         s : Utf8String;
         json : TJSONPair;
         url: TURL;
         i : integer;
         body_s : string;
       begin
         url.Parse( req.Path );
         for i := 0 to length(url.Params)-1 do
         begin
            if (url.Params[i].Name = 'body') and (req.Body.length > 0) then
            begin

               body_s := Format('<h2>Body</h2><pre>%s</pre><hr>',[req.Body.AsUtf8String]);
               break;
            end;
         end;

          if SameText( req.Path, '/json') then
          begin
            resp.writeHeader(200);
            resp.addHeader('Server','Node.pas example');
            resp.addHeader('Content-Type', 'application/json');
            resp.finish(
                     Buffer.Create('{"msg":"Hello!"}')
            );
            exit;
          end;
          if SameText( req.Path, '/json-create') then
          begin
            resp.writeHeader(200);
            resp.addHeader('Server','Node.pas example');
            resp.addHeader('Content-Type', 'application/json');
            json := TJSONPair.Create();
            try
              json['method'].AsString := req.Method;
              json['path'].AsString := req.Path;
              for s in req.Headers.Names do
                json['headers'][s].AsString := req.Headers[s];
              resp.finish(
                         Buffer.Create(json.ToString)
                       );
            finally
              json.Free;
            end;
            exit;
          end;
          if SameText( req.Path, '/shutdown') then
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
                   Format(
                       '<style>'+
                      'table { border-collapse: collapse;}'+
                      'td { border: 1px solid black; padding: 0 5px 0 5px;}'+
                      '</style>'+
                   '<h1>%s, %s!</h1><p>PATH: %s</p><h2>Request headers</h2><pre>%s</pre><hr>%s'+
                '<table>'+
                   '<tr>'+
                      '<th>Operation</th>'+
                      '<th>API</th>'+
                   '</tr>'+
                   '<tr>'+
                       '<td>shutdown</td>'+
                       '<td>/shutdown</td>'+
                   '</tr>'+
                   '<tr>'+
                       '<td>simple json</td>'+
                       '<td>/json</td>'+
                   '</tr>'+
                   '<tr>'+
                       '<td>create json</td>'+
                       '<td>/json-create</td>'+
                   '</tr>'+
                '</table>',
                      [
                      msg,
                      (req as INPTCPStream).getpeername,
                      req.Path, req.Headers.ToString, Body_s]))
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
