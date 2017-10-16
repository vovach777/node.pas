program ex06_eventEmitter;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
   np.core;

  const
     ev_MyName = 1000;
  var
    eventEmitter : TEventEmitter;

  procedure sub;
  var
    eh : IEventHandler;
  begin
      //subscribe with args
      eventEmitter.on_(ev_MyName,
        procedure(arg: Pointer)
        begin
          if assigned(arg) then
           WriteLn(Format('[%d] MyName is %s!', [ this_eventHandler.id, PAString(arg).A ] ))
          else
           WriteLn(Format('[%d] Anonymous!', [ this_eventHandler.id ] ));
        end);
      eh := eventEmitter.on_(ev_MyName, procedure
                              begin
                                 WriteLn('Cancelled handler');
                              end);
      //subscribe no args. one time
      eventEmitter.once(ev_MyName,
             procedure
             begin
                WriteLn('MyName event emitted!');
             end);
      eh.remove; //cancel sub
  end;

  procedure pub;
  var
    arguments: TAString;
  begin
    arguments.A := 'Jon';
    eventEmitter.emit(ev_MyName, @arguments);
  end;

begin
  try
     eventEmitter := TEventEmitter.Create;
     try
       sub;
       pub;
     finally
       freeAndNil(eventEmitter);
     end;
     readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
