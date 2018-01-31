program ex07_gui;

uses
  Vcl.Forms,
  ex07_mainForm in 'ex07_mainForm.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
