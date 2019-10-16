    TEventEmitter = class(XObject, IEventEmitter)
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
       function on_(id: integer; p: TProc_APointer) : IEventHandler; overload; inline;
       function on_(id: integer; p : Tproc) : IEventHandler; overload; inline;
       function once(id: integer; p : TProc) : IEventHandler; overload; inline;
       function once(id: integer; p : TProc_APointer) : IEventHandler; overload; inline;
       procedure RemoveAll;
       procedure Remove(var handler: IEventHandler);
       function CountOf(id : integer) : int64;
       function isEmpty: Boolean;
       procedure emit(eventId: integer; eventArguments : Pointer = nil); overload;
       destructor Destroy;override;
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

  if (emitCount = 0) and assigned(gc) then
  begin
    for i := 0 to gc.Count-1 do
    begin
      tmp := gc[i];
      dispose(tmp);
    end;
    gc.Count := 0;
  end;
end;

procedure TEventEmitter.Remove(var handler: IEventHandler);
begin
   if assigned(handler) then
   begin
     handler.remove;
     handler := nil;
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
  if not assigned(gc) then
    gc := TList< PLinked >.Create;
  gc.add(link);
  if assigned(onHandlerChange) then
  begin
    try
      onHandlerChange(id, hoRemove);
    except
    end;
  end;
end;

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

destructor TEventEmitter.Destroy;
var
  tmp : IEventHandler;
  i : integer;
begin
  onHandlerChange := nil;
  RemoveAll;
  if assigned(gc) then
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
  proc0 : TProc;
  proc1 : TProc_APointer;
begin
  ref := self; //calling callback can destroy object by ref = 0. keep object alive while invoke
  if (id <> 0) and assigned(Proc) then
  begin
      if hasArg then
      begin
         proc1 := TProc_APointer(proc);
         proc1(args);
      end
      else
      begin
        proc0 := proc;
        proc0();
      end;
      if once then
         remove;
  end;
end;

procedure TEventHandler.remove;
begin
  if assigned(procQueue) and assigned(proc) and assigned(link) and (link.id <> 0) then
     procQueue._remove(self);
end;

end.
