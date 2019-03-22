unit np.ut;

interface
  uses
    SysUtils;

//  {$IFDEF }
//       type
//         PUTF8Char = _PAnsiChr;
//         UTF8Char = AnsiChar;
//  {$endif}
{$IFNDEF NEXTGEN}
   type
     UTF8Char = AnsiChar;
     PUTF8Char = PAnsiChar;
{$ENDIF}

const
  CP_USASCII = 20127;
  CP_UTF8    = 65001;
 type
   TUnixTime = type int64;
  function FmtTimestamp(Date: TDateTime): String;
  function FmtTimestampISO(Date: TDateTime): String;
  function StringPrefixIs(const prefix, str : string) : Boolean;
  function StringPostfixIs(const postfix, str : string) : Boolean;
  function StrToHex(const s: RawByteString): UTF8String;
  function prettyJSON(const inJson :string) : string;
  function JSONText(const json : string; OnlySpacial: Boolean = false) : string;
  function JSONBoolean(bool : Boolean): string;

{$IFDEF MSWINDOWS}
  function CurrentFileTime : int64;
{$ENDIF}
  function CurrentTimestamp : int64;
  function FileTimeToTimestamp(ft : int64) : int64;
  function TimeStampToDateTime( ts : int64 ) : TDateTime; inline;

  function ClipValue(V,Min,Max: Integer) : Integer; overload;
  function ClipValue(V,Min,Max: int64) : Int64; overload;

  function trimR(const s: String;  trimChars : array of char) : String;
  function charInSet16(ch : char; const chars : array of char) : Boolean;

  function PosEx(const SubStr, Str: string; Skip: INTEGER): Integer; overload;

  procedure OutputDebugStr( const S : String ); overload;
  procedure OutputdebugStr( const S : String; P : Array of const);overload;

  procedure RMove(const Source; var Dest; Count: Integer);
  function WildFind(wild, s: PUTF8Char; count:Integer): TArray<UTF8String>; overload;
  function WildFind(const wild, s: UTF8String; count:Integer): TArray<UTF8String>; overload; inline;
  function WildFindW(wild, s: PChar; count:Integer): TArray<String>; overload;
  function WildFindW(const wild, s: String; count:Integer): TArray<String>; overload; inline;

  function SplitString(const AContent: string;     out AResult : TArray<String>;    Separators : TSysCharSet) : integer; overload;
  function SplitString(const AContent: UTF8String; out AResult : TArray<UTF8String>; Separator : TSysCharSet) : integer; overload;
  function SplitString(const str: UTF8String; Separator : TSysCharSet) : TArray<UTF8String>; overload;
  procedure SetLengthZ(var S : RawByteString; len : integer); overload;
  procedure SetLengthZ(var S : String; len : integer); overload;
  function strrstr(const _find,_string:string) : integer; overload;
  function strrstr(const _find,_string:RawByteString) : integer; overload;

function WildComp(const wild, s: String): boolean;

function compareTicks(old, new : int64): integer;

function StrRemoveQuote(const s :string) : string;

function DecodeJSONText(const JSON : string; var Index: Integer) : string;

function UnicodeSameText(const A1,A2 : String) : Boolean;
type
   TTokenMap = TFunc<string,string>;

function macros(const templ: string; const macroOpen,macroClose: string; const mapFunc : TTokenMap; macroInsideMacro:Boolean=false ) : string;
function trimar(const ar: TArray<string>) : TArray<string>;

implementation
    uses
      {$IFDEF MSWINDOWS}
      windows,
      {$ENDIF}
      {$IFDEF POSIX}
        Posix.SysTime,
      {$ENDIF}
    Classes, DateUtils, Character;

var
   g_TraceEnabled : Boolean = {$IFDEF DEBUG} true {$ELSE} false {$ENDIF} ;

function TimeStampToDateTime( ts : int64 ) : TDateTime;
  begin
     result := IncMilliSecond(UnixDateDelta, ts );
  end;

function ClipValue(V,Min,Max: Integer) : Integer;
begin
  result := V;
  if result > Max then
     result := Max;
  if result < Min then
     result := Min;
end;

function ClipValue(V,Min,Max: Int64) : Int64;
begin
  result := V;
  if result > Max then
     result := Max;
  if result < Min then
     result := Min;
end;


function FmtTimestamp(Date: TDateTime): String;
begin
  try
    Result := FormatDateTime('dd.mm.yy hh:nn:ss.zzz', Date);
  except
    On E:Exception do
       Result := '(invalid)';
  end;
end;

function FmtTimestampISO(Date: TDateTime): String;
begin
  try
    Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', Date);
  except
    On E:Exception do
       Result := '(invalid)';
  end;
end;


function StringPrefixIs(const prefix, str : string) : Boolean;
var
  s1,s2 : PChar;
begin
  s1 := PChar(prefix);
  s2 := PChar(str);
  if s1 = nil then
     exit(s2=nil);

  while s1^=s2^ do
  begin
     inc(s1);
     inc(s2);
     if s1^ = #0 then
       exit(true);
  end;
  exit(false);
end;

function StringPostfixIs(const postfix, str : string) : Boolean;
var
  I1,I2 : integer;
begin
  I1 := length(str);
  I2 := length(postfix);
   while (I2 > 0) and (I1 > 0) and (str[I1] = postfix[I2]) do
   begin
      dec(I1);
      dec(I2);
   end;
 result := I2 = 0;
end;


function StrToHex(const s: RawByteString): UTF8String;
var
  ch : UTF8Char;
begin
  result := '';
  for ch in s do
    result := result + LowerCase( format('%.2x',[(byte(ch))]) );
end;


function prettyJSON(const inJson :string) : string;
var
  s : string;
  i,l : integer;
  ch : Char;
  Quote : Boolean;
  level : integer;
begin
   Quote := False;
   level := 0;
   //pass1 : remove spaces
   for ch in inJSon do
   begin
     if ch = '"' then
     begin
       Quote := not Quote;
       s := s + ch;
       continue;
     end;
     if Quote then
        s := s + ch
     else
     if ord(ch) >= 32 then
       s := s + ch;
   end;
   //pass2 : formating
   Quote := False;
   l := Length(s);
   i := 1;
   while l > 0 do
   begin
     ch := s[i]; inc(i); dec(l);
     if ch = '"' then
     begin
       Quote := not Quote;
       result := result + ch;
       continue;
     end;
     if not Quote then
     begin
       if ch = ':' then
          result := result + ': '
       else
       if ch in ['[','{'] then
       begin
         inc(level);
         result := result + ch + #13#10+StringOfChar(' ',level*2)
       end
       else
       if ch in [']','}'] then
       begin
         dec(level);
         result := result + #13#10 +StringOfChar(' ',level*2);
         if s[i] = ',' then
         begin
           result := result + ch+','#13#10 +StringOfChar(' ',level*2);
           inc(i);
           dec(l);
         end
         else
           result := result + ch;
       end
       else
       if ch = ',' then
         result := result + ch+#13#10+StringOfChar(' ',level*2)
       else
         result := result + ch;
     end
     else
       result := result + ch;
   end;
end;


  function JSONText(const json : string; OnlySpacial: Boolean) : string;
  var
    sb : TStringBuilder;
    ch : char;
  begin
    sb := TStringBuilder.Create;
    try
      for ch in json do
      begin
        case ch of
           //#0..#7:;
           #8:  sb.Append('\b');
           #9:  sb.Append('\t');
           #10: sb.Append('\n');
           //#11:;
           #12: sb.Append('\f');
           #13: sb.Append('\r');
           //#14..#$1f:;
           '"': sb.Append('\"');
           '\': sb.Append('\\');
           '/': sb.Append('\/');
           #$80..#$ffff:
               if OnlySpacial then
                  sb.Append(ch)
               else
                sb.AppendFormat('\u%.4x',[word(ch)]);
           else
             begin
                case ch of
                  #$20..#$7f: sb.Append(ch);
                end;
             end;
        end;
      end;
      result := sb.ToString;
    finally
      sb.Free;
    end;

  end;

function FileTimeToTimestamp(ft : int64) : int64;
begin
  result := (ft-116444736000000000 ) div 10000;
end;

{$IFDEF MSWINDOWS}
function CurrentFileTime : int64;
begin
  GetSystemTimeAsFileTime(TFileTime(result));
end;
function CurrentTimestamp : int64;
begin
  result := FileTimeToTimestamp( CurrentFileTime );
end;
{$ENDIF}

{$IFDEF POSIX}

function CurrentTimestamp : int64;
var
  tv: timeval;
begin
  assert( gettimeofday(tv,nil) = 0);
  result := int64(tv.tv_sec)*1000+(tv.tv_usec div 1000);
end;
{$ENDIF}

//function ReadTextFile(const path: string; encoding : string) : string;
//var
//  fd : THandle;
//  enc : TEncoding;
//  stats : TStats;
//  buf : BufferRef;
//begin
//   stats := fs.statsync(path);
//   buf := Buffer.Create(stats.Size);
//   fd := fs.openSync(path,'>r');
//   buf.length := fs.readSync(fd,buf,0);
//   result := buf.AsString(encoding);
//end;

function charInSet16(ch : char; const chars : array of char) : Boolean;
var
  _ch : char;
begin
   result := false;
   for _ch in chars do
     if _ch = ch then
       exit(true);
end;

function JSONBoolean(bool : Boolean): string;
begin
  if bool  then
    Result := 'true'
  else
    Result := 'false';
end;

function trimR(const s : string; trimChars : array of char) : string;
var
  L : integer;
begin
  L := Length(s);
  while (L>0) and  CharInSet16(s[L], trimChars) do
    dec(L);
  result := copy(s,1,L);
end;


const
 http_day_of_week : array [0..6] of string = ( 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' );
 http_month : array [1..12] of string = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
 var
 g_tickCount : Cardinal = 0;
 g_lock_current_httpTime : integer = 0;


function PosEx(const SubStr, Str: string; Skip: INTEGER): Integer;
var
  SubLen, SrcLen, Len, I, J: Integer;
  C1: Char;
begin
  Result := 0;
  if Skip < 1 then skip := 1;
  if (Pointer(SubStr) = nil) or (Pointer(Str) = nil) then Exit;
  SrcLen := Length(Str);
  SubLen := Length(SubStr);
  if (SubLen <= 0) or (SrcLen <= 0) or (SrcLen < SubLen) then Exit;
  // find SubStr[1] in Str[1 .. SrcLen - SubLen + 1]
  Len := SrcLen - SubLen + 1;
  C1 := PChar(SubStr)[0];
  for I := Skip-1 to Len - 1 do
  begin
    if PChar(Str)[I] = C1 then
    begin
      Result := I + 1;
      for J := 1 to SubLen-1 do
      begin
        if PChar(Str)[I+J] <> PChar(SubStr)[J] then
        begin
          Result := 0;
          break;
        end;
      end;
      if Result <> 0 then
        break;
    end;
  end;
end;

procedure OutputDebugStr( const S : String );
begin
{$IFDEF MSWINDOWS}
{$IFDEF DEBUG}
  if g_TraceEnabled then
    OutputDebugString( PChar( s ) );
{$ENDIF}
{$ENDIF}
end;

procedure OutputdebugStr( const S : String; P : Array of const);
begin
{$IFDEF DEBUG}
  OutputDebugStr( Format(s, p) );
{$ENDIF}
end;

procedure RMove(const Source; var Dest; Count: Integer);
var
  S, D: PByte;
begin
  if Count <= 0 then
    exit;
  S := PByte(@Source);
  D := PByte(@Dest)+Count-1;
  repeat
    D^ := S^;
    inc(s);
    dec(d);
    dec(count);
  until  count = 0;
end;


function WildFind(wild, s: PUTF8Char; count:Integer): TArray<UTF8String>;
var
  mp_i, cp_i : PUTF8Char;
  j : integer;
  match : PUTF8Char;
begin
  setLength(result,0);
  setLength(result,count);
  if count < 0 then
    exit;
  mp_i := nil;
  cp_i := nil;
  match := nil;
  while (s^ <> #0) and (wild^ <> #0) and (wild^ <> '*') do
  begin
     if (wild^ <> s^) and (wild^<>'?') then
         Exit;
     inc(s);
     inc(wild);
  end;
  j := 0;
  while s^ <> #0 do
  begin
   if (wild^ <> #0) and (wild^ = '*')  then
   begin
      if match = nil then
        match := s;
      inc(wild);
      if wild^ = #0 then
        break;
      mp_i := wild;
      cp_i := s+1;
   end
   else
   if (wild^ <> #0) and ((wild^ = s^) or (wild^='?'))  then
   begin
      if (match <> nil) then
      begin
        SetString(result[j],match,s-match);
        match := nil;
        inc(j);
        if j = count then
          exit;
      end;
      inc(wild);
      inc(s);
   end
   else
   begin
      assert(mp_i <> nil);
      assert(cp_i <> nil);
      wild := mp_i;
      s    := cp_i;
      inc(cp_i);
   end;
  end;
  if match <> nil then
  begin
     while s^ <> #0 do
       inc(s);
     SetString(result[j],match,s-match);
  end
end;

function WildFindW(wild, s: PChar; count:Integer): TArray<String>;
var
  mp_i, cp_i : PChar;
  j : integer;
  match : PChar;
begin
  setLength(result,0);
  setLength(result,count);
  if count < 0 then
    exit;
  mp_i := nil;
  cp_i := nil;
  match := nil;
  while (s^ <> #0) and (wild^ <> #0) and (wild^ <> '*') do
  begin
     if (wild^ <> s^) and (wild^<>'?') then
         Exit;
     inc(s);
     inc(wild);
  end;
  j := 0;
  while s^ <> #0 do
  begin
   if (wild^ <> #0) and (wild^ = '*')  then
   begin
      if match = nil then
        match := s;
      inc(wild);
      if wild^ = #0 then
        break;
      mp_i := wild;
      cp_i := s+1;
   end
   else
   if (wild^ <> #0) and ((wild^ = s^) or (wild^='?'))  then
   begin
      if (match <> nil) then
      begin
        SetString(result[j],match,s-match);
        match := nil;
        inc(j);
        if j = count then
          exit;
      end;
      inc(wild);
      inc(s);
   end
   else
   begin
      assert(mp_i <> nil);
      assert(cp_i <> nil);
      wild := mp_i;
      s    := cp_i;
      inc(cp_i);
   end;
  end;
  if match <> nil then
  begin
     while s^ <> #0 do
       inc(s);
     SetString(result[j],match,s-match);
  end
end;

function WildFindW(const wild, s: String; count:Integer): TArray<String>;
begin
  result := WildFindW(PChar(wild),PChar(s), count);
end;

function WildFind(const wild, s: UTF8String; count:Integer): TArray<UTF8String>;
begin
  result := WildFind(PUTF8Char(wild),PUTF8Char(s), count );
end;

function SplitString(const str: UTF8String; Separator : TSysCharSet) : TArray<UTF8String>;
begin
  if SplitString(str,result, Separator) = 0 then
  begin
     SetLength(result,1);
     result[0] := '';
  end;
end;


function SplitString(const AContent: UTF8String; out AResult : TArray<UTF8String>; Separator : TSysCharSet) : integer;
var
  Head, Tail, Content: PUTF8Char;
  EOS: Boolean;
  Item: string;
  InQ : Boolean;
  label LoopInit;
begin
  Result := 0;
  Content := PUTF8Char(AContent);
  Tail := Content;
  inQ := false;
  if Tail^<>#0 then
  repeat
    while (Tail^ = ' ') do
      Inc(Tail);
    Head := Tail;
//    if tail^='"' then
//       inQ := not inQ;
    goto LoopInit;
    while not ((Tail^=#0) or (not InQ and (Tail^ in Separator))) do
    begin
        Inc(Tail);
        LoopInit:
        if tail^='"' then
           inQ := not inQ;
    end;
    EOS := Tail^ = #0;
//    if ((Head^ <> #0) and ((Head <> Tail) or (Tail^=Separator) or )) then
//    begin
      SetString(Item, Head, Tail - Head);
      if Result = Length(AResult) then
          setlength(AResult, result + 16);
      AResult[Result] := Item;
      Inc(Result);
//    end;
    Inc(Tail);
  until EOS;

  setLength(AResult,Result);
end;

function SplitString(const AContent: string; out AResult : TArray<String>; Separators : TSysCharSet) : integer;
var
  Head, Tail, Content: PChar;
  EOS, InQuote: Boolean;
  QuoteChar: Char;
  Item: string;
  LWhiteSpaces: TSysCharSet;
  LSeparators: TSysCharSet;
//  WhiteSpace: TSysCharSet;
begin
  Result := 0;
  Content := PChar(AContent);
  Tail := Content;
  InQuote := false;
  QuoteChar := #0;
  LWhiteSpaces := [' '];
  LSeparators := Separators + [#0, #13, #10, '''', '"'];
  repeat
    while (Tail^ in LWhiteSpaces) do
      Inc(Tail);
    Head := Tail;
    while True do
    begin
      while (InQuote and not ((Tail^ = #0) or (Tail^ = QuoteChar))) or
        not (Tail^ in LSeparators) do
          Inc(Tail);
      if (Tail^ in ['"']) then
      begin
        if (QuoteChar <> #0) and (QuoteChar = Tail^) then
          QuoteChar := #0
        else if QuoteChar = #0 then
          QuoteChar := Tail^;
        InQuote := QuoteChar <> #0;
        Inc(Tail);
      end else Break;
    end;
    EOS := Tail^ = #0;
    if (Head <> Tail) and (Head^ <> #0) then
    begin
      SetString(Item, Head, Tail - Head);
      if Result = Length(AResult) then
          setlength(AResult, result + 16);
      AResult[Result] := Item;
      Inc(Result);
    end;
    Inc(Tail);
  until EOS;
  setLength(AResult,Result);
end;


  procedure SetLengthZ(var S : RawByteString; len : integer);
  var
    prevLen : integer;
  begin
    prevLen := length(s);
    SetLength(s, len);
    if len > prevLen then
      fillchar(s[prevLen+1],len-prevLen,0);
  end;

  procedure SetLengthZ(var S : String; len : integer);
  var
    prevLen : integer;
  begin
    prevLen := length(s);
    SetLength(s, len);
    if len > prevLen then
      fillchar(s[prevLen+1],(len-prevLen)*2,0);
  end;


(*
** find the last occurrance of find in string
*)
function strrstr(const _find,_string:string) : integer;
var
  stringlen, findlen,i : integer;
  find,str,cp : PChar;
begin
	findlen := Length(_find);
  find := PChar(_find);
  str  := PChar(_string);
	stringlen := length(_string);
	if (findlen > stringlen) then
		exit(0);
  cp := str + stringlen - findlen;
	while (cp >= str) do
  begin
     i := findLen-1;
     while (i >= 0) and (cp[i] = find[i]) do
       dec(i);
     if i < 0 then
        exit(cp-str+1);
     dec(cp);
  end;
  exit(0);
end;

function strrstr(const _find,_string:RawByteString): Integer;
var
  stringlen, findlen,i : integer;
  find,str,cp : PUTF8Char;
begin
  findlen := Length(_find);
  find := PUTF8Char(_find);
  str  := PUTF8Char(_string);
	stringlen := length(_string);
	if (findlen > stringlen) then
		exit(0);
  cp := str + stringlen - findlen;
  while (cp >= str) do
  begin
     i := findLen-1;
     while (i >= 0) and (cp[i] = find[i]) do
       dec(i);
     if i < 0 then
        exit(cp-str+1);
     dec(cp);
  end;
  exit(0);
end;

//function WildComp(const WildS,IstS: String): boolean;
//var
//  i, j, l, p : integer;
//begin
//  i := 1;
//  j := 1;
//  while (i<=length(WildS)) do
//  begin
//    if WildS[i]='*' then
//    begin
//      if i = length(WildS) then
//      begin
//        result := true;
//        exit
//      end
//      else
//      begin
//        { we need to synchronize }
//        l := i+1;
//        while (l < length(WildS)) and (WildS[l+1] <> '*') and (WildS[l+1] <> '?') do
//          inc (l);
//        p := pos (copy (WildS, i+1, l-i), IstS);
//        if p > 0 then
//        begin
//          j := p-1;
//        end
//        else
//        begin
//          result := false;
//          exit;
//        end;
//      end;
//    end
//    else
//    if (WildS[i]<>'?') and ((length(IstS) < i)
//      or (WildS[i]<>IstS[j])) then
//    begin
//      result := false;
//      exit
//    end;
//
//    inc (i);
//    inc (j);
//  end;
//  result := (j > length(IstS));
//end;

function WildComp(const wild, s: String): boolean;
var
  i_w,i_s : integer;
  l_w,l_s : integer;
  mp_i : integer;
  cp_i : integer;
begin
  i_w := 1;
  i_s := 1;
  l_w := Length(wild);
  l_s := Length(s);
  mp_i := MAXINT;
  cp_i := MAXINT;

  while (i_s <= l_s) and (i_w <= l_w) and (wild[i_w] <> '*') do
  begin
     if (wild[i_w] <> s[i_s]) and (wild[i_w] <> '?') then
         exit(false);
     inc(i_w);
     inc(i_s);
  end;

  while i_s <= L_s do
  begin
   if (i_w <= L_w) and (wild[i_w] = '*')  then
   begin
      inc(i_w);
      if i_w > L_w then
         exit(true);
      mp_i := i_w;
      cp_i := i_s+1;
   end
   else
   if (i_w <= L_w) and (wild[i_w] = s[i_s]) or (wild[i_w]='?') then
   begin
      inc(i_w);
      inc(i_s);
   end
   else
   begin
      i_w := mp_i;
      i_s := cp_i;
      inc(cp_i);
   end;
  end;

  while (i_w <= L_w) and (wild[i_w] = '*') do
    inc(i_w);

  exit(i_w > L_w);
end;

function compareTicks(old, new : int64): integer;
begin
  if old > new then
     inc(new,$100000000);
  result := new-old;
end;

//procedure SaveToIni(const P : IS20Properties; const Header: String; const ini : String);
//var
//  F : text;
//  S : String;
//  V : Variant;
//  HSync : IS20Locker;
//begin
//  HSync := CreateNamedMutexRS(ini,'file');
//  HSync.Lock;
//  AssignFile(F, ini);
//  Rewrite(F);
//  try
//  WriteLn(F,'[',Header,']');
//  for S in P.SortedKeys do
//  begin
//    if not P.IsNull(S,V) then
//    begin
//      WriteLn(F, S,'=',V);
//    end;
//  end;
//  finally
//    CloseFile(F);
//  end;
//end;
//
//function LoadFromIniSection(const Section : String; const ini : String) : IS20Properties;
//var
//  F : text;
//  S : String;
//  L : INTEGER;
//  V : Variant;
//  lSection : String;
//  tmp : String;
//  SectionMode : Boolean;
//  HSync : IS20Locker;
//begin
//  result := TS20Properties.Create;
//  HSync := CreateNamedMutexRS(ini,'file');
//  HSync.Lock;
//  AssignFile(F, ini);
//  Reset(F);
//  try
//    lSection := '['+Section+']';
//    SectionMode := false;
//    while not Eof(F) and not SectionMode do
//    begin
//      ReadLn(F,S);
//      SectionMode := trim(S) = lSection;
//    end;
//    while not Eof(F) and SectionMode do
//    begin
//      ReadLn(F,S);
//      S:= trim(s);
//      if Copy(S,1,1)<>';' then
//      begin
//        if Copy(S,1,1)+Copy(S,Length(S),1) = '[]' then
//           SectionMode := S = Section;
//        if SectionMode then
//        begin
//          tmp := tmp + S + #13 + #10;
//        end;
//      end;
//    end;
//    result :=  KVParser(tmp);
//  finally
//    CloseFile(F);
//  end;
//end;

function StrRemoveQuote(const s :string) : string;
var
  l : integer;
begin
  l := length(s);
  if (l>1) and (s[1]='"') and (s[l]='"') then
    result := copy(s,2,l-2)
  else
    result := s;
end;

function DecodeJSONText(const JSON : string; var Index: Integer) : string;
var
  L : Integer;
  SkipMode : Boolean;
begin
  result := '';
  if Index < 1 then
     Index := 1;
  SkipMode := true;
  L := Length(JSON);
  While (Index<=L) DO
  BEGIN
    case JSON[Index] of
       '"':
         begin
           Inc(Index); //Skip rigth "
           if not SkipMode then
              break;
           skipMode := false;
         end;
       #0..#$1f:
          INC(Index);//ignore
       '\':
           begin
             if Index+1 <= L then
             begin
                case JSON[Index+1] of
                  '"','\','/' :
                       begin
                         if not skipMode then
                           Result := Result + JSON[Index+1];
                         INC(Index,2);
                       end;
                  'u':
                      begin
                         if not skipMode then
                          Result := Result + char(word(
                             StrToIntDef('$'+copy(JSON,Index+2,4),ord('?'))
                                       ));
                         INC(Index,6);
                      end;
                   'b':
                      begin
                         if not skipMode then
                           Result := Result + #8;
                         INC(Index,2);
                      end;
                   'f':
                      begin
                         if not skipMode then
                           Result := Result + #12;
                         INC(Index,2);
                      end;
                   'n':
                      begin
                        if not skipMode then
                          Result := Result + #10;
                        INC(Index,2);
                      end;
                   'r':
                      begin
                        if not skipMode then
                          Result := Result + #13;
                        INC(Index,2);
                      end;
                   't':
                      begin
                        if not skipMode then
                          Result := Result + #9;
                        INC(Index,2);
                      end;
                   else
                      INC(Index,2); //Ignore
                end;
             end;
           end;
       else
       begin
         if not skipMode then
            Result := Result +  JSON[Index];
         INC(Index);
       end;
    end;
  END;
end;

function UnicodeSameText(const A1,A2 : String) : Boolean;
begin
   result := Char.ToLower(A1) = Char.ToLower(A2);
end;

function macros(const templ: string; const macroOpen,macroClose: string; const mapFunc : TTokenMap; macroInsideMacro:Boolean ) : string;
var
  F,T,SKIP: INTEGER;
  token : string;
  S : string;
begin
  if (macroOpen = '') or (macroClose='') then
      Exit( macros(templ,'${','}',mapFunc));
  S := templ;
  SKIP := 1;
  repeat
    F := PosEx(macroOpen,S,SKIP);
    if (F=0) then
       break;
    T := PosEx(macroClose,S,F+Length(macroOpen));
    if T=0 then
      break;
    token := copy(s,F+Length(macroOpen),(T-F-Length(macroOpen)));
    if assigned(mapFunc) then
      token := mapFunc(token)
    else
      token := '';
    Delete(s,F,(T-F+Length(macroClose)));
    Insert(token,s,F);
    SKIP := F;//+length(token);
    if not macroInsideMacro then
        INC(SKIP,Length(token));
  until false;
  result := s;
end;

function trimar(const ar: TArray<string>) : TArray<string>;
var
  i : integer;
begin
   SetLength(result, length(ar));
   for i := 0 to length(ar)-1 do
     result[i] := trim(ar[i]);
end;


end.

