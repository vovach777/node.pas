program ex09_tcp_mt;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  np.Core,
  np.libuv,
  np.buffer,
  np.Ut;

  const
  {$IFDEF MSWINDOWS}
    PIPE_NAME = '\\.\pipe\ED9900E6-2A34-470B-9E89-1A9C7C723635\%d\%d';
  {$ENDIF}
  {$IFDEF LINUX}
    PIPE_NAME =  '/tmp/ED9900E6-2A34-470B-9E89-1A9C7C723635-%d-%d';
  {$ENDIF}

    MAX_WORKERS  = 3;

  var
    workers : array [0..MAX_WORKERS] of record
                                  loop: TLoop;
                                  thread: uv_thread_t;
                                  //pipeTo: INPPipe;
                              end;
    barrier : uv_barrier_t;
  procedure logme(const msg : UTF8String);
  begin
    if workers[0].loop = nil then
        exit;

    workers[0].loop.setImmediate(
        procedure
        var
          w, h : integer;
        begin
          stdout.PrintLn(msg);
        end);
  end;

  procedure init_worker(num : integer);
  begin
    workers[num].thread := thread_create(
        procedure
        var
          socket_recv: INPPipe;
          PipeName : string;
        begin
           try
           try
//             WriteLn('thread ',num,'created!');
             workers[num].loop := loop;
             socket_recv := TNPPipe.Create;
             pipeName :=  Format(PIPE_NAME, [uv_os_getpid(),num]);
             socket_recv.bind(  pipeName );
//             WriteLn('before chmod');
//             socket_recv.set_chmod( UV_READABLE or UV_WRITABLE );
             socket_recv.setOnClient(
                procedure(_server: INPPipe)
                var
                  clientTCP : INPTCPStream;
                  clientPipe: INPPipe;
                begin
                  logme(Format('%s>new ipc client',[pipeName]));
                  clientPipe := TNPPipe.CreateIPC;
                  clientPipe.accept(_server);
                  clientPipe.setOnData(
                      procedure (buf: pBufferRef)
                      var
                         fd : uv_os_fd_t;
                         origSocket : string;
                      begin
                        origSocket := buf.AsUtf8String;
                       logme(Format('%s>data: "%s"',[pipeName, origSocket]));
                        while clientPipe.get_pending_count > 0 do
                        begin
                             if clientPipe.get_pending_type = UV_TCP then
                             begin

                               clientTCP := TNPTCPStream.CreateFromIPC(clientPipe);

                               np_ok( uv_fileno(clientTCP._uv_handle, fd) );
                               logme(Format('%s> handle received %u',[ PipeName, fd]));

                               clientTCP.set_nodelay(true);
                               clientTCP.setOnData(
                                   procedure (data:PBufferRef)
                                    begin
                                     clientTCP.write('orig socket: '+origSocket+Format(' shared socket: %6d',[fd])+' echo back:'+data.AsUtf8String);
                                   end);
                               clientTCP.setOnClose(
                                   procedure
                                   begin
                                      logme(Format('%s> ipc client disconnected',[PipeName]));
                                   end
                               );
                             end;
                        end;
                     end);
                end);
//             WriteLn('before listen');
             socket_recv.listen(128);
//             WriteLn('after listen');
             logme(Format( '%d worker start!',[num] ));

           finally
             if uv_barrier_wait(@barrier) > 0 then
             begin
               uv_barrier_destroy(@barrier);
             end;
           end;

           loophere;
           //OutputDebugStr('%d worker end!',[num]);
           logme(Format('%d worker end!',[num] ));
           except
              on E:Exception do
                  WriteLn('exceptin ',num,' ',e.Message);
           end;
        end
     );

  end;

  procedure init_workers;
  var  i : integer;
  begin
     uv_barrier_init(@barrier,High(workers)+1);
     workers[0].loop := loop;
     workers[0].thread := 0;


    logme('<ENTER> - Add task to worker');
    logme('<ESC> - shutdown');

     for I := 1 to High(workers) do
     begin
       init_worker(i);
     end;

     if uv_barrier_wait(@barrier) > 0 then
     begin
       uv_barrier_destroy(@barrier);
     end;
  end;

  procedure get_connector(num : integer; cb : TProc<INPPipe>);
  var
     pipe : INPPipe;
     pipeName : string;
  begin
//keep-alive ipc channel do not works! only one handle within ipc channel!!! bug?!
//last accepted socket collect data from all accepted before sockets!!! (tested on windows)
//     if workers[num].pipeTo = nil then
//     begin
        pipe := TNPPipe.CreateIPC;
        pipeName := Format( PIPE_NAME,[ uv_os_getpid(), num ]);
        pipe.connect(PipeName);
        pipe.setOnConnect(
            procedure
            begin
              pipe.setOnData(
                 procedure(data:PBufferRef)
                 begin
                 end
              );
              logme(Format('pipe to worker open (%s)!', [pipeName]));
              //workers[num].pipeTo := pipe;
              cb(pipe);
              cb := nil;
            end);
        pipe.setOnClose(
              procedure
              begin
                 //workers[num].pipeTo := nil;
                 logme(Format('pipe to worker closed (%s)!', [pipeName]));
                 cb := nil;
              end
            );
//     end;
//     else
//     begin
//       cb( workers[num].pipeTo );
//       cb := nil;
//     end;
  end;

  procedure run_server;
  var
    server : INPTCPServer;
    next_worker: integer;
  begin
          server := TNPTCPServer.Create();
          server.set_nodelay(true);
          server.bind('127.0.0.1',9999);
          next_worker:=0;
          server.setOnClient(
                  procedure (_server: INPTCPServer)
                  var
                    tmpTcp: INPTCPStream;
                  begin
                     tmpTcp := TNPTCPStream.CreateClient(_server);
                     inc(next_worker);
                     if next_worker = high(workers)+1 then
                        next_worker := 1;
                     get_connector( next_worker,
                        procedure (pipe : INPPipe)
                        var
                          fd : uv_os_fd_t;
                        begin
                          np_ok( uv_fileno(tmpTCP._uv_handle, fd) );
                          pipe.write2(Format('%6d',[fd]), tmpTcp);
                          tmpTcp.Clear;
                          tmpTcp := nil;
                          pipe.shutdown;
                        end);

                  end
               );
          server.listen();
  end;

var
   client_num : integer;
procedure run_client;
var
  connect: INPTCPConnect;
  Lclient_num : integer;
begin
  inc( client_num );
  Lclient_num := client_num;

(* same node.js code:
const net = require('net');
let connect = net.createConnection(9999, '127.0.0.1', ()=> {
     connect.on('data',(data) => console.log(data.toString()));
     setInterval(()=>
            {
                  connect.write("hello from node!");
			}, 1000);
});
*)

  connect := TNPTCPStream.CreateConnect();
  connect.set_nodelay(true);
  connect.connect( '127.0.0.1',9999 );
  connect.setOnError(procedure (Err: PNPError)
                     begin
                        logme( 'tcp error: ' + err.msg );
                     end);
  connect.setOnClose(procedure
                     begin
                        logme(Format('client #%6d disconnected',[lclient_num]));
                     end);

  connect.setOnConnect(
      procedure
      var
        fd : uv_os_fd_t;
      begin
        np_ok( uv_fileno(connect._uv_handle, fd) );
        logme( Format('#%6d>tcp connected socket=%6d',[Lclient_num,fd]));
        setInterval(
           procedure
           begin
             connect.write(Format('%6d client_num %d',[ fd, Lclient_num]));
           end,1000);
          connect.setOnData(
                procedure (data:PBufferRef)
                begin
                  logme( Format('#%6d> %s',[Lclient_num,data.asUTF8String]));
                end
            );
      end
    );
end;

procedure shutdown;
var
  i : integer;
begin
  for i := 1 to High(workers) do
  begin
    if assigned( workers[i].loop ) then
    begin
      workers[i].loop.setImmediate(
          procedure
          begin
             loop.terminate;
          end);
     end;
     if workers[i].thread <> 0 then
       uv_thread_join( @workers[i].thread )
   end;
   logme('terminated!');
   setTimeout(
   procedure
   begin
          loop.terminate;
   end,1000);
end;

begin
  try
    init_workers;
    run_server;
    run_client;
    stdInRaw.setOnData(procedure (buf: PBufferRef)
                    begin
                     if (  buf.length = 1) and
                            (buf.ref^ = 27) then
                            begin
                                SetImmediate(
                                   procedure
                                   begin
                                     shutdown;
                                   end);
                            end
                     else
                     if (  buf.length = 1) and
                            (buf.ref^ = 13) then
                            begin
                                SetImmediate(
                                   procedure
                                   begin
                                      run_client;
                                   end);
                            end;

                    end);
    LoopHere;
//    WriteLn('loop exit');
//    readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.


