unit np.promise;

interface
  uses sysUtils, Generics.Collections, rtti;

  type

{$IFDEF NEXTGEN}
     AnsiString =  UTF8String;
{$ENDIF}

  IValue = interface
  ['{A1831462-EC8B-43E0-9B35-CBD00611841A}']
     function RTTI: TValue;
     function ToString : string;
     function TypeName : string;
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
   Value : T;
   _typeName : string;
   constructor Create(AValue: T; const AtypeName: string = '');
   function RTTI: TValue;
   function ToString : String; override;
   function TypeName: string; virtual;
  end;

  TValues = class(TValue<TArray<IValue>>);

  TObjectValue<T:class> = class(TValue<T>)
  public
    destructor Destroy; override;
  end;

  TRecordValue<T:record> = class(TValue<Pointer>)
  type
    PRef = ^T;
  var
    FRecordValue: T;
    constructor Create(const AtypeName: string = '');
    function Ref : PRef;
  end;

  function mkValue( i : int64 ): IValue; overload;
  function mkValue(const s : string): IValue; overload;
  function mkValue(a: TVarRec): IValue; overload;
  function mkValues(values: array of const) : IValue;

  function newPromise(const fn:TPromiseFunction) : IPromise;
  function newResolved(const value:IValue) : IPromise;
  function newRejected(const value:IValue) : IPromise;
  function newRace( promises: array of const ) : IPromise;
  function newAll(  promises: array of const ) : IPromise;

  function p2f(p: TProc<IValue>) : TPromiseResult;

  var
  _unhandledRejectionFn : TProc<IValue>;

implementation
  uses np.core;

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
             on E:Exception do
             begin
                reject(Adeferred.promise as TPromise, TValue<string>.Create(E.Message));
                exit;
             end;
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
          raise Exception.Create('A promise cannot be resolved with itself.');
        promise._state := 3;
        promise._value := newValue;
        finale(promise);
        exit;
      end;
      promise._state := 1;
      promise._value := newValue;
      finale(promise);
    except
      on E:Exception do
        reject(promise,TValue<string>.create(E.Message));
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
            //application.removeTask;
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
      //application.removeTask;
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
        reject(promise, TValue<string>.Create(E.Message));
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

  constructor TValue<T>.Create(AValue: T; const ATypeName : string);
  begin
     Value := AValue;
     if ATypeName <> '' then
       _typeName := ATypeName
     else
        _typeName := ClassName;

     inherited Create;
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

constructor TRecordValue<T>.Create(const AtypeName: string);
begin
  inherited Create(@FRecordValue,ATypeName);
end;

function TRecordValue<T>.Ref: PRef;
begin
  result := @FRecordValue;
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

  function newRace( promises: array of const ) : IPromise;
  var
    values : TArray<IValue>;
  begin
    values := TValues( mkValues(promises) ).Value;
    result := newPromise(
               procedure(resolve,reject: TProc<IValue>)
               var
                 i : integer;
               begin
                  for I := 0 to length(values)-1 do
                  begin
                    if Values[i] is Tpromise then
                     begin
                       Tpromise(Values[i]).then_(resolve,reject);
                     end
                     else
                     begin
                       resolve( Values[i] );
                       exit;
                     end;
                  end;
               end);
  end;
  function newAll(  promises: array of const ) : IPromise;
  var
    values : TArray<IValue>;
  begin
    values := TValues( mkValues(promises) ).Value;
    result := newPromise(
    procedure (Resolve,Reject:TProc<IValue>)
    var
      i,lCount : integer;
      procedure res(i : integer; promise:TPromise);
      begin
           promise.then_(
                 procedure(value: IValue)
                 begin
                   Values[i] := value;
                   dec(lCount);
                   if lCount = 0 then
                     resolve( newResolved(TValues.Create(values)) );
                 end,
                 procedure(value: IValue)
                 begin
                   reject(value);
                 end);
      end;
    begin
      try
       lCount := 0;
       for i := 0 to length(Values)-1 do
       begin
         if Values[i] is Tpromise then
         begin
           inc(lCount);
           res(i, TPromise(Values[i]));
         end;
       end;
       if lCount = 0 then
          resolve( newResolved(TValues.Create(values)) );
      except
        on E:Exception do
          reject(TValue<string>.Create(E.Message));
      end;
    end);
  end;

  function mkValues(values: array of const) : IValue;
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
        arr[i] := nil;
      end;
    end;
    result := TValues.Create(arr);
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

initialization
  _unhandledRejectionFn := procedure(Aerror:IValue)
                           begin
//                              if assigned(application) then
//                                application.log_warn(Format(
//                                 'Possible Unhandled Promise Rejection: %s',
//                                 [(AError as TObject).ToString] ));
                           end;

end.


