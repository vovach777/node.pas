program ex01_LoopTTY;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  np.Core,
  np.Buffer,
  np.Ut;

begin
  try
    loop.setImmediate(
        procedure
        begin
          stdout.PrintLn(#27'[1;32m'+TOSVersion.ToString+#27'[m');
          stdout.PrintLn('type `exit`');
          stdIn.setOnData(procedure(data:PByte; dataLen: Cardinal)
                          var
                            s : string;
                          begin
                            s := trim(Buffer.Create(data,datalen).AsString(65001));
                            stdout.PrintLn(#27'[1;33m'+s+#27'[m');
                            if SameText(s,'exit') then
                               loop.terminate;

                          end);
        end);
    loopHere;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.


