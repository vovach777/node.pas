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
          if stdout.is_tty then
          begin
            stdout.PrintLn(#27'[1;32m'+TOSVersion.ToString+#27'[m');
            stdout.PrintLn('type `exit`');
          end
          else
          begin
            stdout.PrintLn(TOSVersion.ToString);
            stdout.PrintLn('type `exit`');
          end;
          stdIn.setOnData(procedure(data:PBufferRef)
                          var
                            s : string;
                          begin
                            s := trim( data.AsUtf8String );
                            if stdout.is_tty then
                              stdout.PrintLn(#27'[1;33m'+s+#27'[m')
                            else
                              stdout.PrintLn(s);
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


