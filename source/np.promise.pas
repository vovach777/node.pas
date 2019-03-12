unit np.promise;

interface
  uses sysUtils, Generics.Collections, rtti;

  type

{$IFDEF NEXTGEN}
     AnsiString =  UTF8String;
{$ENDIF}

  EPromise = class(exception);

  IValue = interface
  ['{A1831462-EC8B-43E0-9B35-CBD00611841A}']
     function RTTI: TValue;
     function ToString : string;
     function TypeName : string;
  end;
  IValue<T> = interface(IValue)
  ['{3B7468EC-B921-43A7-BBFC-6D6CAE9D5943}']
     function this : T;
  end;

  TPromiseFunction = reference to procedure(ok,ko:TProc<IValue>);
  TPromiseResult   = reference to function(value: IValue) : IValue;
  IPromise = interface(IValue)
  ['{A6F2C65C-709B-43BC-8CE1-447E922CF6E7}']
    function then_( onFulfilled, onRejected: TPromiseResult ) : IPromise; overload;
    function then_( onFulfilled : TPromiseResult) : IPromise; overload;
    procedure then_(onFulfilled, onRejected: TProc<IValue>); overload;
    procedure then_(onFulfilled: TProc<IValue>); overload;
    function done( onComplete: TProc<IValue>) : IPromise; overload;
    function done( onComplete: TProc) : IPromise; overload;
    function catch( onRejected: TPromiseResult ) : IPromise;
  end;

  TValue<T> = class(TInterfacedObject, IValue)
     var
     Value : T;
     _typeName : string;
     constructor Create(const AValue: T; const AtypeName: string = '');
     constructor CreateDefault(const AtypeName: string = '');
     function RTTI: TValue;
     function ToString : String; override;
     function TypeName: string; virtual;
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
    constructor New(const AtypeName: string = 'object');
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
     constructor New(initialValues : array of const ); overload;
     constructor New(); reintroduce; overload;
     function ToString: String; override;
     function GetLength : Int64;
     function Pop : IValue;
     function Push(AValue: IValue) : Int64; overload;
     function Push(AValues : array of const) : int64; overload;
     function Map( func : TFunc<IValue,IValue>) : IValue;
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

  Promise = record
    class function resolve(const value : IValue) : IPromise; static;
    class function reject(const value : IValue) : IPromise;  static;
    class function all(const promises: array of const ) : IPromise; static;
    class function race( const promises: array of const ) : IPromise; static;
    class function new( const fn:TPromiseFunction ) : IPromise; static;
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
  function newPromise(const fn:TPromiseFunction) : IPromise;
  function newResolved(const value:IValue) : IPromise;
  function newRejected(const value:IValue) : IPromise;
  function newRace(const promises: array of const ) : IPromise;
  function newAll(const  promises: array of const ) : IPromise;
  function spread : IValue;

  function p2f(p: TProc<IValue>) : TPromiseResult;

  var
  _unhandledRejectionFn : TProc<IValue>;

implementation
  uses np.core, np.ut;

  type
    IHandler = interface
    ['{24BCEC98-66BC-4AAD-AE96-05EACEBB566C}']
    end;
    Tpromise = class;
    THandler = class(TInterfacedObject, IHandler)
    private
      onFulfilled : TPromiseResult;
      onRejected  : TPromiseResult;
      promise     : IPromise;
      constructor Create( AonFulfilled : TPromiseResult;
                          AonRejected  : TPromiseResult;
                          Apromise     : IPromise);
    end;
    Tpromise = class(TInterfacedObject, IPromise, IValue)
      function RTTI: TValue;
    private
      _state : integer;
      _handled : Boolean;
      _value : IValue;
      _deferreds : TList<IHandler>;
    public
      constructor Create(const fn:TPromiseFunction);
      constructor CreateResolved(const AValue: IValue);
      constructor CreateRejected(const AValue: IValue);
      function then_( onFulfilled, onRejected: TPromiseResult ) : IPromise;overload;
      function then_( onFulfilled: TPromiseResult ) : IPromise;overload;
      procedure then_( onFulfilled, onRejected: TProc<IValue>);overload;
      procedure then_( onFulfilled: TProc<IValue>);overload;
      function done( onComplete: TProc<IValue>) : IPromise; overload;
      function done( onComplete: TProc) : IPromise; overload;
      function catch( onRejected: TPromiseResult ) : IPromise;
      procedure AfterConstruction; override;
      function TypeName : string;
      destructor Destroy; override;
    end;

  procedure doResolve(const fn : TPromiseFunction; promise:TPromise); forward;
  procedure resolve(promise:TPromise; newValue:IValue); forward;
  procedure reject(promise:TPromise; newValue :IValue); forward;
  procedure finale(promise: TPromise); forward;

  procedure Tpromise.afterConstruction;
begin
  inherited;
//  application.log_debug(Format('Create Promise: %u',[NativeUint(self)]));
end;



function Tpromise.catch(onRejected: TPromiseResult): IPromise;
begin
  Result := then_(nil,onRejected);
end;

constructor Tpromise.Create(const fn: TPromiseFunction);
  begin
    assert(assigned(fn));
    inherited Create;
    //application.addTask;
    _addRef;
    _state := 0;
    _value := nil;
    _deferreds := TList<IHandler>.Create;
    doResolve(fn,self);
  end;


  procedure handle(promise:TPromise; Adeferred : THandler);
  begin
//    while promise._value is TPromise do
//       promise := TPromise(promise._value);
    while promise._state = 3 do
       promise := TPromise(promise._value);
  //    if assigned(Promise_onHandle) then
  //      promise_onHandle(promise);
    if promise._state = 0 then
    begin
       promise._deferreds.Add( Adeferred );
       exit;
    end;
    promise._handled := true;
    promise._AddRef;
    Adeferred._AddRef;
    SetImmediate(
       procedure
       var
         cb : TPromiseResult;
         ret : IValue;
       begin
         try
           if promise._state = 1 then
             cb := Adeferred.onFulfilled
           else
             cb := Adeferred.onRejected;
           if not assigned(cb) then
           begin
             if promise._state = 1 then
                 resolve(Adeferred.promise as TPromise, promise._value)
             else
                 reject(Adeferred.promise  as TPromise, promise._value);
             exit;
           end;
           try
             ret := cb(promise._value);
           except
                reject(Adeferred.promise as TPromise, TExceptionValue.Create);
                exit;
           end;
           resolve(Adeferred.promise as TPromise, ret);
         finally
           promise._Release;
           ADeferred._Release;
         end;
       end
    );
  end;

  procedure resolve(promise:TPromise; newValue:IValue);
  begin
    if promise = nil then
      exit;
  // Promise Resolution Procedure: https://github.com/promises-aplus/promises-spec#the-promise-resolution-procedure
    try
      if newValue is TPromise then
      begin
        if Tpromise(newValue) = promise then
          raise EPromise.Create('A promise cannot be resolved with itself.');
        promise._state := 3;
        promise._value := newValue;
        finale(promise);
        exit;
      end;
      promise._state := 1;
      promise._value := newValue;
      finale(promise);
    except
       reject(promise,TExceptionValue.Create);
    end;
  end;

  procedure reject(promise:TPromise; newValue :IValue);
  begin
    if promise = nil then
      exit;
    promise._state := 2;
    promise._value := newValue;
    finale(promise);
  end;

  procedure finale(promise: TPromise);
  var
    i : integer;
  begin
    if (promise._state = 2) and (promise._deferreds.Count = 0) then
    begin
      SetImmediate(
        procedure
        begin
          try
            if (not promise._handled) and assigned(_unhandledRejectionFn) then
               _unhandledRejectionFn(promise._value);
          finally
            promise._Release;
          end;
        end);
      exit;
    end;
    try
      for i := 0 to promise._deferreds.count-1 do
      begin
        handle(promise, promise._deferreds[i] as THandler);
      end;
      promise._deferreds.Clear;
    finally
      promise._Release;
    end;
  end;

  constructor THandler.Create( AonFulfilled : TPromiseResult;
                      AonRejected  : TPromiseResult;
                      Apromise     : IPromise);
  begin
    onFulfilled := AonFulFilled;
    onRejected := AOnRejected;
    promise := APromise;
  end;

  (**
   * Take a potentially misbehaving resolver function and make sure
   * onFulfilled and onRejected are only called once.
   *
   * Makes no guarantees about asynchrony.
   *)
  procedure doResolve(const fn : TPromiseFunction; promise:TPromise);
    var done: Boolean;
  begin
    done := false;
    try
     fn(procedure(value:IValue)
         begin
           if done then
             exit;
           done := true;
           resolve(promise,value);
         end,
         procedure(value:IValue)
         begin
           if done then
             exit;
           done := true;
           reject(promise,value);
         end);
    except
      on E:Exception do
      begin
        if done then
          exit;
        done := true;
        reject(promise, TValue<string>.Create(E.Message,'reject'));
      end;
    end;
  end;

  constructor Tpromise.CreateResolved(const AValue: IValue);
  begin
    inherited Create;
    _state := 1;
    _value := AValue;
  end;

  constructor Tpromise.CreateRejected(const AValue: IValue);
  begin
    inherited Create;
    _state := 2;
    _value := AValue;
  end;

  function TPromise.then_( onFulfilled, onRejected: TPromiseResult ) : IPromise;
  begin
     result := TPromise.Create(procedure(ok,ko:TProc<IValue>) begin end);
     handle(self, THandler.Create( onFulfilled, onRejected, result) );
  end;

  destructor Tpromise.Destroy;
  begin
    freeAndNil(_deferreds);
    //application.log_debug(Format('Destroy Promise: %u',[NativeUint(self)]));

    inherited;
  end;

function Tpromise.done(onComplete: TProc): IPromise;
var
  doneLast : TProc<IValue>;
begin
  result := self;
  if not assigned(onComplete) then
     exit;
  doneLast := procedure(ignoredVal: IValue)
     begin
        SetImmediate( onComplete );
     end;
  then_(doneLast,doneLast);
end;

procedure Tpromise.then_(onFulfilled: TProc<IValue>);
begin
  then_(onFulfilled,nil);
end;

function Tpromise.done(onComplete: TProc<IValue>): IPromise;
var
  doneLast : TProc<IValue>;
begin
  result := self;
  if not assigned(OnComplete) then
    exit;
  doneLast := procedure (val:IValue)
              begin
                SetImmediate(
                procedure
                begin
                  onComplete(val);
                end);
              end;
  then_(doneLast,doneLast);
end;

function Tpromise.RTTI: TValue;
begin
  result := self;
end;


procedure Tpromise.then_(onFulfilled, onRejected: TProc<IValue>);
begin
  handle(self, THandler.Create(p2f( onFulfilled ), p2f( onRejected ), nil) );
end;

function Tpromise.then_(onFulfilled: TPromiseResult): IPromise;
begin
  result := then_(onFulfilled,nil);
end;

function Tpromise.TypeName: string;
begin
  result := ClassName;
end;

{ TValue<T> }

constructor TValue<T>.Create(const AValue: T; const ATypeName : string);
  begin
     inherited Create;
     Value := AValue;
     CreateDefault(ATypeName);
  end;

constructor TValue<T>.CreateDefault(const AtypeName: string);
begin
     if ATypeName <> '' then
       _typeName := ATypeName
     else
        _typeName := ClassName;
end;

function TValue<T>.RTTI: TValue;
begin
  result := TValue.From<T>(Value);
end;

function TValue<T>.ToString: String;
begin
 try
   result := RTTI.ToString;
 except
   result := inherited ToString;
 end;
end;

function TValue<T>.TypeName: string;
begin
   result := _typeName;
end;


{ TOBjectValue }

  destructor TOBjectValue<T>.Destroy;
  begin
    if assigned(value) then
      FreeAndNil(Value);
    //MainLoop.log_debug('free Object Value');
    inherited;
  end;

function newPromise(const fn:TPromiseFunction) : IPromise;
  begin
    result := Tpromise.Create(fn);
  end;

  function newResolved(const value:IValue) : IPromise;
  begin
    result := TPromise.CreateResolved(value);
  end;

  function newRejected(const value:IValue) : IPromise;
  begin
    result := TPromise.CreateRejected(value);
  end;

  function mkValue(i : int64): IValue; overload;
  begin
    Result := TValue<int64>.Create(i,'int64');
  end;

  function mkValue(const s : string): IValue; overload;
  begin
    Result := TValue<string>.Create(s,'string');
  end;

{ TRecordValue<T> }



function TRecordValue<T>.Ref: PRef;
begin
  result := @Value;
end;

function p2f(p: TProc<IValue>) : TPromiseResult;
begin
  if assigned(p) then
    result := function (value:IValue) : IValue
              begin
                p(value);
                result := nil;
              end
  else
    result := nil;
end;

  function newRace(const promises: array of const ) : IPromise;
  var
    all : IValue;
  begin
    all := TAnyArray.New( promises );
    result := newPromise(
               procedure(resolve,reject: TProc<IValue>)
               var
                 cast : TAnyArray;
               begin
                  cast := all as TAnyArray;
                  cast.forEach(
                     procedure (value: IValue)
                     begin
                        if value is TPromise then
                        begin
                          TPromise(value).then_(resolve,reject);
                        end
                        else
                          resolve( value );
                     end);
               end);
  end;

  function newAll(const  promises: array of const ) : IPromise;
  var
    all : IValue;
  begin
    all := TAnyArray.New( promises );
    result := newPromise(
      procedure (Resolve,Reject:TProc<IValue>)
      var
        lCount : integer;
        all_cast: TAnyArray;
      begin
        try
          lCount := 0;
          all_cast := all as TAnyArray;
          all_cast.forEach(
            procedure (value: IValue; Index: int64)
            begin
               if value is Tpromise then
               begin
                 inc(lCount);
                 TPromise(value).then_(
                     procedure(value: IValue)
                     begin
                        all_cast[index] := value;
                        dec(lCount);
                        if lCount = 0 then
                          resolve( all );
                     end,
                     procedure(value:IValue)
                     begin
                       reject(value);
                     end);
               end;
            end);
          if lCount = 0 then
            resolve( all );
        except
            reject(TExceptionValue.Create);
        end;
      end);
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
    result  := TAnyArray.New(values);
  end;

  function mkValue(a: TVarRec): IValue; overload;
  begin
    case a.VType of
            vtInteger:      result := TValue<integer>.Create(a.VInteger);
            vtBoolean:      result := TValue<Boolean>.Create(a.VBoolean);
            vtChar:         result := TValue<Char>.Create(char(a.VChar));
            vtExtended:     result := TValue<Extended>.Create(a.VExtended^);
{$IFNDEF NEXTGEN}
            vtString:       result := mkValue(a.VString^);
            vtWideString:   result := TValue<string>.Create(WideString(a.VWideString));
{$ENDIF}
            vtPointer:      result := TValue<Pointer>.Create(a.VPointer);
            vtPChar:        result := TValue<Char>.Create(char(a.VPChar^));
            vtObject:       begin
                               if a.VObject = nil then
                                 result := nil
                               else
                               if TObject(a.VObject) is Tpromise then
                                 result := TPromise(a.VObject)
                               else
                                 result := TValue<TObject>.Create(a.VObject);
                            end;
            vtClass:        result := TValue<TClass>.Create(a.VClass);
            vtWideChar:     result := TValue<Char>.Create(a.VWideChar);
            vtPWideChar:    result := TValue<Char>.Create(a.VPWideChar^);
            vtAnsiString:   result := mkValue( AnsiString(a.VAnsiString));
            vtCurrency:     result := TValue<Currency>.Create(a.VCurrency^);
            vtVariant:      result := TValue<Variant>.Create(a.VVariant^);
            vtInterface:    if a.VInterface = nil then
                                result := nil
                            else
                            if IInterface(a.VInterface).QueryInterface(IValue,result) <> S_OK then
                              result := TValue<IInterface>.Create(IInterface( a.VInterface ));
            vtInt64:        result := mkValue(a.VInt64^);
            vtUnicodeString: result := mkValue(string(a.VUnicodeString));
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

constructor TAnyObject.New(const AtypeName: string);
begin
   inherited Create( TDictionary<String,IValue>.Create, AtypeName );
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
    exit('');
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

function TAnyArray.Map(func: TFunc<IValue, IValue>): IValue;
var
  i : integer;
  resultCast: TAnyArray;
begin
  resultCast := TAnyArray.New();
  result := resultCast;
  if not assigned(func) then
     exit;
  for i := 0 to FLength-1 do
  begin
    resultCast.SetValueAt(i,  func(GetValueAt(i)));
  end;
end;

constructor TAnyArray.New(initialValues: array of const);
var
  i : integer;
  spredFlag : Boolean;
  tmp : IValue;
  tmpAsArray: TAnyArray;
begin
   inherited New('array');
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

constructor TAnyArray.New;
begin
  inherited New('array');
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
  insertArray := TAnyArray.New( insert );
  removeArray := TAnyArray.New(  );
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

var
  FormatUs : TFormatSettings;

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
            &object := TAnyObject.New('{}');
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
           &array := TAnyArray.New('[]');
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
            if TryStrToFloat(V,Float, FormatUs) then
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
  inherited Create(AValue,'Number');
end;

function TJSONNumber.ToString: String;
begin
  if Frac(Value) = 0 then
    result := IntToStr( Trunc(Value) )
  else
    result := FloatToStr( Value,FormatUS );

end;

{ TJSONBoolean }

constructor TJSONBoolean.Create(AValue: Boolean);
begin
  inherited Create(AValue,'Boolean');
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
   inherited Create(nil,'null');
end;

function TJSONNull.ToString: String;
begin
  result := 'null';
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
  inherited Create(AValue,'String');
end;

function TJSONString.ToString: String;
begin
  result := value;// Format('"%s"',[value{TBoxValue.EncodeJSONText(Value)}]);
end;

{ TExceptionValue }

constructor TExceptionValue.Create;
begin
  inherited Create( Exception(AcquireExceptionObject), 'exception');
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
end;

function TObjectValue<T>.ToString: string;
begin
  if assigned(value) then
     result := value.ToString
  else
     result := inherited;
end;

{ Promise }

class function Promise.all(const promises: array of const): IPromise;
begin
  result := newAll(promises);
end;

class function Promise.new(const fn: TPromiseFunction): IPromise;
begin
  result := newPromise(fn);
end;

class function Promise.race(const promises: array of const): IPromise;
begin
  result := newRace(promises);
end;

class function Promise.reject(const value: IValue): IPromise;
begin
  result := newRejected(value);
end;

class function Promise.resolve(const value: IValue): IPromise;
begin
  result := newResolved(value);
end;

{ TVoid_0 }

constructor TVoid_0.Create;
begin
  inherited Create(nil, 'undefined');
end;

function TVoid_0.ToString: String;
begin
  result := 'undefined';
end;

initialization
   g_null := TJSONNull.Create;
   g_spread := mkValue('...');
   g_void_0 := TVoid_0.Create;
   FormatUs := TFormatSettings.Create('en-US');
  _unhandledRejectionFn := procedure(Aerror:IValue)
                           begin
//                              if assigned(application) then
//                                application.log_warn(Format(
//                                 'Possible Unhandled Promise Rejection: %s',
//                                 [(AError as TObject).ToString] ));
                           end;

finalization
   g_null := nil;
   g_spread := nil;
   g_void_0 := nil;

end.


