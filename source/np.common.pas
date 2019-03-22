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


function h2o(h:THex1) : word; inline; overload;
function h2o(h:THex2) : word; inline; overload;
function h2o(h:THex3) : word; inline; overload;

function CStrLen(const str: PAnsiChar) : SIZE_T;
function CStrUtf8( const p: PUtf8Char) : UTF8String;

procedure scope(const proc: TProc );


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


end.
