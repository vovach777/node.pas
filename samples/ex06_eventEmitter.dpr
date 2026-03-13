program ex06_eventEmitter;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  windows,
  System.SysUtils,
   np.core,
   np.eventEmitter,
   System.Diagnostics,
   System.Threading,
   System.Classes;

  const
     ev_Name = 1000;
     ev_PhoneNo = 1001;
     ev_card = 1002;
     ev_minus = 2000;
     ev_recursive = 3000;
     ev_remover = 3001;
     ev_bench_empty = 4000;
     ev_bench_param = 4001;
     ev_non_existent = 9999;
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

      // --- New tests ---
      // 1. Adding subscriber during emit
      eventEmitter.on_(ev_recursive, procedure
        begin
          WriteLn('ev_recursive: Adding a new subscriber during emission...');
          eventEmitter.on_(ev_recursive, procedure
            begin
              WriteLn('  > Hello from the newly added subscriber!');
            end);
        end);

      // 2. Removing subscriber during emit
      // We add the executioner FIRST so it can remove the victim BEFORE it's called.
      
      // We will need a variable to hold the victim's handle, 
      // but the victim isn't created yet. We can use a pointer or just add it before.
      
      // Let's add a second victim that will survive
      eventEmitter.on_(ev_remover, procedure
        begin
          WriteLn('  > Victim #2: I am downstream and I should survive.');
        end);

      // Add the executioner
      eventEmitter.on_(ev_remover, procedure
        begin
          WriteLn('ev_remover: Removing Victim #1 during emission (it should NOT be called)...');
          eh.remove;
        end);

      // Add Victim #1 (the one to be removed)
      eh := eventEmitter.on_(ev_remover, procedure
        begin
          WriteLn('  > ERROR: Victim #1 was called! (Removal failed or order is wrong)');
        end);

      // Add one more to see if processing continues correctly
      eventEmitter.on_(ev_remover, procedure
        begin
          WriteLn('  > Still alive after removal operation.');
        end);

      // 3. Benchmarking
      WriteLn('--- Registration Benchmark (1,000,000 subscribers) ---');
      var sw := TStopwatch.StartNew;
      for i := 1 to 1000000 do
        eventEmitter.on_(ev_bench_empty, procedure begin end);
      sw.Stop;
      WriteLn(Format('Registered 1,000,000 EMPTY handlers in %d ms', [sw.ElapsedMilliseconds]));

      sw := TStopwatch.StartNew;
      for i := 1 to 1000000 do
        eventEmitter.on_(ev_bench_param, procedure(arg: Pointer)
          begin
            if Assigned(arg) then
              Inc(PInteger(arg)^);
          end);
      sw.Stop;
      WriteLn(Format('Registered 1,000,000 PARAM handlers in %d ms', [sw.ElapsedMilliseconds]));
  end;

  procedure pub;
  var
    card: TCardArgument;
    counter: Integer;
    sw: TStopwatch;
  begin
    card.name := 'Jon';
    card.phoneNo := 5550000;
    eventEmitter.emit(ev_Name, @card.name);
    eventEmitter.emit(ev_PhoneNo, @card.phoneNo);
    eventEmitter.emit(ev_card, @card);

    WriteLn('--- Testing modifications during emit ---');
    WriteLn('Emitting ev_recursive (first time):');
    eventEmitter.emit(ev_recursive);
    WriteLn('Emitting ev_recursive (second time, should have more subscribers):');
    eventEmitter.emit(ev_recursive);

    WriteLn('Emitting ev_remover:');
    eventEmitter.emit(ev_remover);

    WriteLn('--- Emission Benchmark ---');
    sw := TStopwatch.StartNew;
    eventEmitter.emit(ev_bench_empty);
    sw.Stop;
    WriteLn(Format('Emitted 1,000,000 EMPTY handlers in %d ms', [sw.ElapsedMilliseconds]));

    counter := 0;
    sw := TStopwatch.StartNew;
    eventEmitter.emit(ev_bench_param, @counter);
    sw.Stop;
    WriteLn(Format('Emitted 1,000,000 PARAM handlers in %d ms. Counter value: %d', [sw.ElapsedMilliseconds, counter]));

    WriteLn('--- Single Non-existent event Lookup ---');
    sw := TStopwatch.StartNew;
    eventEmitter.emit(ev_non_existent);
    sw.Stop;
    WriteLn(Format('Emitted 1 NON-EXISTENT event in %d ms (lookup overhead for 2,000,000+ total handlers)', [sw.ElapsedMilliseconds]));
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
