program ex03_spawn;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  np.Core,
  np.libuv;

  var
    loop : TLoop;
begin
  try
    SetImmediate(
        procedure
        var
          spawn : INPSpawn;
          cp_stdout :  INPPipe;
        begin
          stdout.PrintLn('Spawn sample');
          stdout.PrintLn('-----------');
          spawn := TNPSpawn.Create();
          spawn.setOnExit(
              procedure (exit_code: int64; term_sign: integer)
              begin
                 stdout.PrintLn('-----------');
                 stdout.PrintLn(Format('process terminated with code %d',[exit_code]));
              end
           );
          spawn.args.DelimitedText := 'ex02_timers.exe';
          cp_stdout := TNPPipe.Create();
          spawn.stdio[1].flags := UV_CREATE_PIPE or UV_WRITABLE_PIPE;
          spawn.stdio[1].stream := puv_stream_t( cp_stdout._uv_handle );
          spawn.spawn;
          cp_stdout.setOnData(
               procedure (data:PBufferRef)
               begin
                 stdout.Print(data.AsUtf8String );
               end);

        end);
    LoopHere;
    WriteLn('loop exit');
    readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.


