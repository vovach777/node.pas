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
    function GetPort: word;
    public
       procedure Parse(const AURL: BufferRef); overload;
       procedure Parse(const AURL: String); overload;
       class function DecodeURL(const s : string) : string; static;
       function HttpHost: string;
       property Schema : string read FSchema;
       property UserName: string read FUserName;
       property HostName: string read FHostName;
       property Host : string read FHost;
       property Port: word read GetPort;
       property Path: string read FPath;
       property Params: TNameValues read FParams;
    end;

implementation
  uses np.ut, np.netEncoding;


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
    FSchema := LowerCase( url.slice(0,I).AsString(65001) );
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
        url.TrimL(i);
        I := 0;
        break;
      end;
    end;
    inc(i);
  until false;

  FPath := DecodeURL( path.AsString(CP_USASCII) );

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
        FUserName := DecodeURL(Auth.slice(0,i).AsString(CP_USASCII) );
        FPassword := DecodeURL(Auth.slice(i+1).AsString(CP_USASCII) );
        break;
      end;
    end;
    if not hasColon then
       FUserName := Auth.AsString(CP_USASCII);
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
          Fparams[k].Name := DecodeURL( params.slice(0,i).AsString(CP_USASCII));
          params.TrimL(i+1);
          i := 0;
      end
      else
      if (Fparams[k].Value = '') and (eop) then
      begin
          Fparams[k].Value := DecodeURL(params.slice(0,i).AsString(CP_USASCII));
          params.TrimL(i+1);
          i := 0;
      end
      else
         inc(i);
      if eop then
        inc(k);
    until k = paramCount;
  end;

  FHost := DecodeURL( hostPort.AsString(CP_USASCII) );
  if hostPort.length > 0 then
  begin
    hasColon := false;
    for i := 0 to hostPort.length-1 do
    begin
      if hostPort.ref[i] = ord(':') then
      begin
        hasColon := true;
        FHostName := DecodeURL( hostPort.slice(0,i).AsString(CP_USASCII) );
        FPort := StrToIntDef( hostPort.slice(i+1).AsString(CP_USASCII), 0) and $FFFF;
        break;
      end;
    end;
    if not hasColon then
       FHostName := FHost;
  end;
  if FPath = '' then
    FPath := '/';

//  if (FUserName <> '') and (FPassword <> '') then
//    WriteLn('Auth: ', FUserName,'/',FPassword);
//
////  WriteLn('Host: ', hostPort.AsString(CP_USASCII));
//  for i := 0 to length(FParams)-1 do
//  begin
//    WriteLn('  "', FParams[i].Name,'"=>"',FParams[i].Value,'"');
//  end;
//
//  WriteLn('Path: ', path.AsString(CP_USASCII));
////  WriteLn('Params: ',params.AsString(CP_USASCII));
end;

procedure TURL.parse(const AURL: String);
begin
   parse(Buffer.Create(AUrl, CP_USASCII));
end;

class function TURL.DecodeURL(const s: string): string;
begin
  try
    result := TNetEncoding.URL.Decode(s);
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
  raise EURL.Create('Error Message');
end;

function TURL.HttpHost: string;
begin
  if (FSchema = 'http') and (Port = 80) then
     exit(FHost)
  else
     exit(Format('%s:%u',[FHostName,Port]));

end;

end.
