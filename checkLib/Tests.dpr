program Tests;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  np.buffer.tests in 'np.buffer.tests.pas';

begin
  try
      RunBufferTests;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
