program ex09_tcp_mt;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  np.Core,
  np.libuv,
  np.buffer,
  np.Ut;

  type
     TNPTCPSocketStream = class( TNPTCPStream )
     public
        constructor CreateSocket(fd : uv_os_sock_t );
     end;

  var
    workers : array [1..4] of TLoop;
    barrier : uv_barrier_t;

  procedure init_worker(num : integer);
  begin
    thread_create(
        procedure
        begin
           workers[num] := loop;
           loop.addTask;
           loop.once(ev_loop_beforeTerminate,
              procedure
              begin
                loop.removeTask;
              end);
           OutputDebugStr('%d worker start!',[num]);
           uv_barrier_wait(@barrier);
           loophere;
           OutputDebugStr('%d worker end!',[num]);
        end
     );

  end;

  procedure init_workers;
  var  i : integer;
  begin
     uv_barrier_init(@barrier,5);
     for I := Low(workers) to High(workers) do
     begin
       init_worker(i);
     end;
     uv_barrier_wait(@barrier);
     uv_barrier_destroy(@barrier);
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
                    uvclient : uv_tcp_t;
                    socket: uv_os_fd_t;
                  begin
                     stdout.PrintLn('Client connected');
                     inc(next_worker);
                     if next_worker = 5 then
                        next_worker := 1;
                    duv_ok( uv_tcp_init(loop.uvloop, @uvclient ));
                    duv_ok( uv_accept( puv_stream_t( _server._uv_handle ), @uvclient ) );
                    duv_ok( uv_fileno( @uvclient, @socket ) );
                    workers[next_worker].setImmediate(
                      procedure
                      var
                        client : INPTCPStream;
                      begin
                        client := TNPTCPSocketStream.CreateSocket(socket);
                        client.set_nodelay(true);
                        client.setOnData(
                            procedure (data:PBufferRef)
                            begin
                              client.write(data^);
                            end);
                      end
                    );
                  end
               );
          server.listen(1);
  end;

{ TNPTCPSocketStream }

constructor TNPTCPSocketStream.CreateSocket(fd: uv_os_sock_t);
begin
  inherited Create;
  uv_tcp_open(puv_tcp_t( FHandle ),fd);
end;


procedure run_client;
var
  connect: INPTCPConnect;
  addr: TSockAddr_in_any;
begin
  //echo server
  connect := TNPTCPStream.CreateConnect();
  connect.set_nodelay(true);
  uv_ip4_addr('127.0.0.1',9999,addr.ip4 );
  connect.connect(addr);
  connect.setOnConnect(
      procedure
      var
        OutBuf : BufferRef;
        InputBuf: BufferRef;
      begin
        OutBuf := Buffer.Create(8);
        OutBuf.write_as<int64>(0,1);
        InputBuf := Buffer.Null;

        connect.write(OutBuf);
          connect.setOnData(
                procedure (data:PBufferRef)
                var
                  data64: int64;
                begin
                    InputBuf := Buffer.Create( [InputBuf, data^] );
                    while InputBuf.HasSize(8) do
                    begin
                      data64 := InputBuf.unpack<int64>;
                      InputBuf.TrimL(8);
                      if data64 and $FFF = 0 then
                      begin
                        stdout.Print(#27'[2K'#13+IntToStr(data64*100 div $10000)+'%' );
                      end;
                      if data64 <= $10000 then
                      begin
                        inc(data64);
                        connect.write(BufferRef.Pack<int64>(data64));
                      end
                      else
                      begin
                        stdout.PrintLn('');
                        connect.shutdown();
                      end;
                    end;
                end
            );
      end
    );
end;


begin
  try
    IsMultiThread := true;
    loop.SetImmediate(
        procedure
        begin
          init_workers();
          run_server;
          SetInterval(procedure
          begin
             run_client;
          end,2000 );
        end);
    LoopHere;
    WriteLn('loop exit');
    readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.


