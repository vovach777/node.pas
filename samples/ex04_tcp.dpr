program ex04_tcp;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  np.Core,
  np.libuv;

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
                        procedure (data:PByte; len : Cardinal)
                        begin
                          client.write(data,len);
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
                 LData : int64;
                 RcvBuf: int64;
                 BufLen : integer;
                 Buf: PByte;
              begin
                LData := 0;
                BufLen := sizeof(int64);
                Buf := @RcvBuf;
                connect.write(PByte(@LData),sizeof(LData));
                  connect.setOnData(
                        procedure (data: PByte; Len : Cardinal)
                        var
                          len2: Cardinal;
                        begin
                            while len > 0 do
                            begin
                              if len > BufLen then
                                 len2 := BufLen
                              else
                                 len2 := len;
                              dec(len,len2);
                              move(data^,Buf^,len2);
                              dec(BufLen,len2);
                              if BufLen = 0 then
                              begin
                                BufLen := sizeof(int64);
                                Buf := @RcvBuf;
                                assert(RcvBuf = Ldata); //check echo data
                                inc(LData);
                                if LData and $FFF = 0 then
                                begin
                                   stdout.Print(#27'[2K'#13+IntToStr(Ldata*100 div $10000)+'%' );
                                end;

                                if LData < $10000 then
                                  connect.write(PByte(@LData),sizeof(LData))
                                else
                                begin
                                  stdout.PrintLn('');
                                  connect.shutdown();
                                end;
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


