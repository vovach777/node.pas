unit np.buffer;
{$R-,Q-}
interface
  uses sysUtils, np.ut,classes;

  type
     PBufferRef = ^BufferRef;
     BufferRef = record
     private
        __ref__ : TBytes;
     public
        ref  : PByte;
        length : integer;
        procedure TrimL(_size : integer); inline;
        procedure TrimR(_size : integer); inline;
        function HasSize(count : integer) : Boolean; overload;
        function HasSize<T> : Boolean; overload; inline;
        function slice(offs,_size:integer) :BufferRef; overload;
        function slice(offs:integer) : BufferRef; overload;
        function slice : BufferRef; overload; inline;
        function sliceBytes : TBytes; overload;
        procedure write(idx:integer; const buf: BufferRef);
        procedure write_as<T>(idx:integer; const v: T);
        function unpack<T> : T; overload; inline;
        function unpack<T>(idx:integer) : T; overload;inline;
        function read(idx,size:integer; var data) : integer;
        function ToString: string;
        function ToBytes : TBytes;  //return allways copy
        function ToHex : UTF8String;
        function AsUtf8String : UTF8String;
        function asRawByteString: RawByteString;
        function AsString(code_page:integer) : string; overload;
        function AsString(const code_page:string)  : string; overload;
        function Find(const Sub : BufferRef) : Integer;
        function Same(const buf : BufferRef) : Boolean;
        procedure Fill(value: Byte);
        function minimalize( max_size : integer ) : BufferRef;
        function maximalize : BufferRef;
        function HashOf: cardinal; //jenkins_one_at_a_time_hash
        class function CreateWeakRef(mem:pointer; mem_sz : Cardinal) : BufferRef; static;
        class function Pack<T>(var w:T) : BufferRef; static;
        class function Create(const ref :TBytes) : BufferRef; static;
        function ToBase64: string;
     end;

     Buffer = record
     public
        class function Null : BufferRef; static;
        class function Create(_Length : Cardinal) : BufferRef; overload; static;
        class function Create(const b : array of byte) : BufferRef;overload; static;
        class function Create(mem: Pointer; _length: Cardinal) : BufferRef; overload; static;
        class function Create(const s : string; cp : word = CP_UTF8) : BufferRef; overload; static;
        class function Create(const s : string; const fmt: array of const; cp : word = CP_UTF8) : BufferRef; overload; static;
        class function Create(const ref : BufferRef) : BufferRef; overload; static;
        class function Create(const list : array of BufferRef) : BufferRef; overload; static;
        class function CreateFromHex(const hexStr : UTF8String) : BufferRef; static;
        class function Create(stream:TStream) : BufferRef; overload; static;
{$IFDEF MSWINDOWS}
        class function CreateFromRCDATA(const resourceId: string): BufferRef; static;
{$ENDIF}
        class function pack<T>(const w:T) : BufferRef; static;
     end;

     procedure optimized_append(var buf: BufferRef; const append: BufferRef);

implementation
  uses np.NetEncoding, Types; //HexToBin

{ Buffer }

class function Buffer.Create(const b: array of byte) : BufferRef;
begin
  if High(b) >= 0 then
    result := Buffer.Create(@b[0],High(b)+1)
  else
    result := Buffer.Null;
end;

class function Buffer.Create(_Length: Cardinal) : BufferRef;
var
  bytes : TBytes;
begin
  if _Length = 0 then
    exit(Null);
  SetLength(bytes,_length);
  result := BufferRef.Create(bytes);
end;

class function Buffer.Create(const s: string; cp: word) : BufferRef;
begin
  with TEncoding.GetEncoding(cp) do
  try
    result := BufferRef.Create(GetBytes(s));
  finally
    Free;
  end;
end;

class function Buffer.Null: BufferRef;
begin
   result := default(BufferRef);
end;

class function Buffer.pack<T>(const w: T): BufferRef;
begin
   result := Buffer.Create(@w,sizeof(w));
end;

class function Buffer.Create(const ref: BufferRef) : BufferRef;
begin
  if ref.length = 0 then
    result := Buffer.Null
  else
    result := Buffer.Create(ref.ref,ref.length);
end;

class function Buffer.CreateFromHex(const hexStr : UTF8String) : BufferRef;
var
  bytes : TBytes;
begin
   setLength(bytes, Length(hexStr));
   move(hexStr[1],bytes[0], Length(hexStr) );
   result := Buffer.Create(system.length(hexStr) div 2);
   HexToBin(bytes , 0,  result.__ref__, 0, result.length );
end;

class function Buffer.Create(mem: Pointer; _length: Cardinal) : BufferRef;
begin
  result := Buffer.Create(_length);
  if _length > 0 then
  begin
    move(mem^,result.ref^,_length);
  end;
end;

class function Buffer.Create(const list: array of BufferRef) : BufferRef;
var
  i,j,len : integer;
  bytes: TBytes;
begin
   //pass 1: calc length
   len := 0;
   for I := 0 to High(list) do
      inc(len, list[i].length );
   SetLength(bytes,len);
   //pass 2: concat
   j := 0;
   for I := 0 to High(list) do
   begin
      len := list[i].length;
      if len > 0 then
      begin
         assert( assigned( list[i].ref ));
         move(list[i].ref^,bytes[j],len);
         inc(j,len);
      end;
   end;
   result := BufferRef.Create(bytes);
end;

{$IFDEF MSWINDOWS}
class function Buffer.CreateFromRCDATA(const resourceId: string): BufferRef;
begin
  with TResourceStream.Create(HInstance,resourceId, RT_RCDATA) do
  try
    result := Buffer.Create(size);
    ReadBuffer(result.ref^,result.length);
  finally
    free;
  end;
end;
{$ENDIF}
class function Buffer.Create(stream: TStream): BufferRef;
var
  bytes : TBytes;
begin
  if assigned(stream) then
  begin
    Setlength(bytes,stream.Size);
    stream.Position := 0;
    stream.ReadBuffer(bytes[0],length(bytes));
    result := BufferRef.Create(bytes);
  end
  else
    result := Buffer.Null;
end;

class function Buffer.Create(const s: string;
                              const fmt: array of const;
                              cp: word): BufferRef;
begin
  result := Buffer.Create(Format(s,fmt),cp);
end;

{ BufferRef }

function BufferRef.AsString(code_page: integer): string;
begin
  with TEncoding.GetEncoding(code_page) do
  try
    exit( getString(toBytes) );
  finally
    free;
  end;
end;

function BufferRef.asRawByteString: RawByteString;
begin
  if length > 0 then
  begin
    setLength(result, length);
    move(ref^,result[1],length);
  end
  else
    result := '';
end;

function BufferRef.AsString(const code_page: string): string;
begin
//no copy version:  exit( TEncoding.Default.GetString(__ref__, ref - PBYTE(@__ref__[0]), length) );
  if code_page = '' then
    exit( TEncoding.Default.GetString( ToBytes ) );
  with TEncoding.GetEncoding(code_page) do
  try
    exit( getString(toBytes) );
  finally
    free;
  end;
end;

function BufferRef.AsUtf8String: UTF8String;
begin
  if length > 0 then
  begin
    setLength(result, length);
    move(ref^,result[1],length);
  end
  else
    result := '';
end;

class function BufferRef.Create(const ref: TBytes): BufferRef;
begin
  if system.length(ref) = 0 then
    exit(Buffer.Null);
  result.__ref__ := ref;
  result.length := system.length( result.__ref__ );
  result.ref  := @ref[0];
end;

class function BufferRef.CreateWeakRef(mem: pointer; mem_sz: Cardinal): BufferRef;
begin
  result.ref := mem;
  result.length := mem_sz;
  result.__ref__ := nil;
end;

procedure BufferRef.Fill(value: Byte);
begin
  if Length > 0 then
  begin
    fillchar(ref^,Length,value);
  end;
end;

function BufferRef.Find(const Sub: BufferRef): Integer;
var
  len : integer;
begin
  len := length;
  result := 0;
  while len >= Sub.length do
  begin
    if CompareMem(@ref[result],Sub.ref ,Sub.length ) then
      exit;
    inc(result);
    dec(len);
  end;
  result := -1;
end;

//uint32_t jenkins_one_at_a_time_hash(char *key, size_t len)
function BufferRef.HashOf: cardinal;
var
  hash : cardinal;
  i : integer;
begin
  hash := 0;
  for i := 0 to length-1 do
  begin
    inc(hash, ref[i]);
    inc(hash, hash shl 10);
    hash := hash xor (hash shr 6);
  end;
  inc(hash, hash shl 3);
  hash := hash xor (hash shr 11);
  inc(hash, hash shl 15);
  result := hash;
end;

function BufferRef.HasSize(count: integer): Boolean;
begin
  result := length >= count;
end;

function BufferRef.HasSize<T>: Boolean;
begin
  result := HasSize(sizeof(T));
end;

function BufferRef.maximalize: BufferRef;
begin
  result := Create(__ref__);
end;

function BufferRef.minimalize(max_size: integer): BufferRef;
begin
  if system.length(__ref__) - length >= max_size then
  begin
//     debugBreak;
     result := Buffer.Create( self )
  end
  else
     result := self;
end;

class function BufferRef.Pack<T>(var w: T): BufferRef;
begin
  result := CreateWeakRef(@w,sizeof(w));
end;

function BufferRef.read(idx, size: integer; var data): integer;
begin
  if size <= 0 then
     exit(0);
  result := length - idx;
  if size < result then
    result := size;
  move(ref[idx],data,result);
end;

function BufferRef.sliceBytes: TBytes;
begin
  result := __ref__;
  if assigned(result) then
  begin
    if ref = @result[0] then
    begin
      if length <> System.length(result) then
         SetLength(result,length);
    end
    else
    begin
       result := copy(result, ref - PBYTE(@__ref__[0]), Length );
    end;
  end
  else
     result := ToBytes;
end;

function BufferRef.Same(const buf: BufferRef): Boolean;
begin
  result := (length = buf.length) and CompareMem(buf.ref,ref,length);
end;

//class function BufferRef.PackWeak<T>(const w: T): BufferRef;
//begin
//   result := CreateWeakRef(@w,sizeof(w));
//end;

function BufferRef.slice: BufferRef;
begin
  result := slice(0,length);
end;

function BufferRef.slice(offs: integer): BufferRef;
begin
  result := slice(offs,length-offs);
end;

function BufferRef.slice(offs, _size: integer): BufferRef;
begin
  result.ref  := ref + offs;
  result.length := _size;
  result.__ref__ := __ref__;
end;

function BufferRef.ToBase64: string;
begin
  if length = 0 then
    result := ''
  else
    result := TNetEncoding.Base64.EncodeBytesToString(ref,length);
end;

function BufferRef.ToBytes: TBytes;
begin
  if (length > 0) and (ref <> nil) then
  begin
    setLength(result, length);
    move(ref^,result[0],length);
  end
  else
    setLength(result, 0);
end;

const HEX : array [0..$F] of UTF8char = ('0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f');
function BufferRef.ToHex: UTF8String;
var
  l : integer;
  src : pbyte;
  dst : pUtf8char;
begin
  l := self.length;
  src := self.ref;
  if (l <= 0) or (src=nil) then
       exit('');
 setLength(result, l*2);
 dst := @result[1];
 while l > 0 do
 begin
    dst^ := HEX[src^ shr 4 and $f];
    inc(dst);
    dst^ := HEX[src^ and $f];
    inc(dst);
    inc(src);
    dec(l);
 end;
end;

function BufferRef.ToString: string;
var
  sb : TStringBuilder;
  lcount : integer;
  lref : PByte;
begin
  if (self.length <= 0) or (self.ref=nil) then
     exit('<NULL>');
  sb := TStringBuilder.Create;
  try
    sb.Append('<BufferRef');
    lref := ref;
    lcount := length;
    while lcount > 0 do
    begin
      sb.AppendFormat(' %.2x',[lref^]);
      inc(lref);
      dec(lcount);
    end;
    sb.Append('>');
    result := sb.ToString;
  finally
    sb.free;
  end;

end;

procedure BufferRef.TrimL(_size: integer);
begin
  inc(ref,_size);
  dec(Length,_size);
end;

procedure BufferRef.TrimR(_size: integer);
begin
  dec(Length,_size);
end;

function BufferRef.unpack<T>(idx: integer): T;
type
  PT = ^T;
begin
   result := PT(ref+idx)^;
end;

function BufferRef.unpack<T>: T;
begin
   result := unpack<T>(0);
end;

procedure BufferRef.write(idx:integer; const buf: BufferRef);
begin
  if buf.length > 0 then
  begin
    if HasSize(idx+buf.length) then
       move(buf.ref^,(ref+idx)^,buf.length)
    else
     raise Exception.Create('no room in buffer');
  end;
end;

procedure BufferRef.write_as<T>(idx:integer; const v: T);
begin
  write(idx, BufferRef.CreateWeakRef(@v,sizeof(v)));
end;


procedure optimized_append(var buf: BufferRef; const append: BufferRef);
var
  avail,idx : integer;
  tmp : BufferRef;
begin
  if append.length <= 0 then
    exit;

  avail := (PByte(@buf.__ref__[0]) + length(buf.__ref__)) - (buf.ref+buf.length);
  if avail >= append.length then
  begin
     idx := buf.length;
     buf.length := buf.length + append.length;
     buf.write(idx,append);
  end
  else
  begin
    avail := buf.length + append.length;
    tmp := Buffer.Create( (avail shr 1 + avail + 16) and not 15);
    tmp.write(0,buf);
    tmp.write(buf.length,append);
    tmp.length := buf.length + append.length;
    buf := tmp;
  end;
end;

end.
