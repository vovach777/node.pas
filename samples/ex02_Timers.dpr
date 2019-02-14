program ex02_Timers;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  np.Core;

  procedure main;
  var
    int1 : INPHandle;
begin
    stdout.PrintLn(IntToStr(loop.now) + '> '+ TOSVersion.ToString);
    SetTimeout(
              procedure
              begin
                stdout.PrintLn(IntToStr(loop.now) + '> timer 1s fire');
              end, 1000);
    SetTimeout(
               procedure
               begin
                 stdout.PrintLn(IntToStr(loop.now) + '> clear int1 from 10s timer...');
                 int1.Clear;
               end, 10000);
    int1 := SetInterval(
              procedure
              begin
                stdout.PrintLn(IntToStr(loop.now) + '> interval');
              end, 1001);
  end;

  begin
  try
    main;
    loopHere;
    WriteLn('loop exit');
//    readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
