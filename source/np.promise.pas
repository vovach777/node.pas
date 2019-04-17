unit np.promise;

interface
  uses sysUtils, np.common, np.value, generics.collections;

  type

  EPromise = class(exception);

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


  Promise = record
    class function resolve(const value : IValue) : IPromise; static;
    class function reject(const value : IValue) : IPromise;  static;
    class function all(const promises: array of const ) : IPromise; static;
    class function race( const promises: array of const ) : IPromise; static;
    class function new( const fn:TPromiseFunction ) : IPromise; static;
  end;

  function p2f(p: TProc<IValue>) : TPromiseResult;

  var
  _unhandledRejectionFn : TProc<IValue>;

implementation
  uses np.core;

  type
    IHandler = interface
    ['{24BCEC98-66BC-4AAD-AE96-05EACEBB566C}']
    end;

  Tpromise = class(TSelfValue, IPromise, IValue)
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
    destructor Destroy; override;
  end;

    THandler = class(TInterfacedObject, IHandler)
    private
      onFulfilled : TPromiseResult;
      onRejected  : TPromiseResult;
      promise     : IPromise;
      constructor Create( AonFulfilled : TPromiseResult;
                          AonRejected  : TPromiseResult;
                          Apromise     : IPromise);
    end;
  procedure doResolve(const fn : TPromiseFunction; promise:TPromise); forward;
  procedure resolve(promise:TPromise; newValue:IValue); forward;
  procedure reject(promise:TPromise; newValue :IValue); forward;
  procedure finale(promise: TPromise); forward;



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


procedure Tpromise.then_(onFulfilled, onRejected: TProc<IValue>);
begin
  handle(self, THandler.Create(p2f( onFulfilled ), p2f( onRejected ), nil) );
end;

function Tpromise.then_(onFulfilled: TPromiseResult): IPromise;
begin
  result := then_(onFulfilled,nil);
end;

{ Promise }

class function Promise.all(const promises: array of const): IPromise;
var
  all : IValue;
begin
  all := TAnyArray.Create( promises );
  result := Promise.new(
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

class function Promise.new(const fn: TPromiseFunction): IPromise;
begin
  result := Tpromise.Create(fn);
end;

class function Promise.race(const promises: array of const): IPromise;
var
  all : IValue;
begin
  all := TAnyArray.Create( promises );
  result := Promise.new(
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

class function Promise.reject(const value: IValue): IPromise;
begin
  result := TPromise.CreateRejected(value);
end;

class function Promise.resolve(const value: IValue): IPromise;
begin
  result := TPromise.CreateResolved(value);
end;

function p2f(p: TProc<IValue>) : TPromiseResult;
begin
    result := function (value:IValue) : IValue
              begin
                if assigned(p) then
                begin
                   p(value);
                end;
                result := void_0;
              end
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


