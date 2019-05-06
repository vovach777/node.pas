unit np.common;

interface
  uses SysUtils;

const
{$IFDEF LINUX64}
  NODEPAS_LIB = 'nodepaslib.so';
{$ENDIF}
{$IFDEF WIN64}
   NODEPAS_LIB = 'nodepaslib64.dll';
{$ENDIF}
{$IFDEF WIN32}
  NODEPAS_LIB = 'nodepaslib32.dll';
//  {$Message Error 'only 64 bit windows support!'}
{$ENDIF}


type
    SIZE_T = NativeUInt;
    psize_t = ^SIZE_T;
    SSIZE_T = NativeInt;
{$IFDEF NEXTGEN}
   PAnsiChar = pUtf8char;
{$ELSE}
   pansichar = pUtf8char;
{$ENDIF}

  ULONG = Cardinal;
  Long = Integer;

  THex1 = 0..$F;
  THex2 = $10..$FF;
  THex3 = $100..$FFF;

{$IFDEF NEXTGEN}
     AnsiString =  UTF8String;
{$ENDIF}

    TProc_APointer = TProc<Pointer>;

    IEventHandler = interface
    ['{2205ED21-A159-4085-8EF5-5C3715A4F6F4}']
       procedure remove;
       procedure invoke(args: Pointer);
       function  GetID: integer;
       property ID: integer read GetID;
    end;

     IEventEmitter = Interface
     ['{1C509C46-A6CC-492E-9117-8BF72F10244C}']
       function on_(id: integer; p: TProc_APointer) : IEventHandler; overload;
       function on_(id: integer; p : Tproc) : IEventHandler; overload;
       function once(id: integer; p : TProc) : IEventHandler; overload;
       function once(id: integer; p : TProc_APointer) : IEventHandler;overload;
       procedure RemoveAll;
       function isEmpty: Boolean;
       function CountOf(id : integer) : int64;
       procedure emit(eventId: integer; eventArguments : Pointer = nil);
     end;

   let<T> = record
   type
     TLetMethod = procedure(a1:T) of object;
     class function call(a:T; proc: TProc<T> ) : TProc; overload; static;
     class function call(a:T; proc: TLetMethod ) : TProc;overload; static;
   end;
   let<T,T2> = record
     type TLetMethod = procedure(a:T;a2:T2) of object;
     class function call(a:T; a2:T2; proc: TProc<T,T2> ) : TProc; overload; static;
     class function call(a:T; a2:T2; proc: TLetMethod ) : TProc; overload; static;
   end;
   let<T,T2,T3> = record
     type TLetMethod = procedure(a:T;a2:T2;a3:T3) of object;
     class function call(a:T; a2:T2; a3:T3; proc: TProc<T,T2,T3> ) : TProc; overload; static;
     class function call(a:T; a2:T2; a3:T3; proc: TLetMethod ) : TProc; overload; static;
   end;
   let<T,T2,T3,T4> = record
     type TLetMethod = procedure(a1:T;a2:T2;a3:T3;a4:T4) of object;
     class function call(a:T; a2:T2; a3:T3; a4:T4; proc: TProc<T,T2,T3,T4> ) : TProc; overload; static;
     class function call(a:T; a2:T2; a3:T3; a4:T4; proc: TLetMethod ) : TProc; overload; static;
   end;

function h2o(h:THex1) : word; inline; overload;
function h2o(h:THex2) : word; inline; overload;
function h2o(h:THex3) : word; inline; overload;

function CStrLen(const str: PAnsiChar) : SIZE_T;
function CStrUtf8( const p: PUtf8Char) : UTF8String;

procedure scope(const proc: TProc );


var
  g_FormatUs : TFormatSettings;

implementation

function h2o(h:THex1) : word;
begin
    result := h and 7;
end;

function h2o(h:THex2) : word;
begin
    result := (h and 7) or (h and $70 shr 1);
end;
function h2o(h:THex3) : word;
begin
    result := (h and 7) or (h and $70 shr 1) or (h and $700 shr 2);
end;


function CStrLen(const str: PAnsiChar) : SIZE_T;
var
  ch : PAnsiChar;
begin
  if str = nil then
    exit(0);
  ch := Str;
  while ch^ <> #0 do
    inc(ch);
  result := (ch-str);
end;

function CStrUtf8( const p: PUtf8Char) : UTF8String;
begin
   result := UTF8String(p);
end;


procedure scope(const proc: TProc );
begin
  if assigned(proc) then
    proc();
end;

   class function let<T>.call(a: T; proc:TProc<T> ) : TProc;
   begin
      result:= procedure
               begin
                 if assigned(proc) then
                    proc(a);
               end;
   end;
  class function let<T>.call(a: T; proc: TLetMethod): TProc;
  begin
      result:= procedure
               begin
                 if assigned(proc) then
                    proc(a);
               end;
  end;

   class function let<T,T2>.call(a: T; a2:T2; proc:TProc<T,T2> ) : TProc;
   begin
      result:= procedure
               begin
                 if assigned(proc) then
                   proc(a,a2);
               end;
   end;
   class function let<T,T2>.call(a: T; a2:T2; proc:TLetMethod ) : TProc;
   begin
      result:= procedure
               begin
                 if assigned(proc) then
                   proc(a,a2);
               end;
   end;
   class function let<T,T2,T3>.call(a: T; a2:T2; a3:T3; proc:TProc<T,T2,T3> ) : TProc;
   begin
      result:= procedure
               begin
                 if assigned(proc) then
                   proc(a,a2,a3);
               end;
   end;
   class function let<T,T2,T3>.call(a: T; a2:T2; a3:T3; proc:TLetMethod ) : TProc;
   begin
      result:= procedure
               begin
                 if assigned(proc) then
                   proc(a,a2,a3);
               end;
   end;
   class function let<T,T2,T3,T4>.call(a: T; a2:T2; a3:T3; a4:T4; proc:TProc<T,T2,T3,T4> ) : TProc;
   begin
      result:= procedure
               begin
                 if assigned(proc) then
                    proc(a,a2,a3,a4);
               end;
   end;
   class function let<T,T2,T3,T4>.call(a: T; a2:T2; a3:T3; a4:T4; proc:TLetMethod ) : TProc;
   begin
      result:= procedure
               begin
                 if assigned(proc) then
                    proc(a,a2,a3,a4);
               end;
   end;



initialization
   g_FormatUs := TFormatSettings.Create('en-US');

end.
