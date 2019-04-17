unit np.value;

interface
  uses sysUtils, rtti, Math, np.common, Generics.Collections;

  const
    objectId = 'object';
    arrayId  = 'array';
    booleanId = 'boolean';
    undefinedId = 'undefined';
    nullId  = 'null';
    numberId = 'number';
    exceptionId = 'exception';
    stringId = 'string';

  type

  IValue = interface
  ['{D95206A4-BAB8-4ADC-882E-DA66B20FDA82}']
     function RTTI: TValue;
     function ToString : string;
     function GetTypeId : string;
     property TypeId: string read GetTypeId;
  end;

  IValue<T> = interface(IValue)
  ['{3B7468EC-B921-43A7-BBFC-6D6CAE9D5943}']
     function this : T;
  end;

  TSelfValue = class(TInterfacedObject, IValue)
   public
     typeId : string;
     constructor Create();
     function RTTI: TValue; virtual;
     function GetTypeID: string;
  end;


  TValue<T> = class(TSelfValue, IValue<T>)
  public
     Value : T;
     constructor Create(const AValue: T; const AtypeName: string = '');
     function RTTI: TValue; override;
     function this: T;
     function ToString : String; override;
  end;

  TArrayValue = class(TValue<TArray<IValue>>);

  TObjectValue<T:class> = class(TValue<T>)
  public
    function ToString : string; override;
    destructor Destroy; override;
  end;

  TExceptionValue = class(TObjectValue<Exception>)
  public
     constructor Create;
     procedure throw;
  end;

  TRecordValue<T:record> = class(TValue<T>)
  type
    PRef = ^T;
    function Ref : PRef;
  end;

  TAnyObject = class(TObjectValue<TDictionary<string,IValue>>, IValue<TAnyObject>)
  public
    function ToString : String; override;
    constructor Create(); reintroduce;
    procedure setValue(const key:string; const Avalue : IValue);
    function getValue(const Key: string) : IValue;
    function GetKeys : TArray<String>;
    procedure DeleteKey(const AKey:String);
    function EnumKeys : TEnumerable<String>;
    function this: TAnyObject;
    property ValueOf[const key: string] : IValue read GetValue write SetValue; default;
  end;

  TAnyArray = class(TAnyObject, IValue<TAnyArray>)
  private
    FLength: int64;
    FShift:  int64;
  public
     destructor Destroy; override;
     function  GetValueAt( Index: Int64 ) : IValue;
     procedure SetValueAt( Index: Int64; AValue: IValue );
     constructor Create(initialValues : array of const ); overload;
     constructor Create(); reintroduce; overload;
     function ToString: String; override;
     function GetLength : Int64;
     function Pop : IValue;
     function Push(AValue: IValue) : Int64; overload;
     function Push(AValues : array of const) : int64; overload;
     function Map( func : TFunc<IValue,IValue>) : IValue<TAnyArray>;
     procedure forEach( func : TProc<IValue,int64,TAnyArray> ); overload;
     procedure forEach( func : TProc<IValue,int64> ); overload;
     procedure forEach( func : TProc<IValue> ); overload;
     function find( func : TFunc<IValue,int64,TAnyArray,Boolean> ) : IValue; overload;
     function find( func : TFunc<IValue,int64,Boolean> ) : IValue; overload;
     function find( func : TFunc<IValue,Boolean> ): IValue; overload;
     function join(const separator : string=',') : string;
     function splice(start:int64; deleteCount: integer; insert : array of const) : IValue;
     function shift : IValue;
     function unshift(AValue: IValue) : int64; overload;
     function unshift(AValues: array of const) : int64; overload;
     function this: TAnyArray;
     property ValueAt[ Index: int64] : IValue read GetValueAt write SetValueAt; default;
     property Length : int64 read GetLength;
  end;

    TJSONNumber = class(TValue<Double>)
        constructor Create(AValue: Double);
        function ToString : String; override;
    end;

    TJSONBoolean = class(TValue<Boolean>)
        constructor Create(AValue: Boolean);
        function ToString : String; override;
    end;

    TJSONString = class(TValue<String>)
        constructor Create(const AValue: String);
        function ToString : String; override;
    end;

  ObjectWalker = record
     this : IValue;
     function isObject : Boolean;
     function isArray  : Boolean;
     function asNumber: Double;
     function asTrunc: int64;
     function asObject : TAnyObject;
     function asArray  : TAnyArray;
     procedure walk(const prop: string); overload;
     procedure walk(const path: array of string); overload;

  end;

  function JSONNull : IValue;
  function void_0 : IValue;
  function JSONParse(const JSON:String) : IValue; overload;
  function JSONParse(const JSON:String; var I:Integer) : IValue; overload;

  function mkValue( i : int64 ): IValue; overload;
  function mkValue(const s : string): IValue; overload;
  function mkValue(a: TVarRec): IValue; overload;
  function mkValuesOLD(values: array of const) : IValue; deprecated;
  function mkValues(values: array of const) : IValue;
  function spread : IValue;

implementation
  uses np.ut;

{ TValue<T> }

constructor TValue<T>.Create(const AValue: T; const ATypeName : string);
  begin
     inherited Create;
     if AtypeName <> '' then
       TypeId := ATypeName;
     Value := AValue;
  end;

function TValue<T>.RTTI: TValue;
begin
  result := TValue.From<T>(Value);
end;

function TValue<T>.this : T;
begin
  result := value;
end;

function TValue<T>.ToString: String;
begin
 try
   result := RTTI.ToString;
 except
   result := inherited ToString;
 end;
end;


{ TOBjectValue }

  destructor TOBjectValue<T>.Destroy;
  begin
    if assigned(value) then
      FreeAndNil(Value);
    inherited;
  end;

  function mkValue(i : int64): IValue; overload;
  begin
    Result := TValue<int64>.Create(i,'int64');
  end;

  function mkValue(const s : string): IValue; overload;
  begin
    Result := TValue<string>.Create(s,stringId );
  end;

{ TRecordValue<T> }



function TRecordValue<T>.Ref: PRef;
begin
  result := @Value;
end;

  function mkValuesOLD(values: array of const) : IValue;
  var
    i : integer;
    arr : TArray<IValue>;
  begin
    SetLength(arr,High(values)+1);
    for I := 0 to length(Values)-1 do
    begin
      try
         arr[i] := mkValue(values[i]);
      except
         arr[i] := TExceptionValue.Create;
      end;
    end;
    result := TArrayValue.Create(arr);
  end;

  function mkValues(values: array of const) : IValue;
  begin
    result  := TAnyArray.Create(values);
  end;

  function mkValue(a: TVarRec): IValue; overload;
  begin
    case a.VType of
            vtInteger:      result := TJSONNumber.Create(a.VInteger);//TValue<integer>.Create(a.VInteger);
            vtBoolean:      result := TJSONBoolean.Create(a.VBoolean);//  TValue<Boolean>.Create(a.VBoolean);
            vtExtended:     result := TJSONNumber.Create(a.VExtended^); // TValue<Extended>.Create(a.VExtended^);
{$IFNDEF NEXTGEN}
            vtString:       result := TJSONString.Create(a.VString^); // mkValue(a.VString^);
            vtWideString:   result := TJSONString.Create(WideString(a.VWideString)); //TValue<string>.Create(WideString(a.VWideString));
{$ENDIF}
            vtPointer:      result := TValue<Pointer>.Create(a.VPointer);
            vtPChar:        result := TJSONString.Create( String(a.VPChar) ); //TValue<Char>.Create(char(a.VPChar^));
            vtChar:         result := TJSONString.Create( char(a.VChar) + ''); //TValue<Char>.Create(char(a.VChar));
            vtObject:       begin
                               if a.VObject = nil then
                                 result := TValue<TObject>.Create(nil)
                               else
                               if TObject(a.VObject) is TSelfValue then
                                  result := TSelfValue(a.VObject)
                               else
                                 result := TValue<TObject>.Create(a.VObject);
                            end;
            vtClass:        result := TValue<TClass>.Create(a.VClass);
            vtWideChar:     result := TJSONString.Create(Char(a.VWideChar)+'');  //TValue<Char>.Create(a.VWideChar);
            vtPWideChar:    result := TJSONString.Create(String(PChar(a.VPWideChar))); //TValue<Char>.Create(a.VPWideChar^);
            vtAnsiString:   result := TJSONString.Create(AnsiString(a.VAnsiString));//  mkValue( AnsiString(a.VAnsiString));
            vtCurrency:     result := TValue<Currency>.Create(a.VCurrency^);
            vtVariant:      result := TValue<Variant>.Create(a.VVariant^);
            vtInterface:    if a.VInterface = nil then
                                result := nil
                            else
                            if IInterface(a.VInterface).QueryInterface(IValue,result) <> S_OK then
                              result := TValue<IInterface>.Create(IInterface( a.VInterface ));
            vtInt64:        result := TJSONNumber.Create(a.VInt64^); //result := mkValue(a.VInt64^);
            vtUnicodeString: result := TJSONString.Create(string(a.VUnicodeString)); // mkValue(string(a.VUnicodeString));
      else
         result := nil;
    end;
  end;

{ TAnyValue }

function TAnyObject.getValue(const Key: string): IValue;
begin
   if not Value.TryGetValue(Key, result) then
     result := void_0;
end;

constructor TAnyObject.Create();
begin
  inherited Create(TDictionary<String,IValue>.Create, objectId );
end;

procedure TAnyObject.setValue(const key: string; const Avalue: IValue);
begin
   Value.AddOrSetValue(key,AValue);
end;

function TAnyObject.this: TAnyObject;
begin
  result := self;
end;

function TAnyObject.ToString: String;
var
  sb : TStringBuilder;
  i : int64;
  ar : TArray<TPair<String,IValue>>;
  s : string;
begin
  ar := Value.ToArray;
  if Length(ar) = 0 then
    exit('{}');
  sb := TStringBuilder.Create;
  try
     sb.Append('{');
     for I := 0 to Length(ar)-1 do
     begin
       sb.Append('"').Append( ar[i].Key ).Append('"').Append(':');
       if ar[i].Value = nil then
         sb.Append('null')
       else
       if (ar[i].Value is TJSONNumber) or
          (ar[i].Value is TJSONBoolean) or
//          (ar[i].Value is TJSONString) or
          (ar[i].Value is TAnyObject) or
           (ar[i].Value is TValue<Integer>) or
           (ar[i].Value is TValue<Int64>) or
           (ar[i].Value is TValue<UInt64>) or
           (ar[i].Value is TValue<Cardinal>) or
           (ar[i].Value is TValue<Double>) or
           (ar[i].Value is TValue<Extended>) then
             sb.Append(ar[i].Value.ToString)
       else
          sb.AppendFormat('"%s"',[ JSONText( ar[i].Value.ToString, true) ]);
       if i < Length(ar)-1  then
          sb.Append(',')
     end;
     sb.Append('}');
     result := sb.ToString;
  finally
    sb.Free;
  end;
end;

procedure TAnyObject.DeleteKey(const AKey: String);
begin
   value.Remove(AKey);
end;

function TAnyObject.EnumKeys: TEnumerable<String>;
begin
  result := value.Keys;
end;

function TAnyObject.GetKeys: TArray<String>;
begin
   result := value.Keys.ToArray;
end;

{ TAnyArray }

procedure TAnyArray.forEach(func: TProc<IValue, int64, TAnyArray>);
var
  i : integer;
begin
  if assigned(func) then
    for i := 0 to FLength-1 do
    begin
      func(GetValueAt(i),i,self);
    end;
end;

procedure TAnyArray.forEach(func: TProc<IValue, int64>);
var
  i : integer;
begin
  if assigned(func) then
    for i := 0 to FLength-1 do
    begin
      func(GetValueAt(i),i);
    end;
end;

destructor TAnyArray.Destroy;
begin
  inherited;
end;

function TAnyArray.find(func: TFunc<IValue, int64, TAnyArray, Boolean>): IValue;
var
  i : integer;
begin
  if assigned(func) then
    for i := 0 to FLength-1 do
    begin
      if func(GetValueAt(i),i,self) then
        exit( GetValueAt(i) );
    end;
  exit(void_0);
end;

function TAnyArray.find(func: TFunc<IValue, int64, Boolean>): IValue;
var
  i : integer;
begin
  if assigned(func) then
    for i := 0 to FLength-1 do
    begin
      if func(GetValueAt(i),i) then
        exit( GetValueAt(i) );
    end;
  exit(void_0);
end;

function TAnyArray.find(func: TFunc<IValue, Boolean>): IValue;
var
  i : integer;
begin
  if assigned(func) then
    for i := 0 to FLength-1 do
    begin
      if func(GetValueAt(i)) then
        exit( GetValueAt(i) );
    end;
  exit(void_0);
end;

procedure TAnyArray.forEach(func: TProc<IValue>);
var
  i : integer;
begin
  if assigned(func) then
    for i := 0 to FLength-1 do
    begin
      func(GetValueAt(i));
    end;
end;

function TAnyArray.GetLength: Int64;
begin
   result := FLength;
end;

function TAnyArray.GetValueAt(Index: Int64): IValue;
begin
   if Index >= 0 then
     Inc(Index,FShift);
   if not Value.TryGetValue(IntToStr(Index),result) then
     result := nil;
end;

function TAnyArray.join(const separator: string): string;
var
  i : integer;
begin
  if FLength = 0 then
    exit('');
  result := GetValueAt(0).ToString;
  for i := 1 to FLength-1 do
  begin
    result := result + separator + GetValueAt(i).ToString;
  end;
end;

function TAnyArray.Map(func: TFunc<IValue, IValue>): IValue<TAnyArray>;
var
  i : integer;
begin
  result := TAnyArray.Create();
  if not assigned(func) then
     exit;
  for i := 0 to FLength-1 do
  begin
    result.this.SetValueAt(i,  func(GetValueAt(i)));
  end;
end;

constructor TAnyArray.Create(initialValues: array of const);
var
  i : integer;
  spredFlag : Boolean;
  tmp : IValue;
  tmpAsArray: TAnyArray;
begin
   Create;
   spredFlag := false;
   for I := 0 to System.length(InitialValues)-1 do
   begin
      try
         tmp := mkValue(initialValues[i]);
         if tmp = spread then
         begin
            spredFlag := true;
            continue;
         end;
         if spredFlag and (tmp is TAnyArray) then
         begin
            tmpAsArray := tmp as TAnyArray;
            tmpAsArray.forEach(
               procedure (value: IValue)
               begin
                  Push( value );
               end
            );
         end
         else
            Push( tmp );
      except
         push( TExceptionValue.Create );
      end;
      spredFlag := false;
   end;
end;

constructor TAnyArray.Create;
begin
  inherited Create();
  typeId := arrayId;
end;


function TAnyArray.Pop: IValue;
var
  key : string;
begin
  if FLength <= 0 then
    exit(nil);
   key := IntToStr( FLength-1+FShift);
   if value.TryGetValue( key, result) then
      value.Remove( key )
   else
      result := nil;
   Dec(FLength);
end;

function TAnyArray.Push(AValues: array of const): int64;
var
  i : integer;
begin
   for I := 0 to System.length(AValues)-1 do
   begin
      Push( mkValue(Avalues[i]) );
   end;
   result := FLength;
end;

function TAnyArray.Push(AValue: IValue): Int64;
begin
  SetValueAt(FLength,AValue);
  result := FLength;
end;

procedure TAnyArray.SetValueAt(Index: Int64; AValue: IValue);
begin
   if (Index < 0) then
   begin
      Value.AddOrSetValue(IntToStr(Index), AValue);
      exit;
   end;
   Value.AddOrSetValue(IntToStr(Index+FShift), AValue);
   if (Index >= FLength) then
     FLength := Index+1;
end;

function TAnyArray.shift: IValue;
begin
  if FLength <= 0 then
    exit(nil);
  result := GetValueAt(0);
  SetValueAt(0,nil);
  inc(FShift);
  dec(FLength);
end;

function TAnyArray.splice(start: int64; deleteCount: integer;
  insert: array of const): IValue;
var
  insertArray, removeArray: TAnyArray;
  i,k : int64;
  resultLength,actualLength: int64;
begin
  insertArray := TAnyArray.Create( insert );
  removeArray := TAnyArray.Create(  );
  try

   if start < 0 then
      start := FLength+start;
   if start < 0 then
      start := 0;
   if start >= FLength then
   begin
      deleteCount := 0;
      start := FLength;
   end;

   if start + deleteCount > FLength  then
     deleteCount := FLength-start;
   actualLength := FLength;


    resultLength := FLength + InsertArray.Length - deleteCount;

    if (deleteCount > 0) or (InsertArray.Length > 0) then
    begin
      k := start+deleteCount;
      for I := start to actualLength-1 do
      begin
         if i < k then
            removeArray.Push( getValueAt(i) )
         else
            insertArray.Push( getValueAt(i) );
         SetValueAt(i, nil );
      end;

      for i := 0 to insertArray.Length-1 do
      begin
        SetValueAt( start+i, insertArray.GetValueAt(i) );
      end;
    end;

    FLength := resultLength;

  finally
    freeAndNil(insertArray);
    result := removeArray;
  end;

end;

function TAnyArray.this: TAnyArray;
begin
  result := self;
end;

function TAnyArray.ToString: String;
var
  sb : TStringBuilder;
  i : int64;
  s : string;
  value : IValue;
begin
  if FLength <= 0 then
    exit('');
  sb := TStringBuilder.Create;
  try
     sb.Append('[');
     for I := 0 to FLength-1 do
     begin
       value := GetValueAt(i);
       if (Value is TJSONNumber) or
          (Value is TJSONBoolean) or
          //(Value is TJSONString) or
          (Value is TAnyObject) or
           (Value is TValue<Integer>) or
           (Value is TValue<Int64>) or
           (Value is TValue<UInt64>) or
           (Value is TValue<Cardinal>) or
           (Value is TValue<Double>) or
           (Value is TValue<Extended>) then
             sb.Append(Value.ToString)
       else
          sb.AppendFormat('"%s"',[Value.ToString]);

       sb.Append( s );
       if i <> FLength-1 then
         sb.Append(',');
     end;
     sb.Append(']');
     result := sb.ToString;
  finally
    sb.Free;
  end;
end;

function TAnyArray.unshift(AValues: array of const): int64;
var
  i : integer;
begin
   for I := System.length(AValues)-1 downto 0 do
   begin
     unshift(mkValue( AValues[i] ));
   end;
   result := FLength;
end;

function TAnyArray.unshift(AValue: IValue): int64;
begin
  if FLength <= 0 then
  begin
    SetValueAt(0,AValue);
    result := FLength;
  end
  else
  begin
    Dec(FShift);
    Inc(FLength);
    SetValueAt(0,AValue);
    result := FLength;
  end;
end;

function JSONParse(const JSON: string; var I: integer) : IValue;
VAR
  L : INTEGER;
  J:INTEGER;
  K,V: String;
  &object : TAnyObject;
  &array  : TAnyArray;
  LCount : integer;
  Float: Double;
  function ReadToken : String;
  var
    J : Integer;
  begin
     J := I;
     While (I<=L) and not ((JSON[I] in [',','}',']']) or (JSON[I] <= #20)) DO
        INC(I);
     result := Copy(JSON,J,I-J);
  end;

begin
  result := nil;
  if I < 1 then I := 1;
  L := Length(JSON);
  LCount := 0;
  While I<=L DO
  BEGIN
    CASE JSON[I] OF
      '{':
         begin
            INC(I);
            &object := TAnyObject.Create;
            result := &object;
            repeat
              K := DecodeJSONText(JSON,I);
              While (I<=L) and (JSON[I] <> ':') DO INC(I);
              INC(I);
              &object[K] := JSONParse(JSON,I);
              //outputdebugStr(K);
              While (I<=L) and not (JSON[I] in [',','}']) DO INC(I);
              INC(I);
            until not((I<=L) and (I>1) and (JSON[I-1]=','));
         end;
      '[':
         begin
           INC(I);
           &array := TAnyArray.Create;
           result := &array;
           repeat
             &array[LCount] := JSONParse( JSON,I );
             inc(LCount);
             While (I<=L) and not (JSON[I] in [',',']']) DO INC(I);
             INC(I);
           until not((I<=L) and (I>1) and (JSON[I-1]=','));
//           if (LCount = 1) and (&array[0] = nil) then
//             &array.pop();
         end;
      '"':
         begin
            result := TJSONString.Create( DecodeJSONText(JSON,I) );
         end;
        #0..#$20:
           begin
            INC(I);
            continue;
           end
        else
         begin
            V := ReadToken;
            if V = 'null' then
               result := JSONNull
            else
            if V = 'true' then
               result := TJSONBoolean.Create(True)
            else
            if V = 'false' then
               result := TJSONBoolean.Create(False)
            else
            if TryStrToFloat(V,Float, g_FormatUs) then
               result := TJSONNumber.Create(Float)
            else
               result := mkValue(V);
         end;

    END;
    break;
  END;
//  if value = nil then
//     OutputDebugStr('null');
end;

function JSONParse(const JSON : string) : IValue;
var
  i : integer;
begin
  i := 1;
  result := JSONParse(JSON,I);
end;

{ TJSONNumber }

constructor TJSONNumber.Create(AValue: Double);
begin
  inherited Create(AValue,numberId);
end;

function TJSONNumber.ToString: String;
begin
  if Frac(Value) = 0 then
    result := IntToStr( Trunc(Value) )
  else
    result := FloatToStr( Value,g_FormatUS );

end;

{ TJSONBoolean }

constructor TJSONBoolean.Create(AValue: Boolean);
begin
  inherited Create(AValue,booleanId);
end;

function TJSONBoolean.ToString: String;
begin
  result := JSONBoolean(value);
end;

type
    TJSONNull = class(TValue<Pointer>)
        constructor Create();
        function ToString : String; override;
    end;

    TVoid_0 = class(TValue<Pointer>)
        constructor Create();
        function ToString : String; override;
    end;


{ TJSONNull }

constructor TJSONNull.Create;
begin
   inherited Create(nil,nullId);
end;

function TJSONNull.ToString: String;
begin
  result := nullId;
end;

var
  g_null : IValue;
  g_spread : IValue;
  g_void_0 : IValue;

function JSONNull : IValue;
begin
   result := g_null;
end;


function spread : IValue;
begin
  result := g_spread;
end;

function void_0 : IValue;
begin
  result := g_void_0;
end;



{ TJSONString }

constructor TJSONString.Create(const AValue: String);
begin
  inherited Create(AValue,stringId);
end;

function TJSONString.ToString: String;
begin
  result := value;// Format('"%s"',[value{TBoxValue.EncodeJSONText(Value)}]);
end;

{ TExceptionValue }

constructor TExceptionValue.Create;
begin
  inherited Create( Exception(AcquireExceptionObject), exceptionId);
end;

procedure TExceptionValue.throw;
begin
  if assigned(value) then
  begin
    try
       raise value;
    finally
      value := nil;
    end;
  end
  else
    raise Exception.Create('Exception is ready raised! The reference exception was lost!');
end;

function TObjectValue<T>.ToString: string;
begin
  if assigned(value) then
     result := value.ToString
  else
     result := inherited;
end;

{ TVoid_0 }

constructor TVoid_0.Create;
begin
  inherited Create(nil, undefinedId);
end;

function TVoid_0.ToString: String;
begin
  result := undefinedId;
end;

{ ObjectWalker }

function ObjectWalker.asArray: TAnyArray;
begin
  result := this as TAnyArray;
end;

function ObjectWalker.asNumber: Double;
begin
   if this is TValue<integer> then
     result := TValue<integer>(this).value
  else
   if this is TValue<Cardinal> then
     result := TValue<Cardinal>(this).value
   else
   if this is TValue<int64> then
     result := TValue<int64>(this).value
   else
   if this is TValue<uint64> then
     result := TValue<uint64>(this).value
   else
   if this is TValue<word> then
     result := TValue<word>(this).value
   else
   if this is TValue<String> then
   begin
     if not TryStrToFloat(TValue<String>(this).value, result) then
       result := NaN;
   end
   else
     result := NaN;
end;

function ObjectWalker.asObject: TAnyObject;
begin
  result := this as TAnyObject;
end;

function ObjectWalker.asTrunc: int64;
begin
   if isNaN( asNumber ) then
     result := 0
   else
   result := trunc( asNumber );
end;

function ObjectWalker.isArray: Boolean;
begin
  result := this is TAnyArray;
end;

function ObjectWalker.isObject: Boolean;
begin
  result := this is TAnyObject;
end;

type
  EWalkError = class(Exception);

procedure ObjectWalker.walk(const path: array of string);
var
  i : integer;
begin
  for I := Low(Path) to High(Path) do
  begin
     walk(path[i]);
  end;
end;

procedure ObjectWalker.walk(const prop: string);
begin
  this := asObject[prop];
end;

{ TSelfValue }

constructor TSelfValue.Create;
begin
   TypeId := ClassName;
end;

function TSelfValue.GetTypeID: string;
begin
  result := typeId;
end;

function TSelfValue.RTTI: TValue;
begin
    result := self;
end;

initialization
   g_null := TJSONNull.Create;
   g_spread := mkValue('...');
   g_void_0 := TVoid_0.Create;

finalization
   g_null := nil;
   g_spread := nil;
   g_void_0 := nil;


end.
