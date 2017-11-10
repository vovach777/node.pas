program ex07_sock5;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  sock5client in 'sock5client.pas';

begin
  try
    { TODO -oUser -cConsole Main : Insert code here }
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
