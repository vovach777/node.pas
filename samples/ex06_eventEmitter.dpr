program ex06_eventEmitter;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  windows,
  System.SysUtils,
   np.core,
   System.Diagnostics,
   System.Threading,
   System.Classes;

  const
     ev_Name = 1000;
     ev_PhoneNo = 1001;
     ev_card = 1002;
     ev_minus = 2000;
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
    i : integer;
  begin
      eventEmitter.on_(ev_Name,
        procedure(arg: Pointer)
        begin
          if assigned(arg) then
           WriteLn(Format('[%d] Name is %s!', [ ev_Name, PString(arg)^ ] ))
          else
           WriteLn(Format('[%d] Anonymous!', [ ev_Name ] ));
           eventEmitter.emit(ev_Minus);
        end);
      eh := eventEmitter.on_(ev_Name, procedure
                              begin
                                 WriteLn('Cancelled handler');
                                 eventEmitter.emit(ev_minus);
                              end);
      eh.remove; //cancel sub
      eventEmitter.on_(ev_PhoneNo, procedure(phone_arg: Pointer)
                                   begin
                                     WriteLn(Format('[%d] PhoneNo: %d',[ev_PhoneNo, PInt64(phone_arg)^]));
                                     eventEmitter.emit(ev_minus);
                                   end);
      eventEmitter.on_(ev_card, procedure(cardArg: Pointer)
                                begin
                                  assert(assigned(cardArg));
                                  with PCardArgument(cardArg)^ do
                                     WriteLn(Format('Name: %s, tel.: %d', [name, phoneNo] ));
                                  eventEmitter.emit(ev_minus);
                                end);
//      p :=   procedure
//             begin
//                eventEmitter.emit(ev_minus);
//             end;
//      eventEmitter.on_(ev_Name,p);
//      eventEmitter.on_(ev_PhoneNo,p);
//      eventEmitter.on_(ev_card,p);
      for i := 1 to 24 do
      eventEmitter.on_(
         ev_minus,
         procedure
         begin
           write('-');
         end);
      eventEmitter.on_(
         ev_minus,
           procedure
           begin
              WriteLn;
           end);

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
       eventEmitter.RemoveAll;
     finally
       freeAndNil(eventEmitter);
     end;
     readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
