unit np.eventEmitter;
interface
  uses sysUtils, classes, Generics.Collections;
type
    TProc_APointer = TProc<Pointer>;

    IEventHandler = interface
    ['{2205ED21-A159-4085-8EF5-5C3715A4F6F4}']
       procedure remove;
       procedure invoke(args: Pointer);
       function  GetID: integer;
       property ID: integer read GetID;
    end;

     IEventEmitter = Interface
     ['{1C509C46-A6CC-492E-9117-8BF72F10244C}']
       function on_(id: integer; p: TProc_APointer) : IEventHandler; overload;
       function on_(id: integer; p : Tproc) : IEventHandler; overload;
       function once(id: integer; p : TProc) : IEventHandler; overload;
//       function addEventHandler(id: integer; p : Tproc) : IEventHandler; overload;
//       function addEventHandler(id: integer; p : TProc_APointer) : IEventHandler; overload;
       function once(id: integer; p : TProc_APointer) : IEventHandler;overload;
       procedure RemoveAll;
       function isEmpty: Boolean;
       function CountOf(id : integer) : int64;
       procedure emit(eventId: integer; eventArguments : Pointer = nil);
     end;

    TEventEmitter = class(TComponent, IEventEmitter)
    public
    type
       PLinked = ^TLinked;
       TLinked = record
         id : integer;
         //hasArg: Boolean;
         Item: IEventHandler;
         Next: PLinked;
         Prev: PLinked;
       end;
      strict private
       head,tail : PLinked;
       gc : TList< PLinked >;
       emitCount : integer;
       procedure _collect;
    protected
       procedure _remove( eh : IEventHandler ); virtual;
       function _add(id: integer; p: TProc; once: Boolean; hasArg: Boolean) : IEventHandler; virtual;
    public
       type THandlerOperation = (hoAdd,hoRemove);
       var  onHandlerChange : TProc<integer,THandlerOperation>;
       constructor Create();
       function on_(id: integer; p: TProc_APointer) : IEventHandler; overload; inline;
       function on_(id: integer; p : Tproc) : IEventHandler; overload; inline;
       function once(id: integer; p : TProc) : IEventHandler; overload; inline;
//       function addEventHandler(id: integer; p : Tproc) : IEventHandler; overload;
//       function addEventHandler(id: integer; p : TProc_APointer) : IEventHandler; overload;
       function once(id: integer; p : TProc_APointer) : IEventHandler; overload; inline;
       procedure RemoveAll;
       function CountOf(id : integer) : int64;
       function isEmpty: Boolean;
       procedure emit(eventId: integer; eventArguments : Pointer = nil); overload;
       destructor Destroy;override;
    end;

    TIEventEmitter = class(TInterfacedObject, IEventEmitter)
    protected
       FEventEmitter: TEventEmitter;
    private
       function on_(id: integer; p: TProc_APointer) : IEventHandler; overload;
       function on_(id: integer; p : Tproc) : IEventHandler; overload;
       function once(id: integer; p : TProc) : IEventHandler; overload;
       function doAddEvent(id : integer; p: Tproc; once:Boolean; hasArg: Boolean ) : IEventHandler; virtual;
       function once(id: integer; p : TProc_APointer) : IEventHandler;overload;
       procedure RemoveAll;
       function CountOf(id : integer) : int64;
       function isEmpty : Boolean;
       procedure emit(eventId: integer; eventArguments : Pointer = nil);
    public
       constructor Create;
       destructor destroy; override;
    end;

implementation
type
    TEventHandler = class(TInterfacedObject, IEventHandler)
    private
      id : integer;
      hasArg : Boolean;
      procQueue: TEventEmitter;
      proc: TProc;
      once: Boolean;
      link: TEventEmitter.PLinked;
      function  GetID: integer;
      procedure remove;
      procedure invoke(args: Pointer);
      Constructor Create();
      destructor Destroy;override;
    end;


{ TBaseWorker }

function TEventEmitter._add(id: integer; p: TProc; once:Boolean; hasArg: Boolean) : IEventHandler;
var
  tmp : PLinked;
  qi : TEventHandler;
begin
  assert(id <> 0);
  if not assigned(p) then
    exit(nil);
  new(tmp);
  qi := TEventHandler.Create();
  qi.id := id;
  qi.procQueue := self;
  qi.proc := p;
  qi.HasArg := hasArg;
  qi.once := once;
  qi.link := tmp;

  result := qi;
  tmp.id := id;
//  tmp.hasArg := hasArg;

  tmp.Item := qi;
  qi := nil;

  tmp.Prev := nil;
  tmp.Next := nil;
    if head = nil then
    begin
      assert(tail = nil);
      head := tmp;
      tail := tmp;
    end
    else
    begin
     assert(tail <> nil);
     tail.Next := tmp;
     tmp.Prev := tail;
     tail := tmp;
    end;
  //inc(count);
  if assigned(onHandlerChange) then
     onHandlerChange(id,hoAdd);
end;

procedure TEventEmitter._collect;
var
  i : integer;
  tmp : PLinked;
begin
  if emitCount = 0 then
  begin
    for i := 0 to gc.Count-1 do
    begin
      tmp := gc[i];
      dispose(tmp);
    end;
    gc.Count := 0;
  end;
end;

procedure TEventEmitter._remove(eh: IEventHandler);
var
  qi: TEventHandler;
  link : PLinked;
  id : integer;
begin
  assert(assigned(eh));
  qi := TEventHandler(eh);
  assert(assigned(qi));
  assert(assigned(qi.proc));
  assert(assigned(qi.link));
  assert(qi.id = qi.link.id);
  assert(qi.id <> 0);
  id := qi.id;
  qi.procQueue := nil;
  qi.proc := nil;
  link := qi.link;
  qi.link := nil;
  link.Item := nil;
  if link.Prev <> nil then
    link.Prev.Next := link.Next
  else
    head := link.Next;
  if link.Next <> nil then
    link.Next.Prev := link.Prev
  else
    tail := link.Prev;
  link.Item := nil;
  link.id   := 0;
  gc.add(link);
  if assigned(onHandlerChange) then
  begin
    try
      onHandlerChange(id, hoRemove);
    except
    end;
  end;
end;

//function TEventEmitter.addEventHandler(id:integer; p: Tproc): IEventHandler;
//begin
//  result := _add(id,p,false, false);
//end;
//
//function TEventEmitter.addEventHandler(id: integer; p: TProc_APointer): IEventHandler;
//begin
//  result := _add(id,TProc(p), false, true);
//end;

function TEventEmitter.CountOf(id: integer): int64;
var
  tmp : PLinked;
begin
  tmp := head;
  result := 0;
  while assigned(tmp) do
  begin
    if tmp.id = Id then
    begin
       inc(result);
    end;
    tmp := tmp.Next;
  end;
end;

constructor TEventEmitter.Create();
begin
  inherited Create(nil);
  gc := TList< PLinked >.Create;
end;

destructor TEventEmitter.Destroy;
var
  tmp : IEventHandler;
  i : integer;
begin
  onHandlerChange := nil;
  RemoveAll;
  freeAndNil(gc);
  inherited;
end;


procedure TEventEmitter.emit(eventId: integer; eventArguments: Pointer=nil);
var
  tmp : PLinked;
  qi : TEventHandler;
  i : integer;
begin
  inc( emitCount );
  try
  assert(EventId <> 0);
  tmp := head;
  while assigned(tmp) do
  begin
    if tmp.id = eventId then
    begin
      assert(assigned(tmp.Item));
      tmp.Item.invoke(eventArguments);
//      qi := TEventHandler(ref);
//      assert(assigned(qi.proc));
//      assert(qi.id = eventId);
//      if qi.hasArg then
//         TProc_APointer(qi.proc)(eventArguments)
//      else
//        qi.proc();
//      if qi.once then
//         ref.remove;
    end;
    tmp := tmp.Next;
  end;
  finally
    dec(emitCount);
    _collect;
  end;
end;

function TEventEmitter.isEmpty: Boolean;
begin
   result := not assigned(head);
end;

function TEventEmitter.once(id: integer; p: TProc_APointer): IEventHandler;
begin
  result := _add(id, TProc(p), true, true);
end;

function TEventEmitter.on_(id: integer; p: Tproc): IEventHandler;
begin
  result := _add(id, p, false,false);
end;

function TEventEmitter.on_(id: integer; p: TProc_APointer): IEventHandler;
begin
  result := _add(id,Tproc(p),false, true);
end;

function TEventEmitter.once(id: integer; p: TProc): IEventHandler;
begin
  result := _add(id, p,true, false);
end;

procedure TEventEmitter.RemoveAll;
begin
  while assigned(tail) do
      tail.Item.remove;
  _collect;
end;

{ TEventHandler }

constructor TEventHandler.Create();
begin
  inherited;
end;

destructor TEventHandler.Destroy;
begin
//  WriteLn('TEventHandler.Destroy');
  inherited;
end;

function TEventHandler.GetID: integer;
begin
  result := id;
end;

procedure TEventHandler.invoke(args: Pointer);
var
  ref: IEventHandler;
begin
  ref := self; //calling callback can destroy object by ref = 0. keep object alive while invoke
  if (id <> 0) and assigned(Proc) then
  begin
//      assert(assigned(qi.proc));
//      assert(qi.id = eventId);
      if hasArg then
         TProc_APointer(proc)(args)
      else
        proc();
      if once then
         remove;
  end;
end;

procedure TEventHandler.remove;
begin
  if assigned(procQueue) and assigned(proc) and assigned(link) and (id <> 0) then
     procQueue._remove(self);
end;
{ TIEventEmitter }


function TIEventEmitter.CountOf(id: integer): int64;
begin
  result := FEventEmitter.CountOf(id);
end;

constructor TIEventEmitter.Create;
begin
  inherited;
  FEventEmitter := TEventEmitter.Create;
end;

destructor TIEventEmitter.destroy;
begin
  FreeAndNil(FEventEmitter);
  inherited;
end;

function TIEventEmitter.doAddEvent(id: integer; p: Tproc; once,
  hasArg: Boolean) : IEventHandler;
begin
   result := FEventEmitter._add(id,p,once,hasArg);
end;

procedure TIEventEmitter.emit(eventId: integer; eventArguments: Pointer);
begin
  FEventEmitter.emit(eventId,eventArguments);
end;

function TIEventEmitter.isEmpty: Boolean;
begin
  result := FEventEmitter.isEmpty;
end;


function TIEventEmitter.once(id: integer; p: TProc_APointer): IEventHandler;
begin
  Result := doAddEvent(id, TProc(p), true, true);
end;

function TIEventEmitter.once(id: integer; p: TProc): IEventHandler;
begin
  result := doAddEvent(id, p, true, false );
end;

function TIEventEmitter.on_(id: integer; p: TProc_APointer): IEventHandler;
begin
  result := doAddEvent(id, Tproc(p),false, true);
end;

function TIEventEmitter.on_(id: integer; p: Tproc): IEventHandler;
begin
  result := doAddEvent(id,p,false,false);
end;

procedure TIEventEmitter.RemoveAll;
begin
  FEventEmitter.RemoveAll
end;


end.