program ex06_eventEmmiter;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
   np.core;

  const ev_MyName = 1000;

  procedure main;
  var
    ee : TEventEmitter;
    eh : IEventHandler;
    name: TAString;
    i : integer;
  begin
    ee := TEventEmitter.Create;
    try
      ee.on_(ev_MyName,
        procedure(arg: Pointer)
        begin
          if assigned(arg) then
           WriteLn(Format('[%d] MyName is %s!', [ this_eventHandler.id, PAString(arg).A ] ))
          else
           WriteLn(Format('[%d] Anonymous!', [ this_eventHandler.id ] ));
        end);
      eh := ee.on_(ev_MyName, procedure
                              begin
                                 WriteLn('Cancelled handler');
                              end);
      ee.once(ev_MyName,
             procedure
             begin
                WriteLn('MyName event emitted!');
             end);
      eh.remove;
      name.A := 'Jon';
      ee.emit(ev_MyName, @name);

    except
      ee.Free;
    end;
  end;

begin
  try
     main;
     readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
