program ex05_thread;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  np.libuv,
  np.core;

  var
    SetImmediateML : TSetImmediate; //ref to main loop (executed in main thread) SetImmediate

  procedure HighLevelThread;
  begin
     stdout.PrintLn('HLT: start!');

    loop.newThread(
      procedure
      var
        i : integer;
      begin
         for i := 1 to 8 do
         begin
           setImmediateML(
              procedure
              begin
                stdout.PrintLn('HLT: hello from thread!');
              end
           );
           sleep(100);
         end;
      end, procedure
      begin
         stdout.PrintLn('HLT: thread done!');
      end);
  end;


  procedure LowLevelThread;
  var
    async : INPAsync;
    thread : uv_thread_t;
  begin
    async := SetAsync(
                 procedure
                 begin
                   stdout.PrintLn('LLT: Async fire!');
                 end);
    thread := thread_create(
              procedure
              var
                i : integer;
              begin
                 for i := 1 to 8 do
                 begin
                   async.send;
                   sleep(100);
                 end;
                 //access from second thread to main thread loop. setImmediate() is thread safe.
                  setImmediateML(
                     procedure
                     begin
                       //Main Thread
                       thread_join(thread);
                       async.Clear;
                       stdout.PrintLn('LLT: async close'#13#10);
                       async := nil;
                       NextTick(
                          procedure
                          begin
                             HighLevelThread; //chain HLT
                          end);
                     end
                   );
              end);
  end;


begin
  try

    SetImmediateML := loop.setImmediate;
    LowLevelThread;

    LoopHere;
    WriteLn('loop exit');
    readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.


