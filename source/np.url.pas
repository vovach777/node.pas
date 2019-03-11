unit np.url;
Interface
  uses np.Buffer, sysUtils;

  type
    TNameValue = record
                  Name : string;
                  Value : string;
                 end;
    TNameValues = TArray<TNameValue>;
    EURL = class(Exception);
    TURL = record
    private
       FSchema: string;
       FUserName: string;
       FPassword: string;
       FHostName: String;
       FHost : String;
       FPort: word;
       FParams: TNameValues;
       FPath : String;
       FfullPath : String;
       FSplitPath : TArray<String>;
       function GetPort: word;
       function GetSplitPath : TArray<String>;
    public
       procedure Parse(const AURL: BufferRef); overload;
       procedure Parse(const AURL: String); overload;
       class function _DecodeURL(const s : string) : string; static;
       function HttpHost: string;
       function IsDefaultPort: Boolean;
       function HasCredentials : Boolean;
       function TryGetParam(const AName : String; Out AValue: String; CaseSens:Boolean = false) : Boolean;
       function ToString : string;
       property Schema : string read FSchema;
       property UserName: string read FUserName;
       property HostName: string read FHostName;
       property Host : string read FHost;
       property Port: word read GetPort;
       property Path: string read FPath;
       property SplitPath : TArray<String> read GetSplitPath;
       property FullPath: string read FFullPath;
       property Params: TNameValues read FParams;
    end;

implementation
  uses np.ut, np.NetEncoding;


function _dec(Input: BufferRef): UTF8String;

  function DecodeHexChar(const C: UTF8Char): Byte;
  begin
    case C of
       '0'..'9': Result := Ord(C) - Ord('0');
       'A'..'F': Result := Ord(C) - Ord('A') + 10;
       'a'..'f': Result := Ord(C) - Ord('a') + 10;
    else
      raise EConvertError.Create('');
    end;
  end;

  function DecodeHexPair(const C1, C2: UTF8Char): UTF8Char; inline;
  begin
    Result := UTF8Char( DecodeHexChar(C1) shl 4 + DecodeHexChar(C2) );
  end;

var
  I: Integer;
begin
  SetLength(result, Input.length * 4);
  I := 1;
  while (Input.length > 0) and (I <= Length(result)) do
  begin
    case UTF8Char(Input.ref^) of
      '+':
        result[I] := ' ';
      '%':
        begin
          Input.TrimL(1);
          // Look for an escaped % (%%)
          if UTF8Char(Input.ref^) = '%' then
            result[I] := '%'
          else
          begin
            // Get an encoded byte, may is a single byte (%<hex>)
            // or part of multi byte (%<hex>%<hex>...) character
            if (Input.length < 2) then
              break;
            result[I] := DecodeHexPair( UTF8Char( Input.ref[0] ),  UTF8Char( Input.ref[1] ));
            Input.TrimL(1);
          end;
        end;
    else
       result[I] :=  UTF8Char(Input.ref^)
    end;
    Inc(I);
    Input.TrimL(1);
  end;
  SetLength(result, I-1);
end;


{ TURL }

procedure TURL.Parse(const AURL: BufferRef);
var
  I,paramCount,k : integer;
  url,hostPort,Auth,Path,Params: BufferRef;
  hasColon,eop:Boolean;
begin
  self := default(TURL);
  url := Buffer.Create([AURL,Buffer.Create([0])]);
  I :=  url.Find( Buffer.Create('://') );
  if i >= 0 then
  begin
    FSchema := LowerCase( url.slice(0,I).AsUtf8String );
    url.TrimL(I+3);
  end;
  Auth := Buffer.Null;
  hostPort := Buffer.Null;
  path := Buffer.Null;
  Params := Buffer.Null;
  I := 0;
  repeat
    case url.ref[i] of
    ord('/'),ord('?'),0:
    begin
      hostPort := url.slice(0,i);
      url.TrimL(i);
      I := 0;
      break;
    end;
    ord('@'):
      if (Auth.length=0) then
      begin
        Auth := url.slice(0,i);
        url.TrimL(I+1);
        I:=0;
        continue;
      end;
    end;
    inc(i);
  until false;

  repeat
    case url.ref[i] of
    ord('?'),0:
      begin
        path := url.slice(0,i);
        FfullPath := _dec(url.slice(0,url.length-1) );
        url.TrimL(i);
        I := 0;
        break;
      end;
    end;
    inc(i);
  until false;

  FPath := _dec(path);

  repeat
    case url.ref[i] of
    ord('#'),0:
      begin
        params := url.slice(0,i);
        url.TrimL(i);
        I := 0;
        break;
      end;
    end;
    inc(i);
  until false;
//  WriteLn('Schema: ', FSchema);
//  WriteLn('Auth: ', Auth.AsString(CP_USASCII));

  if Auth.length > 0 then
  begin
    hasColon := false;
    for i := 0 to Auth.length-1 do
    begin
      if auth.ref[i] = ord(':') then
      begin
        hasColon := true;
        FUserName := _dec(Auth.slice(0,i));
        FPassword := _dec(Auth.slice(i+1));
        break;
      end;
    end;
    if not hasColon then
       FUserName := _dec( Auth );
  end;
  if Params.length > 0 then
  begin
    paramCount := 1;
    Params.TrimL(1);
    for i := 0 to Params.length-1 do
      if params.ref[i] = ord('&') then
        inc(paramCount);
    SetLength( FParams, paramCount);
    i := 0;
    k := 0;
    repeat
      eop := (i=params.length) or (params.ref[i] = ord('&'));
      if (Fparams[k].Name = '') and ((params.ref[i] = ord('=')) or eop) then
      begin
          Fparams[k].Name := _dec( params.slice(0,i));
          params.TrimL(i+1);
          i := 0;
      end
      else
      if (Fparams[k].Value = '') and (eop) then
      begin
          Fparams[k].Value := _dec(params.slice(0,i));
          params.TrimL(i+1);
          i := 0;
      end
      else
         inc(i);
      if eop then
        inc(k);
    until k = paramCount;
  end;

  FHost := _dec( hostPort );
  if hostPort.length > 0 then
  begin
    hasColon := false;
    for i := 0 to hostPort.length-1 do
    begin
      if hostPort.ref[i] = ord(':') then
      begin
        hasColon := true;
        FHostName := _dec( hostPort.slice(0,i) );
        FPort := StrToIntDef( hostPort.slice(i+1).AsUtf8String, 0) and $FFFF;
        break;
      end;
    end;
    if not hasColon then
       FHostName := FHost;
  end;
  if FPath = '' then
    FPath := '/';
end;

procedure TURL.parse(const AURL: String);
begin
   parse(Buffer.Create(AUrl));
end;

function _enc(const s : string ) : string; inline;
begin
   result := TNetEncoding.URL.Encode(s);
end;

function TURL.ToString: string;
begin
   if FSchema <> '' then
     result := FSchema + '://'
   else
      result := '';
   if HasCredentials then
   begin
    result := result + _enc( FUserName )+':'+ _enc( FPassword ) +'@';
   end;
   result := result + _enc(HostName);
   if not IsDefaultPort then
     result := result + ':' + UIntToStr(GetPort);
   result := result + _enc( FfullPath );
end;

function TURL.TryGetParam(const AName: String; out AValue: String;
  CaseSens: Boolean): Boolean;
var
  i : integer;
begin
   result := false;
   for I := 0 to length(FParams)-1 do
   begin
      if (CaseSens and UnicodeSameText(FParams[i].Value,AValue)) or
         (not CaseSens and (FParams[i].Value=AValue)) then
       begin
          AValue := FParams[i].Value;
          exit(true);
       end;
   end;
end;

class function TURL._DecodeURL(const s: string): string;
begin
  try
    // result := TNetEncoding.URL.Decode(s);
     result := _dec(Buffer.Create(s));
  except
    raise EURL.CreateFmt('Can not decode URL %s',[s]);
  end;
end;

function TURL.GetPort: word;
begin
  if FPort <> 0 then
     exit(FPort);
  if SameText(FSchema,'http')  then
     exit(80);
  if SameText(FSchema,'https')  then
     exit(443);
  if SameText(FSchema,'rtsp')  then
     exit(554);
  raise EURL.Create('Uknown Schema');
end;

function TURL.GetSplitPath: TArray<String>;
begin
   if not assigned(FSplitPath) then
   begin
      SplitString(FPath, FSplitPath, ['/']);
   end;
   result := FSplitPath;
end;

function TURL.HasCredentials: Boolean;
begin
   result := (FUserName <> '') or (FPassword <> '');
end;

function TURL.HttpHost: string;
begin
  if SameText(FSchema,'http') and (Port = 80) then
     exit(FHost)
  else
     exit(Format('%s:%u',[FHostName,Port]));

end;

function TURL.IsDefaultPort: Boolean;
begin
  if FSchema = '' then
     exit(true);
  if SameText(FSchema,'http') and (Port = 80) then
     exit(true);
  if SameText(FSchema,'https') and (Port = 443) then
     exit(true);
  if SameText(FSchema,'rtsp') and (Port = 554) then
     exit(true);
  exit(false);
end;

end.
