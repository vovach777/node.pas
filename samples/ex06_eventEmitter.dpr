program ex06_eventEmitter;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
   np.core;

  const
     ev_Name = 1000;
     ev_PhoneNo = 1001;
     ev_card = 1002;
  type
     PCardArgument = ^TCardArgument;
     TCardArgument = record
        name: string;
        phoneNo: int64;
     end;

  var
    eventEmitter : TEventEmitter;

  procedure sub;
  var
    eh : IEventHandler;
    p  : TProc;
  begin
      eventEmitter.on_(ev_Name,
        procedure(arg: Pointer)
        begin
          if assigned(arg) then
           WriteLn(Format('[%d] Name is %s!', [ this_eventHandler.id, PString(arg)^ ] ))
          else
           WriteLn(Format('[%d] Anonymous!', [ this_eventHandler.id ] ));
        end);
      eh := eventEmitter.on_(ev_Name, procedure
                              begin
                                 WriteLn('Cancelled handler');
                              end);
      eh.remove; //cancel sub
      eventEmitter.on_(ev_PhoneNo, procedure(phone_arg: Pointer)
                                   begin
                                     WriteLn(Format('[%d] PhoneNo: %d',[this_eventHandler.id, PInt64(phone_arg)^]));
                                   end);
      eventEmitter.on_(ev_card, procedure(cardArg: Pointer)
                                begin
                                  assert(assigned(cardArg));
                                  with PCardArgument(cardArg)^ do
                                     WriteLn(Format('Name: %s, tel.: %d', [name, phoneNo] ));
                                end);
      p :=   procedure
             begin
                WriteLn('----------------------------------');
             end;
      eventEmitter.on_(ev_Name,p);
      eventEmitter.on_(ev_PhoneNo,p);
      eventEmitter.on_(ev_card,p);
  end;

  procedure pub;
  var
    card: TCardArgument;
  begin
    card.name := 'Jon';
    card.phoneNo := 5550000;
    eventEmitter.emit(ev_Name, @card.name);
    eventEmitter.emit(ev_PhoneNo, @card.phoneNo);
    eventEmitter.emit(ev_card, @card);
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
