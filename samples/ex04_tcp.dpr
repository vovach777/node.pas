program ex04_tcp;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  np.Core,
  np.libuv,
  np.buffer;

begin
  try
    loop.NextTick(
        procedure
        var
          server : INPTCPServer;
          connect: INPTCPConnect;
          addr: TSockAddr_in_any;
        begin
          //echo server
          server := TNPTCPServer.Create();
          server.set_nodelay(true);
          server.bind('127.0.0.1',9999);
          server.setOnClient(
                  procedure (_server: INPTCPServer)
                  var
                    client : INPTCPStream;
                  begin
                    client := TNPTCPStream.CreateClient(_server);
                    client.set_nodelay(true);
                    stdout.PrintLn('Client connected');
                    client.setOnData(
                        procedure (data:PBufferRef)
                        begin
                          client.write(data^);
                        end
                    );
                    client.setOnClose(
                         procedure
                         begin
                           stdout.PrintLn('Client disconnected');
                         end);
                  end
               );
          server.listen(1);
          server.unref;
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

        end
    );
    LoopHere;
    WriteLn('loop exit');
    readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.


