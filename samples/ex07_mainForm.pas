unit ex07_mainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, np.core, np.HttpConnect, np.Url, np.json, np.Ut, np.Promise, np.Buffer, Vcl.AppEvnts, Vcl.ExtCtrls,
  Vcl.StdCtrls;

type
  TForm1 = class(TForm)
    ApplicationEvents1: TApplicationEvents;
    Timer1: TTimer;
    Label1: TLabel;
    Edit1: TEdit;
    Button1: TButton;
    Memo1: TMemo;
    procedure ApplicationEvents1Message(var Msg: tagMSG; var Handled: Boolean);
    procedure Timer1Timer(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
    function do_get(const s : string) : IPromise;
    procedure logLines(const s: string);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.ApplicationEvents1Message(var Msg: tagMSG;
  var Handled: Boolean);
begin
  Handled := false;
  loop.run_nowait;

end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  memo1.Clear;
  do_get(edit1.Text).then_(
     procedure(value: IValue)
     begin
       if value is TObjectValue<TJSONPair> then
       begin
         logLines(
          prettyJSON(         TObjectValue<TJSONPair>( value ).Value.ToString  )
            );
       end
       else
       begin
          if Value is TRecordValue<BufferRef> then
          logLines(
            TRecordValue<BufferRef>(value).Ref.AsUtf8String
             );

       end;

     end,
     procedure(errorValue: IValue)
     begin
       Memo1.Text := errorValue.ToString;
     end
  )
end;

function TForm1.do_get(const s: string): IPromise;
begin
   result := newPromise(
    procedure(ok,ko:TProc<IValue>)
    var
      http : THttpConnect;
      url : TURL;
      req: TBaseHttpRequest;
      to_: INPTimer;
    begin
      to_ := SetTimeout(
          procedure
          begin
             ko(mkValue('Timeout'));
             req.done;
             http.Shutdown;
          end,5000);
       url.Parse(s);
       http := THttpConnect.Create(url.Schema+'://'+url.HttpHost);
       req := http._GET(url.FullPath);
       req.once(ev_Complete,
               procedure
               begin
                 to_.Clear;
                 try
                   try
                    if req.statusCode = 200 then
                    begin
                       if req.ResponseHeader.ContentType = 'application/json' then
                       begin
                           ok(
                                 TObjectValue<TJSONPair>.Create(
                                                                  TJSONPair.Create( req.ResponseContent.AsUtf8String )
                                                               )
                             );
                       end
                       else
                          ok( TRecordValue<BufferRef>.Create( req.ResponseContent ) );
                    end
                    else
                    begin
                       ko( mkValue( 'Error: ' + req.statusReason ) );
                    end;
                   finally
                    req.done;
                    http.Shutdown;
                   end;
                 except
                    on E:Exception do
                      ko( mkValue(E.Message) );
                 end;
               end);
    end);
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
   begin
   end;
end;

procedure TForm1.logLines(const s: string);
var
  sl : TStringList;
begin
  sl :=  TStringList.Create;
  try
    sl.Text := s;
    memo1.Lines.AddStrings(sl);
    memo1.Lines.Add('-------')
  finally
    sl.free;
  end;
end;


end.
