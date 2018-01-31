{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 1995-2015 Embarcadero Technologies, Inc. }
{                                                       }
{*******************************************************}

unit np.NetEncoding;
{$Z1}

interface

uses Classes, SysUtils;

type
  TNetEncoding = class
  private
    class var
      FBase64Encoding: TNetEncoding;
      FHTMLEncoding: TNetEncoding;
      FURLEncoding: TNetEncoding;
    class function GetBase64Encoding: TNetEncoding; static;
    class function GetHTMLEncoding: TNetEncoding; static;
    class function GetURLEncoding: TNetEncoding; static;
//    class destructor Destroy;
  protected
    function DoDecode(const Input, Output: TStream): Integer; overload; virtual;
    function DoDecode(const Input: TBytes): TBytes; overload; virtual;
    function DoDecode(const Input: string): string; overload; virtual; abstract;
    function DoEncode(const Input, Output: TStream): Integer; overload; virtual;
    function DoEncode(const Input: TBytes): TBytes; overload; virtual;
    function DoEncode(const Input: string): string; overload; virtual; abstract;
    function DoDecodeStringToBytes(const Input: string): TBytes; virtual;
    function DoEncodeBytesToString(const Input: TBytes): string; overload; virtual;
    function DoEncodeBytesToString(const Input: Pointer; Size: Integer): string; overload; virtual;
  public
    function Decode(const Input, Output: TStream): Integer; overload;
    function Decode(const Input: TBytes): TBytes; overload;
    function Decode(const Input: string): string; overload;
    function Encode(const Input, Output: TStream): Integer; overload;
    function Encode(const Input: TBytes): TBytes; overload;
    function Encode(const Input: string): string; overload;
    function DecodeStringToBytes(const Input: string): TBytes;
    function EncodeBytesToString(const Input: TBytes): string; overload;
    function EncodeBytesToString(const Input: Pointer; Size: Integer): string; overload;
    class property Base64: TNetEncoding read GetBase64Encoding;
    class property HTML: TNetEncoding read GetHTMLEncoding;
    class property URL: TNetEncoding read GetURLEncoding;
  end;

  TBase64Encoding = class(TNetEncoding)
  protected
  const
    kCharsPerLine = 76;

    DecodeTable: array[0..79] of Int8 = (
      62,  -1,  -1,  -1,  63,  52,  53,  54,  55,  56,  57, 58, 59, 60, 61, -1,
      -1,  -1,  -2,  -1,  -1,  -1,   0,   1,   2,   3,   4,  5,  6,  7,  8,  9,
      10,  11,  12,  13,  14,  15,  16,  17,  18,  19,  20, 21, 22, 23, 24, 25,
      -1,  -1,  -1,  -1,  -1,  -1,  26,  27,  28,  29,  30, 31, 32, 33, 34, 35,
      36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46, 47, 48, 49, 50, 51);

    EncodeTable: array[0..63] of Byte = (
      Ord('A'),Ord('B'),Ord('C'),Ord('D'),Ord('E'),Ord('F'),Ord('G'),Ord('H'),Ord('I'),Ord('J'),Ord('K'),Ord('L'),Ord('M'),
      Ord('N'),Ord('O'),Ord('P'),Ord('Q'),Ord('R'),Ord('S'),Ord('T'),Ord('U'),Ord('V'),Ord('W'),Ord('X'),Ord('Y'),Ord('Z'),
      Ord('a'),Ord('b'),Ord('c'),Ord('d'),Ord('e'),Ord('f'),Ord('g'),Ord('h'),Ord('i'),Ord('j'),Ord('k'),Ord('l'),Ord('m'),
      Ord('n'),Ord('o'),Ord('p'),Ord('q'),Ord('r'),Ord('s'),Ord('t'),Ord('u'),Ord('v'),Ord('w'),Ord('x'),Ord('y'),Ord('z'),
      Ord('0'),Ord('1'),Ord('2'),Ord('3'),Ord('4'),Ord('5'),Ord('6'),Ord('7'),Ord('8'),Ord('9'),Ord('+'),Ord('/'));

  type
    TEncodeStep = (EncodeStepA, EncodeStepB, EncodeStepC);
    TDecodeStep = (DecodeStepA, DecodeStepB, DecodeStepC, DecodeStepD);

    TEncodeState = record
      Step: TEncodeStep;
      Result: Byte;
      StepCount: Integer;
    end;

    TDecodeState = record
      Step: TDecodeStep;
      Result: Byte;
    end;

  protected
    FCharsPerline: Integer;
    FLineSeparator: string;

    procedure InitEncodeState(var State: TEncodeState);
    procedure InitDecodeState(var State: TDecodeState);

    function EstimateEncodeLength(const InputLength: UInt64): UInt64;
    function EstimateDecodeLength(const InputLength: UInt64): UInt64;

    function DecodeValue(const Code: Byte): Integer; inline;
    function EncodeValue(const Code: Integer): Byte; inline;

    function EncodeBytes(Input, Output: PByte; InputLen: Integer; CharSize: SmallInt; LineSeparator: array of Byte;
      var State: TEncodeState): Integer;
    function EncodeBytesEnd(Output: PByte; CharSize: SmallInt;
      var State: TEncodeState): Integer;
    function DecodeBytes(Input, Output: PByte; InputLen: Integer; CharSize: SmallInt;
      var State: TDecodeState): Integer;

    function DoDecode(const Input, Output: TStream): Integer; override;
    function DoDecode(const Input: TBytes): TBytes; overload; override;
    function DoDecode(const Input: string): string; overload; override;
    function DoEncode(const Input, Output: TStream): Integer; override;
    function DoEncode(const Input: TBytes): TBytes; overload; override;
    function DoEncode(const Input: string): string; overload; override;
    function DoDecodeStringToBytes(const Input: string): TBytes; override;
    function DoEncodeBytesToString(const Input: TBytes): string; overload; override;
    function DoEncodeBytesToString(const Input: Pointer; Size: Integer): string; overload; override;
  public
    constructor Create; overload; virtual;
    constructor Create(CharsPerLine: Integer); overload; virtual;
    constructor Create(CharsPerLine: Integer; LineSeparator: string); overload; virtual;
  end;

  TURLEncoding = class(TNetEncoding)
  protected
    function DoDecode(const Input: string): string; overload; override;
    function DoEncode(const Input: string): string; overload; override;
  end;

  THTMLEncoding = class(TNetEncoding)
  protected
    function DoDecode(const Input: string): string; overload; override;
    function DoEncode(const Input: string): string; overload; override;
  end;

  EHTTPException = class(Exception)
  end;

implementation

uses
{$IFDEF MSWINDOWS}
  windows,
{$ENDIF}
RTLConsts;

type
  TPointerStream = class(TCustomMemoryStream)
  public
    constructor Create(P: Pointer; Size: Integer);
    function Write(const Buffer; Count: LongInt): LongInt; override;
  end;

{ TNetEncoding }

function TNetEncoding.DoDecode(const Input: TBytes): TBytes;
begin
  if Length(Input) > 0 then
    Result := TEncoding.UTF8.GetBytes(DoDecode(TEncoding.UTF8.GetString(Input)))
  else
    SetLength(Result, 0);
end;

function TNetEncoding.DoDecode(const Input, Output: TStream): Integer;
var
  InBuf: TBytes;
  OutBuf: TBytes;
begin
  if Input.Size > 0 then
  begin
    SetLength(InBuf, Input.Size);
    Input.Read(InBuf[0], Input.Size);
    OutBuf := DoDecode(InBuf);
    Result := Length(OutBuf);
    Output.Write(OutBuf, Result);
    SetLength(InBuf, 0);
  end
  else
    Result := 0;
end;

function TNetEncoding.DoDecodeStringToBytes(const Input: string): TBytes;
begin
  Result := TEncoding.UTF8.GetBytes(DoDecode(Input));
end;

function TNetEncoding.Decode(const Input: TBytes): TBytes;
begin
  Result := DoDecode(Input);
end;

function TNetEncoding.Decode(const Input, Output: TStream): Integer;
begin
  Result := DoDecode(Input, Output);
end;

function TNetEncoding.Decode(const Input: string): string;
begin
  Result := DoDecode(Input);
end;

function TNetEncoding.DecodeStringToBytes(const Input: string): TBytes;
begin
  Result := DoDecodeStringToBytes(Input);
end;

//class destructor TNetEncoding.Destroy;
//begin
//  FreeAndNil(FBase64Encoding);
//  FreeAndNil(FHTMLEncoding);
//  FreeAndNil(FURLEncoding);
//end;

function TNetEncoding.DoEncode(const Input: TBytes): TBytes;
begin
  if Length(Input) > 0 then
    Result := TEncoding.UTF8.GetBytes(DoEncode(TEncoding.UTF8.GetString(Input)))
  else
    SetLength(Result, 0);
end;

function TNetEncoding.DoEncodeBytesToString(const Input: TBytes): string;
begin
  Result := TEncoding.UTF8.GetString(DoEncode(Input));
end;

function TNetEncoding.Encode(const Input: TBytes): TBytes;
begin
  Result := DoEncode(Input);
end;

function TNetEncoding.Encode(const Input, Output: TStream): Integer;
begin
  Result := DoEncode(Input, Output);
end;

function TNetEncoding.Encode(const Input: string): string;
begin
  Result := DoEncode(Input);
end;

function TNetEncoding.EncodeBytesToString(const Input: TBytes): string;
begin
  Result := DoEncodeBytesToString(Input);
end;

function TNetEncoding.EncodeBytesToString(const Input: Pointer; Size: Integer): string;
begin
  Result := DoEncodeBytesToString(Input, Size);
end;

function TNetEncoding.DoEncodeBytesToString(const Input: Pointer; Size: Integer): string;
var
  InStr: TPointerStream;
  OutStr: TBytesStream;
begin
  InStr := TPointerStream.Create(Input, Size);
  try
    OutStr := TBytesStream.Create;
    try
      Encode(InStr, OutStr);
      SetString(Result, PChar(OutStr.Memory), OutStr.Size);
    finally
      OutStr.Free;
    end;
  finally
    InStr.Free;
  end;
end;

function TNetEncoding.DoEncode(const Input, Output: TStream): Integer;
var
  InBuf: TBytes;
  OutBuf: TBytes;
begin
  if Input.Size > 0 then
  begin
    SetLength(InBuf, Input.Size);
    Input.Read(InBuf[0], Input.Size);
    OutBuf := DoEncode(InBuf);
    Result := Length(OutBuf);
    Output.Write(OutBuf, Result);
    SetLength(InBuf, 0);
  end
  else
    Result := 0;
end;

class function TNetEncoding.GetBase64Encoding: TNetEncoding;
var
  LEncoding: TBase64Encoding;
begin
  if FBase64Encoding = nil then
  begin
    LEncoding := TBase64Encoding.Create;
//    if InterlockedCompareExchangePointer(Pointer(FBase64Encoding), Pointer(LEncoding), nil) <> nil then
    if  AtomicCmpExchange(Pointer(FBase64Encoding), Pointer(LEncoding), nil) <> nil then
      LEncoding.Free;
{$IFDEF AUTOREFCOUNT}
    FBase64Encoding.__ObjAddRef;
{$ENDIF AUTOREFCOUNT}
  end;
  Result := FBase64Encoding;
end;

class function TNetEncoding.GetHTMLEncoding: TNetEncoding;
var
  LEncoding: THTMLEncoding;
begin
  if FHTMLEncoding = nil then
  begin
    LEncoding := THTMLEncoding.Create;
    if AtomicCmpExchange(Pointer(FHTMLEncoding), Pointer(LEncoding), nil) <> nil then
      LEncoding.Free;
{$IFDEF AUTOREFCOUNT}
    FHTMLEncoding.__ObjAddRef;
{$ENDIF AUTOREFCOUNT}
  end;
  Result := FHTMLEncoding;
end;

class function TNetEncoding.GetURLEncoding: TNetEncoding;
var
  LEncoding: TURLEncoding;
begin
  if FURLEncoding = nil then
  begin
    LEncoding := TURLEncoding.Create;
    if AtomicCmpExchange(Pointer(FURLEncoding), Pointer(LEncoding), nil) <> nil then
      LEncoding.Free;
{$IFDEF AUTOREFCOUNT}
    FURLEncoding.__ObjAddRef;
{$ENDIF AUTOREFCOUNT}
  end;
  Result := FURLEncoding;
end;

{ TBase64Encoding }

function TBase64Encoding.DecodeValue(const Code: Byte): Integer;
var
  LCode: Integer;
begin
  LCode := Code - 43;
  if (LCode < 0) or (LCode > 80) then
    Result := -1
  else
    Result := DecodeTable[LCode];
end;

function TBase64Encoding.EncodeValue(const Code: Integer): Byte;
begin
  Result := EncodeTable[Code];
end;

function TBase64Encoding.EstimateDecodeLength(const InputLength: UInt64): UInt64;
begin
  Result := InputLength div 4 * 3 + 4;
end;

function TBase64Encoding.EstimateEncodeLength(const InputLength: UInt64): UInt64;
begin
  Result := InputLength div 3 * 4 + 4;
  if FCharsPerLine > 0 then
    Result := Result + Result div FCharsPerLine * Length(FLineSeparator);
end;

function TBase64Encoding.DoDecode(const Input: TBytes): TBytes;
const
  CharSize = SizeOf(Byte);
var
  Len: Integer;
  State: TDecodeState;
begin
  if Length(Input) > 0 then
  begin
    SetLength(Result, EstimateDecodeLength(Length(Input)));
    InitDecodeState(State);
    Len := DecodeBytes(@Input[0], PByte(Result), Length(Input) * CharSize, CharSize, State);
    SetLength(Result, Len);
  end
  else
    SetLength(Result, 0)
end;

constructor TBase64Encoding.Create;
begin
  Create(kCharsPerLine, sLineBreak);
end;

constructor TBase64Encoding.Create(CharsPerLine: Integer);
begin
  Create(CharsPerLine, sLineBreak);
end;

constructor TBase64Encoding.Create(CharsPerLine: Integer; LineSeparator: string);
begin
  FCharsPerline := CharsPerLine;
  FLineSeparator := LineSeparator;
end;

function TBase64Encoding.DecodeBytes(Input, Output: PByte;
  InputLen: Integer; CharSize: SmallInt; var State: TDecodeState): Integer;
var
  POut: PByte;
  Fragment: Integer;
  P, PEnd: PByte;

begin
  POut := Output;
  P := Input;
  PEnd := P + InputLen;
  POut^ := State.Result;
  while True do
  begin
    case State.Step of
      DecodeStepA:
      begin
        repeat
          if P = PEnd then
          begin
            State.Result := POut^;
            Exit(POut - Output);
          end;
          Fragment := DecodeValue(Ord(P^));
          Inc(P, CharSize);
        until (Fragment >= 0) ;
        POut^ := (Fragment and $03F) shl 2;
        State.Step := DecodeStepB;
      end;

      DecodeStepB:
      begin
        repeat
          if P = PEnd then
          begin
            State.Result := POut^;
            Exit(POut - Output);
          end;
          Fragment := DecodeValue(Ord(P^));
          Inc(P, CharSize);
        until (Fragment >= 0) ;
        POut^ := (POut^ or ((Fragment and $030) shr 4));
        Inc(POut);
        POut^ :=           ((Fragment and $00F) shl 4);
        State.Step := DecodeStepC;
      end;

      DecodeStepC:
      begin
        repeat
          if P = PEnd then
          begin
            State.Result := POut^;
            Exit(POut - Output);
          end;
          Fragment := DecodeValue(Ord(P^));
          Inc(P, CharSize);
        until (Fragment >= 0) ;
        POut^ := (POut^ or ((Fragment and $03C) shr 2));
        Inc(POut);
        POut^ :=           ((Fragment and $003) shl 6);
        State.Step := DecodeStepD;
      end;

      DecodeStepD:
      begin
        repeat
          if P = PEnd then
          begin
            State.Result := POut^;
            Exit(POut - Output);
          end;
          Fragment := DecodeValue(Ord(P^));
          Inc(P, CharSize);
        until (Fragment >= 0) ;
        POut^ := (POut^ or (Fragment and $03F));
        Inc(POut);
        State.Step := DecodeStepA;
      end;
    end;
  end;
end;

function TBase64Encoding.DoDecode(const Input, Output: TStream): Integer;
var
  InBuf: array[0..1023] of Byte;
  OutBuf: array[0..767] of Byte;
  BytesRead, BytesWrite: Integer;
  State: TDecodeState;
begin
  InitDecodeState(State);
  Result := 0;
  repeat
    BytesRead := Input.Read(InBuf[0], Length(InBuf));
    BytesWrite := DecodeBytes(@InBuf[0], @OutBuf[0], BytesRead, 1, State);
    Output.Write(Outbuf, BytesWrite);
    Result := Result + BytesWrite;
  until BytesRead = 0;
end;

function TBase64Encoding.DoDecode(const Input: string): string;
begin
  Result := TEncoding.UTF8.GetString(DoDecodeStringToBytes(Input));
end;

function TBase64Encoding.DoDecodeStringToBytes(const Input: string): TBytes;
const
  CharSize = SizeOf(Char);
var
  Len: Integer;
  State: TDecodeState;
begin
  SetLength(Result, EstimateDecodeLength(Length(Input)));
  InitDecodeState(State);
  Len := DecodeBytes(PByte(Input), PByte(Result), Length(Input) * CharSize, CharSize, State);
  SetLength(Result, Len);
end;

function TBase64Encoding.DoEncode(const Input: TBytes): TBytes;
const
  CharSize = SizeOf(Byte);
var
  Len: Integer;
  State: TEncodeState;
  LineSeparator: TBytes;
begin
  if Length(Input) > 0 then
  begin
    LineSeparator := TEncoding.UTF8.GetBytes(FLineSeparator);
    SetLength(Result, EstimateEncodeLength(Length(Input)));
    InitEncodeState(State);
    Len := EncodeBytes(@Input[0], PByte(Result), Length(Input), CharSize, LineSeparator, State);
    Len := EncodeBytesEnd(PByte(PByte(Result) + Len), CharSize, State) + Len;
    SetLength(Result, Len);
  end
  else
    SetLength(Result, 0)
end;

function TBase64Encoding.EncodeBytesEnd(Output: PByte; CharSize: SmallInt;
  var State: TEncodeState): Integer;
var
  POut: PByte;
begin
  POut := Output;
  case State.Step of
    EncodeStepB:
    begin
      POut^ := EncodeTable[State.Result];
      Inc(POut, CharSize);
      POut^ := Byte('=');
      Inc(POut, CharSize);
      POut^ := Byte('=');
      Inc(POut, CharSize);
    end;
    EncodeStepC:
    begin
      POut^ := EncodeTable[State.Result];
      Inc(POut, CharSize);
      POut^ := Byte('=');
      Inc(POut, CharSize);
    end;
  end;
  Result := POut - Output;
end;

function TBase64Encoding.EncodeBytes(Input, Output: PByte; InputLen: Integer; CharSize: SmallInt;
  LineSeparator: array of Byte; var State: TEncodeState): Integer;
var
  B, C: Byte;
  P, PEnd, POut: PByte;
begin
  P := Input;
  PEnd := P + InputLen;
  POut := Output;
  C := State.Result;
  while P <> PEnd do
  begin
    case State.Step of
      EncodeStepA:
      begin
        B := P^;
        Inc(P);
        C := (B and $FC) shr 2;
        POut^ := EncodeValue(C);
        Inc(POut, CharSize);
        C := (B and $3) shl 4;
        State.Step := EncodeStepB;
      end;

      EncodeStepB:
      begin
        B := P^;
        Inc(P);
        C := C or (B and $F0) shr 4;
        POut^ := EncodeValue(C);
        Inc(POut, CharSize);
        C := (B and $F) shl 2;
        State.Step := EncodeStepC;
      end;

      EncodeStepC:
      begin
        B := P^;
        Inc(P);
        C := C or (B and $C0) shr 6;
        POut^ := EncodeValue(C);
        Inc(POut, CharSize);
        C := (B and $3F) shr 0;
        POut^ := EncodeValue(C);
        Inc(POut, CharSize);
        Inc(State.StepCount);
        if (FCharsPerLine > 0) and (State.StepCount >= FCharsPerLine/4)  then
        begin
          Move(LineSeparator[0], POut^, Length(LineSeparator));
          Inc(POut, Length(LineSeparator));
          State.StepCount := 0;
        end;
        State.Step := EncodeStepA;
      end;
    end;
  end;
  State.Result := C;
  Exit(POut - Output);
end;

function TBase64Encoding.DoEncodeBytesToString(const Input: TBytes): string;
begin
  if Length(Input) > 0 then
    Result := EncodeBytesToString(@Input[0], Length(Input))
  else
    Result := '';
end;

function TBase64Encoding.DoEncode(const Input, Output: TStream): Integer;
var
  InBuf: array[0..767] of Byte;
  OutBuf: array[0..1023] of Byte;
  BytesRead, BytesWrite: Integer;
  State: TEncodeState;
  LineSeparator: TBytes;
begin
  LineSeparator := TEncoding.UTF8.GetBytes(FLineSeparator);
  InitEncodeState(State);
  Result := 0;
  repeat
    BytesRead := Input.Read(InBuf[0], Length(InBuf));
    BytesWrite := EncodeBytes(@InBuf[0], @OutBuf[0], BytesRead, 1, LineSeparator, State);
    Output.Write(Outbuf, BytesWrite);
    Result := Result + BytesWrite;
  until BytesRead = 0;
  BytesWrite := EncodeBytesEnd(@OutBuf[0], 1, State);
  Result := Result + BytesWrite;
  Output.Write(Outbuf, BytesWrite);
end;

function TBase64Encoding.DoEncode(const Input: string): string;
begin
  Result := DoEncodeBytesToString(TEncoding.UTF8.GetBytes(Input));
end;

function TBase64Encoding.DoEncodeBytesToString(const Input: Pointer; Size: Integer): string;
const
  CharSize = SizeOf(Char);
var
  Len: Integer;
  State: TEncodeState;
  LineSeparator: TBytes;
  Estimate: Integer;
begin
  LineSeparator := TEncoding.Unicode.GetBytes(FLineSeparator);
  Estimate :=  EstimateEncodeLength(Size);
  SetLength(Result, Estimate);
  FillChar(PChar(Result)^, Estimate * CharSize, 0);
  InitEncodeState(State);
  Len := EncodeBytes(Input, PByte(Result), Size, CharSize, LineSeparator, State);
  Len := EncodeBytesEnd(PByte(PByte(Result) + Len), CharSize, State) + Len;
  SetLength(Result, Len div CharSize);
end;

procedure TBase64Encoding.InitDecodeState(var State: TDecodeState);
begin
  State.Step := DecodeStepA;
  State.Result := 0;
end;

procedure TBase64Encoding.InitEncodeState(var State: TEncodeState);
begin
  State.Step := EncodeStepA;
  State.Result := 0;
  State.StepCount := 0;
end;

{ TURLEncoding }

function TURLEncoding.DoDecode(const Input: string): string;

  function DecodeHexChar(const C: Char): Byte;
  begin
    case C of
       '0'..'9': Result := Ord(C) - Ord('0');
       'A'..'F': Result := Ord(C) - Ord('A') + 10;
       'a'..'f': Result := Ord(C) - Ord('a') + 10;
    else
      raise EConvertError.Create('');
    end;
  end;

  function DecodeHexPair(const C1, C2: Char): Byte; inline;
  begin
    Result := DecodeHexChar(C1) shl 4 + DecodeHexChar(C2)
  end;

var
  Sp, Cp: PChar;
  I: Integer;
  Bytes: TBytes;

begin
  SetLength(Bytes, Length(Input) * 4);
  I := 0;
  Sp := PChar(Input);
  Cp := Sp;
  try
    while Sp^ <> #0 do
    begin
      case Sp^ of
        '+':
          Bytes[I] := Byte(' ');
        '%':
          begin
            Inc(Sp);
            // Look for an escaped % (%%)
            if (Sp)^ = '%' then
              Bytes[I] := Byte('%')
            else
            begin
              // Get an encoded byte, may is a single byte (%<hex>)
              // or part of multi byte (%<hex>%<hex>...) character
              Cp := Sp;
              Inc(Sp);
              if ((Cp^ = #0) or (Sp^ = #0)) then
                raise EHTTPException.CreateFmt('ErrorDecodingURLText', [Cp - PChar(Input)]);
              Bytes[I] := DecodeHexPair(Cp^, Sp^)
            end;
          end;
      else
        // Accept single and multi byte characters
        if Ord(Sp^) < 128 then
          Bytes[I] := Byte(Sp^)
        else
          I := I + TEncoding.UTF8.GetBytes(String(Sp^), 0, 1, Bytes, I) - 1

      end;
      Inc(I);
      Inc(Sp);
    end;
  except
    on E: EConvertError do
      raise EConvertError.CreateFmt('InvalidURLEncodedChar', [Char('%') + Cp^ + Sp^, Cp - PChar(Input)])
  end;
  SetLength(Bytes, I);
  Result := TEncoding.UTF8.GetString(Bytes);
end;

function TURLEncoding.DoEncode(const Input: string): string;
// The NoConversion set contains characters as specificed in RFC 1738 and
// should not be modified unless the standard changes.
const
  NoConversion = [Ord('A')..Ord('Z'), Ord('a')..Ord('z'), Ord('*'), Ord('@'),
                  Ord('.'), Ord('_'), Ord('-'), Ord('0')..Ord('9'), Ord('$'),
                  Ord('!'), Ord(''''), Ord('('), Ord(')'),ord('/'),ord('='),ord('&'),ord('?'),ord(':')];

  procedure AppendByte(B: Byte; var Buffer: PChar);
  const
    Hex = '0123456789ABCDEF';
  begin
    Buffer[0] := '%';
    Buffer[1] := Hex[B shr 4 + 1];
    Buffer[2] := Hex[B and $F + 1];
    Inc(Buffer, 3);
  end;

var
  Sp, Rp: PChar;
  MultibyteChar: TBytes;
  I, ByteCount: Integer;
begin
  // Characters that require more than 1 byte are translated as "percent-encoded byte"
  // which will be encoded with 3 chars per byte -> %XX
  // Example: U+00D1 ($F1 in CodePage 1252)
  //   UTF-8 representation: $C3 $91 (2 bytes)
  //   URL encode representation: %C3%91
  //
  // So the worst case is 4 bytes(max) per Char, and 3 characters to represent each byte
  SetLength(Result, Length(Input) * 4 * 3);
  Sp := PChar(Input);
  Rp := PChar(Result);
  SetLength(MultibyteChar, 4);
  while Sp^ <> #0 do
  begin
    if Ord(Sp^) in NoConversion then
    begin
      Rp^ := Sp^;
      Inc(Rp)
    end
    else {if Sp^ = ' ' then
    begin
      Rp^ := '+';
      Inc(Rp)
    end
    else}
    begin
      if (Ord(Sp^) < 128) then
        // Single byte char
        AppendByte(Ord(Sp^), Rp)
      else
      begin
        // Multi byte char
        ByteCount := TEncoding.UTF8.GetBytes(String(Sp^), 0, 1, MultibyteChar, 0);
        for I := 0 to ByteCount - 1 do
          AppendByte(MultibyteChar[I], Rp);
      end
    end;
    Inc(Sp);
  end;
  SetLength(Result, Rp - PChar(Result));
end;

{ THTMLEncoding }

function THTMLEncoding.DoEncode(const Input: string): string;
var
  Sp, Rp: PChar;
begin
  SetLength(Result, Length(Input) * 10);
  Sp := PChar(Input);
  Rp := PChar(Result);
  // Convert: &, <, >, "
  while Sp^ <> #0 do
  begin
    case Sp^ of
      '&':
        begin
          StrCopy(Rp, '&amp;');
          Inc(Rp, 5);
        end;
      '<':
        begin
          StrCopy(Rp, '&lt;');
          Inc(Rp, 4);
        end;
       '>':
        begin
          StrCopy(Rp, '&gt;');
          Inc(Rp, 4);
        end;
      '"':
        begin
          StrCopy(Rp, '&quot;');
          Inc(Rp, 6);
        end;
      else
      begin
        Rp^ := Sp^;
        Inc(Rp);
      end;
    end;
    Inc(Sp);
  end;
  SetLength(Result, Rp - PChar(Result));
end;

function THTMLEncoding.DoDecode(const Input: string): string;
var
  Sp, Rp, Cp, Tp: PChar;
  S: string;
  I, Code: Integer;
begin
  SetLength(Result, Length(Input));
  Sp := PChar(Input);
  Rp := PChar(Result);
  Cp := Sp;
  try
    while Sp^ <> #0 do
    begin
      case Sp^ of
        '&':
          begin
            Cp := Sp;
            Inc(Sp);
            case Sp^ of
              'a':
                if AnsiStrPos(Sp, 'amp;') = Sp then { do not localize }
                begin
                  Inc(Sp, 3);
                  Rp^ := '&';
                end;
              'l', 'g':
                if (AnsiStrPos(Sp, 'lt;') = Sp) or (AnsiStrPos(Sp, 'gt;') = Sp)
                then { do not localize }
                begin
                  Cp := Sp;
                  Inc(Sp, 2);
                  while (Sp^ <> ';') and (Sp^ <> #0) do
                    Inc(Sp);
                  if Cp^ = 'l' then
                    Rp^ := '<'
                  else
                    Rp^ := '>';
                end;
              'q':
                if AnsiStrPos(Sp, 'quot;') = Sp then { do not localize }
                begin
                  Inc(Sp, 4);
                  Rp^ := '"';
                end;
              '#':
                begin
                  Tp := Sp;
                  Inc(Tp);
                  while (Sp^ <> ';') and (Sp^ <> #0) do
                    Inc(Sp);
                  SetString(S, Tp, Sp - Tp);
                  Val(S, I, Code);
                  if I >= $10000 then
                  begin
                    // DoDecode surrogate pair
                    Rp^ := Char(((I - $10000) div $400) + $D800);
                    Inc(Rp);
                    Rp^ := Char(((I - $10000) and $3FF) + $DC00);
                  end
                  else
                    Rp^ := Chr((I));
                end;
            else
              raise EConvertError.CreateFmt('InvalidHTMLEncodedChar',
                [Cp^ + Sp^, Cp - PChar(Input)])
            end;
          end
      else
        Rp^ := Sp^;
      end;
      Inc(Rp);
      Inc(Sp);
    end;
  except
    on E: EConvertError do
      raise EConvertError.CreateFmt('InvalidHTMLEncodedChar',
        [Cp^ + Sp^, Cp - PChar(Input)])
  end;
  SetLength(Result, Rp - PChar(Result));
end;

{ TPointerStream }

constructor TPointerStream.Create(P: Pointer; Size: Integer);
begin
  SetPointer(P, Size);
end;

function TPointerStream.Write(const Buffer; Count: LongInt): LongInt;
var
  Pos, EndPos, Size: LongInt;
  Mem: Pointer;
begin
  Pos := Self.Position;
  if (Pos >= 0) and (Count > 0) then
  begin
    EndPos := Pos + Count;
    Size := Self.Size;
    if EndPos > Size then
      raise EStreamError.CreateRes(@SMemoryStreamError);
    Mem := Self.Memory;
    System.Move(Buffer, Pointer(Longint(Mem) + Pos)^, Count);
    Self.Position := Pos;
    Result := Count;
    Exit;
  end;
  Result := 0;
end;

initialization

finalization
 //No Class destructor
  freeAndNil( TNetEncoding.FBase64Encoding );
  freeAndNil( TNetEncoding.FHTMLEncoding);
  freeAndNil( TNetEncoding.FURLEncoding);


end.

