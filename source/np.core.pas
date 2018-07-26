unit np.core;

interface
  uses np.winsock, sysutils,Classes, np.libuv, generics.collections, np.buffer,
      np.eventEmitter;
  type

//    IEventEmitter = np.eventEmitter.IEventEmitter;
//    TEventEmmiter = np.eventEmitter.TEventEmitter;
//    TIEventEmitter = np.eventEmitter.TIEventEmitter;
    PBufferRef = np.buffer.PBufferRef;
    IQueueItem = interface
    ['{49B198FA-6AA5-43C4-9F04-574E0411EA76}']
      procedure Invoke;
      procedure Cancel;
    end;

    TSetImmediate = function (p: Tproc): IQueueItem of object;

    TQueueItem = class(TInterfacedObject, IQueueItem)
    private
      proc: TProc;
      constructor Create(p: TProc);
      procedure Cancel;
      procedure Invoke;
      destructor Destroy; override;
    end;

    IRWLock = Interface
    ['{AA6012BF-B585-47B7-B090-40264F725D19}']
       procedure beginRead;
       procedure endRead;
       procedure beginWrite;
       procedure endWrite;
    end;

    TProcQueue = class
    strict private
    type
       PLinked = ^TLinked;
       TLinked = record
         Item: IQueueItem;
         Next: PLinked;
       end;
      var
       lock: IRWLock;
       head,tail : PLinked;
    public
       function add(p: TProc) : IQueueItem;
       constructor Create();
       function isEmpty: Boolean;
       function emit : Boolean;
       destructor Destroy;override;
    end;

    INPHandle = interface
    ['{E158881A-915E-436D-966A-F7CF969E09E2}']
       procedure ref;
       procedure unref;
       function  hasRef : Boolean;
       procedure setOnClose(OnClose: TProc);
       procedure Clear;
       function is_closing : boolean;
       function _uv_handle : puv_handle_t;
     end;

  INPCheck = Interface(INPHandle)
  ['{AB0D7CEF-4CDD-4E2A-9194-B36A682F1814}']
  end;
  INPPrepare = Interface(INPHandle)
  ['{2D29D734-8265-4419-A6CC-AF979C249C0E}']
  end;
  INPIdle = Interface(INPHandle)
  ['{360B04B1-FDAF-415C-BD85-54BDEBE2A5B5}']
  end;
  INPAsync = interface(INPHandle)
  ['{55C45C90-701B-4709-810F-FF746AC2AB8C}']
     procedure send;
  end;


  INPTimer = Interface(INPHandle)
  ['{A76DFCB7-01F9-460B-97D5-6D9A05A23C03}']
     procedure SetRepeat(Arepeat: uint64);
     function  GetRepeat : uint64;
     procedure Again;
  end;

  PNPError = ^TNPError;
  TNPError = record
     code : integer;
     msg  : string;
  end;

     INPStream = interface(INPHandle)
       ['{DAF6338E-B124-403E-B4C9-BF5B3556697C}']
      procedure shutdown(Acallback : TProc=nil);
//      procedure write(data: Pbyte; dataLen : cardinal; Acallback: TProc=nil); overload;
//      procedure write(data: UTF8String; Acallback: TProc=nil); overload;
      //procedure setOnClose(OnClose: TProc);
//      procedure setOnData(onData: TProc<PByte,Cardinal>);
//      procedure setOnEnd(onEnd: TProc);
      function is_readable : Boolean;
      function is_writable: Boolean;
      procedure setOnData(onData: TProc<PBufferRef>);
      procedure setOnEnd(onEnd: TProc);
      procedure setOnClose(onCloce: Tproc);
      procedure setOnError(OnError: TProc<PNPError>);
      procedure write(const data: BufferRef; Acallback: TProc=nil); overload;
      procedure write(const data: UTF8String; Acallback: TProc=nil); overload;
     end;

    INPTCPStream = Interface(INPStream)
    ['{AF9699FF-CC5A-4004-A19A-DF6420141D55}']
       procedure bind(const Aaddr: UTF8String; Aport: word);
       procedure bind6(const Aaddr: UTF8String; Aport: word; tcp6Only: Boolean=false);
       function  getpeername : string;
       procedure  getpeername_port(out name: string; out port: word);
       function getsockname : string;
       procedure getsockname_port(out name: string; out port: word);
       procedure set_nodelay(enable:Boolean);
       procedure set_simultaneous_accepts(enable:Boolean);
       procedure set_keepalive(enable:Boolean; delay:cardinal);
    end;

    INPTCPConnect = interface (INPTCPStream)
      ['{8F00A812-AFA9-4313-969E-88AD2935C5B0}']
//      procedure start_read;
//      procedure stop_read;
      procedure connect(const address: TSockAddr_in_any; ACallBack: TProc=nil); overload;
      procedure connect(const address: Utf8String; port: word); overload;
      procedure setOnConnect(onConnect : TProc);
    end;

    INPTCPServer = interface;
    TOnTCPClient = reference to procedure(server: INPTCPServer); //duv.tcp.client.TNPTCPStream.CreateClient( Server : INPTCPServer );

    INPTCPServer = interface(INPHandle)
     ['{E20EB1A4-7A85-4C09-9FA5-FF821C68CEEE}']
       procedure setOnClient(OnClose: TOnTCPClient);
       procedure setOnError(OnError: TProc<PNPError>);
       procedure setOnClose(OnClose: TProc);
       procedure bind(const Aaddr: UTF8String; Aport: word);
       procedure bind6(const Aaddr: UTF8String; Aport: word; tcp6Only: Boolean=false);
       procedure set_nodelay(enable:Boolean);
       procedure set_simultaneous_accepts(enable:Boolean);
       procedure set_keepalive(enable:Boolean; delay:cardinal);
       procedure listen(backlog: integer=UV_DEFAULT_BACKLOG);
    end;

      INPPipe = interface(INPStream)
        procedure connect(const AName: UTF8String);
        procedure setOnConnect(onConnect : TProc);
      end;

      INPSpawn = interface(INPHandle)
      ['{D756C9DD-76D0-4597-81B4-8E813360B8B5}']
          function GetStdio(inx:integer) : puv_stdio_container_t;
          function getArgs : TStringList;
          procedure spawn;
          function getFlags : uv_process_flags_set;
          procedure setFlags( flags : uv_process_flags_set);
          procedure setOnExit(ACallBack: TProc<int64,integer>);
          procedure kill(signnum: integer);
          procedure setCWD(const cwd : String);
          function getCWD : String;
          function getPID : integer;
          property args : TStringList read getArgs;
          property stdio[ inx:integer ] : puv_stdio_container_t read GetStdio;
          property flags : uv_process_flags_set read getFlags write setFlags;
          property PID: integer read getPid;
          property CWD : String read getCWD write setCWD;
      end;

    TNPBaseHandle = class(TInterfacedObject, INPHandle)
     protected
       FHandle : puv_handle_t;
       HandleType: uv_handle_type;
       FActiveRef : INPHandle;
       FOnClose : TProc;
       procedure ref;
       procedure unref;
       function  hasRef : Boolean;
       procedure Clear;
       function is_closing : Boolean;
       procedure onClose; virtual;
       function _uv_handle : puv_handle_t;
       procedure setOnClose(OnClose: TProc);
     public
       constructor Create(AHandleType: uv_handle_type);
       destructor Destroy; override;
   end;


     TNPStream = class(TNPBaseHandle, INPStream, INPHandle)
     private
     type
      PWriteData = ^TWriteData;
      TWriteData = record
         req : uv_write_t;
         buf: uv_buf_t;
         callback: TProc;
         streamRef: INPHandle;
      end;
     private
       __buf: TBytes;
       FStream: puv_stream_t;
       FRead: Boolean;
       FListen : Boolean;
       FError : Boolean;
       FShutdown: Boolean;
       FShutdownReq: uv_shutdown_t;
       FShutdownRef : INPStream;
       FOnError : TProc<PNPError>;
       FOnEnd   : TProc;
       FOnData  : TProc<PBufferRef>;
       FOnShutdown: TProc;
       FOnConnect : TProc;
       FConnect : Boolean;
       FConnected: Boolean;
       FConnectReq: uv_connect_t;
       FConnectRef: INPStream;
       procedure _writecb(wd: PWriteData; status: integer);
     private
       procedure _onRead(data: Pbyte; nread: size_t);
       procedure _onEnd;
       procedure _onError(status: integer);
       procedure writeInternal(data: PByte; len: Cardinal; ACallBack: TProc);
     protected
       procedure __onError(status: integer);
       procedure setOnError(OnError: TProc<PNPError>);
       procedure setOnData(onData: TProc<PBufferRef>);
       procedure setOnEnd(onEnd: TProc);
       procedure setOnConnect(onConnect : TProc);
       procedure onClose; override;
       procedure tcp_connect(const address: TSockaddr_in_any);
       procedure pipe_connect(const name: UTF8String);
       procedure pipe_bind(const name: UTF8String);
       procedure _onConnect; virtual;
       procedure _onConnection; virtual;
       procedure write(const data:BufferRef; ACallBack: TProc = nil); overload;
       procedure write(const data : UTF8String; ACallBack: TProc = nil); overload;
       procedure shutdown(ACallBack: TProc);
       procedure _listen(backlog:integer);
//       procedure _accept(client : puv_stream_t);
       procedure read_start;
       procedure read_stop;
       function is_readable : Boolean;
       function is_writable: Boolean;
       property is_shutdown: Boolean read FShutdown;
      public
       constructor Create(AHandleType: uv_handle_type);
     end;


    TNPTCPHandle = class(TNPStream)
       procedure bind(const Aaddr: UTF8String; Aport: word);
       procedure bind6(const Aaddr: UTF8String; Aport: word; tcp6Only: Boolean=false);
       function  getpeername : string;
       procedure  getpeername_port(out name: string; out port: word);
       function getsockname : string;
       procedure getsockname_port(out name: string; out port: word);
       procedure set_nodelay(enable:Boolean);
       procedure set_simultaneous_accepts(enable:Boolean);
       procedure set_keepalive(enable:Boolean; delay:cardinal);
       constructor Create();
    end;

    TNPTCPServer = class(TNPTCPHandle, INPTCPServer)
    private
       FOnClient : TOnTCPClient;
    protected
       procedure setOnClient(AOnClient: TOnTCPClient);
       procedure listen(backlog: integer);
       procedure _onConnection; override;
    end;

    TNPTCPStream = class(TNPTCPHandle, INPTCPStream, INPTCPConnect)
    protected
      procedure connect(const address: TSockAddr_in_any; ACallBack: TProc=nil);overload;
      procedure connect(const address: UTF8String; port: word); overload;
    public
      constructor CreateClient( Server : INPTCPServer );
      constructor CreateConnect();
      destructor Destroy; override;
    end;

      TNPPipe = class(TNPStream, INPPipe)
      private
        procedure connect(const AName: UTF8String);
      public
        constructor Create();
      end;


  TLoop = class(TEventEmitter)
  public
    Fuvloop: puv_loop_t;
    //isDefault : Boolean;
    embededTasks: INPAsync;
    checkQueue: TProcQueue;
    nextTickQueue: TProcQueue;
    taskCount: integer;
    isTerminated: Boolean;
    loopThread: uv_thread_t;
    procedure addTask;
    procedure removeTask;
    function now: uint64;
    procedure terminate;
    procedure newThread(p: TProc; onJoin: TProc = nil);
    function setImmediate(p: Tproc): IQueueItem;
    function NextTick(p: Tproc): IQueueItem;
    constructor Create();
//    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
//    function _AddRef: Integer; stdcall;
//    function _Release: Integer; stdcall;
    function uvloop: puv_loop_t;
    destructor Destroy; override;
    procedure run_nowait();
    private
    check: INPCheck;
    procedure run();
  end;


  INPTTY = interface(INPHandle)
    ['{FA890477-2F37-4A17-84B0-7A7C47994000}']
    procedure Print(const s: UTF8String);
    procedure PrintLn(const s: UTF8String);
    procedure MoveTo(x, y: integer);
    procedure MoveTo1x1;
    procedure MoveToX(x: integer);
    procedure MoveToY(y: integer);
    procedure beginPrint;
    procedure endPrint;
    procedure get_winsize(out width: integer; out height:integer);
  end;

      TNPSpawn = class(TNPBaseHandle, INPSpawn)
      private
        FProcess: puv_process_t;
        FSpawn : Boolean;
        Fstdio :  array [0..2] of uv_stdio_container_t;
        Fargs : TStringList;
        Fcurrent_args : TArray<UTF8String>;
        Foptions : uv_process_options_t;
        FOnExit: TProc<int64, integer>;
        FCWD : UTF8String;
      private
          function GetStdio(inx:integer) : puv_stdio_container_t;
          function getArgs : TStringList;
          function getFlags : uv_process_flags_set;
          procedure setFlags( flags : uv_process_flags_set);
          procedure setOnExit(ACallBack: TProc<int64,integer>);
          function getCWD : String;
          procedure setCWD(const cwd : String);
          function getPID : integer;
          procedure spawn;
          procedure kill(signnum: integer);
          procedure _onExit(exit_status: Int64;  term_signal: Integer);
      public
        constructor Create();
        destructor Destroy; override;
      end;


  function newRWLock : IRWLock;

  function SetCheck(cb:TProc) : INPCheck;
  function SetPrepare(cb:TProc) : INPPrepare;
  function SetIdle(cb:TProc) : INPIdle;
  function SetAsync(cb:TProc) : INPAsync;

  function SetTimer(cb:TProc; Atimeout,Arepeat:uint64) : INPTimer;
  procedure Cleartimer(var handle: INPTimer);
  function SetInterval(p: Tproc; AInterval: Uint64): INPTimer;
  function SetTimeout(p: Tproc; ATimeout: Uint64): INPTimer;

  function thread_create(p : TProc) : uv_thread_t;
  procedure thread_join(tid: uv_thread_t);



  function NextTick(p: TProc) : IQueueItem;
  function setImmediate(p: Tproc): IQueueItem;

  procedure LoopHere;
  function loop: TLoop;
  function stdOut : INPTTY;
  function stdErr : INPTTY;
  function stdIn  : INPStream;
  function stdInRaw : INPStream;

  procedure dns_resolve(const addr: UTF8String; const onResolved: TProc<integer,UTF8String>);



const
  ev_loop_shutdown = 1;
  ev_loop_beforeTerminate = 2;
//threadvar
//  this_eventHandler: IEventHandler;

implementation

const
  FD_STDIN  = 0;
  FD_STDOUT = 1;
  FD_STDERR = 2;

type
  P_tty_w_req = ^TNPTTY_w_req;

  TNPTTY_w_req = record
    wr: uv_write_t;
    msg: UTF8String;
  end;

  TNPTTY = class( TNPStream, INPTTY )
  private
    Ftty: puv_tty_t;
    pbuf: UTF8String;
    pcount: integer;
    procedure PrintLn(const s: UTF8String);
    procedure Print(const s: UTF8String);
    procedure MoveTo(x, y: integer);
    procedure MoveTo1x1;
    procedure MoveToX(x: integer);
    procedure MoveToY(y: integer);
    procedure beginPrint;
    procedure endPrint;
    procedure flush;
    procedure get_winsize(out width: integer; out height:integer);
  public
    constructor Create(fd:integer=FD_STDOUT);
    destructor Destroy; override;
  end;

  TNPTTY_INPUT = class( TNPStream )
    constructor Create(raw:Boolean=false);
  end;


   threadvar
     tv_loop : TLoop;
     tv_stdout: INPTTY;
     tv_stderr: INPTTY;
     tv_stdin : INPStream;

  function loop : TLoop;
  begin
    if not assigned(tv_loop) then
      TLoop.Create;
    assert(assigned(tv_loop));
    result := tv_loop;
  end;

  procedure LoopHere;
  begin
    if not assigned(tv_loop) then
      tv_loop := TLoop.Create;
    tv_loop.run;
    tv_stdin := nil;
    tv_stdout := nil;
  end;




function TProcQueue.add(p: TProc) : IQueueItem;
var
  tmp : PLinked;
begin
  if not assigned(p) then
    exit(nil);
  new(tmp);
  tmp.Item := TQueueItem.Create(p);
  tmp.Next := nil;
  lock.beginWrite;
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
     tail := tmp;
    end;
  //inc(count);
  lock.endWrite;
  result := tmp.Item;
end;

constructor TProcQueue.Create;
begin
  lock := newRWLock;
end;

destructor TProcQueue.Destroy;
var
  tmp : PLinked;
begin
  Lock.beginWrite;
    while head <> nil do
    begin
      tmp := head;
      head := tmp.Next;
      tmp.Item := nil;
      Dispose(tmp);
    end;
  Lock.endWrite;
  inherited;
end;

function TProcQueue.emit : Boolean;
var
  tmp : PLinked;
begin
  if isEmpty then
    exit(false);
  lock.BeginWrite;
  tmp := head;
  head := tmp.Next;
  if head = nil then
  begin
     assert(tail = tmp);
     tail := nil;
  end;
  //dec(count);
  //assert(count >= 0);
  lock.endWrite;
  try
    tmp.Item.invoke;
  except
//TODO: unhandled exception
//        on E:Exception do
//          application.log_warn('Unhandled exception: '+E.Message);
  end;
  tmp.Item := nil;
  Dispose(tmp);
  exit(not IsEmpty);
end;

function TProcQueue.isEmpty: Boolean;
begin
      lock.beginRead;
        result := not assigned(head);
      lock.endRead;
end;

{ TQueueItem }

procedure TQueueItem.Cancel;
begin
  proc := nil;
end;

constructor TQueueItem.Create(p: TProc);
begin
  proc := p;
end;

destructor TQueueItem.Destroy;
begin
  inherited;
end;

procedure TQueueItem.Invoke;
var
  p : TProc;
begin
  p := Proc;
  proc := nil;
  if assigned(p) then
    p();
  p := nil;
end;

{ TLoop }



procedure TLoop.addTask;
begin
  inc(taskCount);
  if taskCount = 1 then
     embededTasks.ref;
end;

constructor TLoop.Create();
begin
  tv_loop := self;
  loopThread := uv_thread_self;
  inherited Create();
  New(Fuvloop);
  duv_ok( uv_loop_init(Fuvloop) );
  assert( assigned(Fuvloop));
  checkQueue := TProcQueue.Create;
  nextTickQueue := TProcQueue.Create;
  embededTasks := SetAsync(nil);
  embededTasks.unref;
  embededTasks.setOnClose(
     procedure
     begin
       emit(ev_loop_shutdown,self);
       while nextTickQueue.emit do;
       while checkQueue.emit do
         while nextTickQueue.emit do;

     end);
  check := SetCheck(
    procedure
    begin
      checkQueue.emit;
    end);
    check.unref;
end;


destructor TLoop.Destroy;
begin
  FreeAndNil(checkQueue);
  FreeAndNil(nextTickQueue);
  dispose(uvloop);
  Fuvloop := nil;
  tv_loop := nil;
  inherited;
end;


procedure TLoop.newThread(p: TProc; onJoin: TProc);
var
  thd : uv_thread_t;
  async: INPAsync;
begin
   if not assigned(p) then
     exit;
   async := SetAsync(
     procedure
     begin
       if assigned(onJoin) then
       begin
          thread_join( thd );
          onJoin();
          onJoin := nil;
          async.Clear;
          async := nil;
       end;
     end
       );
   thd := thread_create(
           procedure
           begin
              try
                p();
              except
              end;
              p := nil;
              async.send;
           end);
end;

function TLoop.NextTick(p: Tproc): IQueueItem;
begin
  result := nil;
  if assigned(nextTickQueue) and (assigned(p)) then
  begin
    result := nextTickQueue.add(p);
  end;
end;

function TLoop.now: uint64;
begin
  result := uv_now(uvloop);
end;

procedure TLoop.removeTask;
begin
  dec( taskCount );
  if taskCount = 0 then
    embededTasks.unref;
end;

procedure __cbWalk(handle: puv_handle_t; arg: pinteger); cdecl;
var
 ht : uv_handle_type;
begin
  ht := uv_get_handle_type(handle);
  if uv_is_closing(handle) = 0 then
    uv_close(handle, uv_get_close_cb(handle));
end;

procedure TLoop.run_nowait();
begin
  loopThread := uv_thread_self;
  while nextTickQueue.emit do;
  if checkQueue.isEmpty then
    check.unref
  else
   check.ref;
  uv_run(uvloop, UV_RUN_NOWAIT);
end;

procedure TLoop.run();
begin
  try
//      setImmediate(mainProc);
    repeat
      while nextTickQueue.emit do;
      if not checkQueue.isEmpty then
      begin
        check.ref;
        uv_run(uvloop, UV_RUN_NOWAIT);
      end
      else
      begin
        check.unref;
        uv_run(uvloop, UV_RUN_ONCE);
      end;
      if isTerminated then
        break;
    until (uv_loop_alive(uvloop) = 0) and (checkQueue.isEmpty);
    uv_walk(uvloop, @__cbWalk, nil);
    uv_run(uvloop, UV_RUN_DEFAULT);
    duv_ok( uv_loop_close(uvloop) );
    check := nil;
    embededTasks := nil;
  finally
    Free;
  end;
end;

function TLoop.setImmediate(p: Tproc): IQueueItem;
begin
  result := nil;
  if assigned(checkQueue) and (assigned(p)) then
  begin
    result := checkQueue.add(p);
    if uv_thread_self <> loopThread then
       embededTasks.send;
  end;
end;

function SetInterval(p: Tproc; AInterval: Uint64): INPTimer;
begin
  result := SetTimer(p, AInterval, AInterval);
end;

function SetTimeout(p: Tproc; ATimeout: Uint64): INPTimer;
begin
  result := SetTimer(p, ATimeout, 0);
end;

procedure TLoop.terminate;
begin
  if not isTerminated then
  begin
    emit(ev_Loop_beforeTerminate);

    uv_stop(uvloop); //break run_default loop to check isTerminated
    isTerminated := true;
  end;
end;

function TLoop.uvloop: puv_loop_t;
begin
  result := Fuvloop;
end;

//function TLoop.QueryInterface(const IID: TGUID; out Obj): HResult;
//begin
//  if GetInterface(IID, Obj) then
//    Result := 0
//  else
//    Result := E_NOINTERFACE;
//end;
//
//function TLoop._AddRef: Integer;
//begin
//  result := 1;
//end;
//
//function TLoop._Release: Integer;
//begin
//  result := 1;
//end;


  type

  TNPCBHandle = class(TNPBaseHandle)
  private
    FCallBack: TProc;
  protected
    procedure onClose; override;
  public
    constructor Create(AHandleType: uv_handle_type; ACallBack: TProc);
  end;

  TNPCheck = Class(TNPCBHandle, INPCheck)
       constructor Create(ACallBack: TProc);
  public
    destructor Destroy; override;
     end;

     TNPPrepare = class(TNPCBHandle, INPPrepare)
       constructor Create(ACallBack: TProc);
  public
    destructor Destroy; override;
     end;

  TNPIdle = class(TNPCBHandle, INPIdle)
     constructor Create(ACallBack: TProc);
  public
    destructor Destroy; override;
     end;

   TNPAsync = class(TNPCBHandle, INPASync)
       constructor Create(ACallBack: TProc);
       procedure send;
       destructor Destroy; override;
   end;


  procedure __cb(handle: puv_handle_t); cdecl;
  var
    ud : TNPCBHandle;
  begin
    ud := uv_get_user_data(handle);
    assert(assigned(ud));
    if assigned( ud.FCallBack ) then
      ud.FCallBack();
  end;


  function SetCheck(cb:TProc) : INPCheck;
  begin
    result := TNPCheck.Create(cb);
  end;

  function SetPrepare(cb:TProc) : INPPrepare;
  begin
    result := TNPPrepare.Create(cb);
  end;

  function SetIdle(cb:TProc) : INPIdle;
  begin
    result := TNPIdle.Create(cb);
  end;

  function SetAsync(cb:TProc) : INPAsync;
  begin
    result := TNPAsync.Create(cb);
  end;


{ TNPCheck }


constructor TNPCheck.Create(ACallBack: TProc);
begin
    inherited Create(UV_CHECK, ACallBack);
    duv_ok(uv_check_init(loop.uvloop , puv_check_t( Fhandle) ));
    duv_ok(uv_check_start(puv_check_t(Fhandle), @__cb));
    FActiveRef := self;
end;

destructor TNPCheck.Destroy;
begin
  //OutputdebugString('TNPCheck.Destroy');
  inherited;
end;

{ TNPPrepare }


constructor TNPPrepare.Create(ACallBack: TProc);
begin
    inherited Create(UV_PREPARE, ACallBack);
    uv_prepare_init(loop.uvloop, puv_prepare_t(Fhandle));
    duv_ok(uv_prepare_start(puv_prepare_t(Fhandle), @__cb));
    FActiveRef := self;
end;

destructor TNPPrepare.Destroy;
begin
  //OutputdebugString('TNPPrepare.Destroy');
  inherited;
end;

{ TNPIdle }

constructor TNPIdle.Create(ACallBack: TProc);
begin
    inherited Create(UV_IDLE,ACallBack);
    uv_idle_init(loop.uvloop, puv_idle_t(FHandle));
    duv_ok( uv_idle_start(puv_idle_t(FHandle), @__cb) );
    FActiveRef := self;
end;

destructor TNPIdle.Destroy;
begin
  //OutputdebugString('TNPIdle.Destroy');
  inherited;
end;

constructor TNPAsync.Create(ACallBack: TProc);
begin
  inherited Create(UV_ASYNC,ACallBack);
  uv_async_init(loop.uvloop, puv_async_t(FHandle), @__cb);
  FActiveRef := self;
end;

constructor TNPCBHandle.Create(AHandleType: uv_handle_type; ACallBack: TProc);
begin
  inherited Create(AHandleType);
  FCallBack := ACallBack;
end;

procedure TNPCBHandle.onClose;
begin
  inherited;
  FCallBack := nil;
end;

destructor TNPAsync.Destroy;
begin
//  WriteLn('TNPAsync.Destroy');
  inherited;
end;

procedure TNPAsync.send;
begin
  duv_ok( uv_async_send(puv_async_t(FHandle)) );
end;

   type
    TRWLock = class(TInterfacedObject,IRWLock)
    strict private
       rwlock: uv_rwlock_t;
       procedure beginRead;
       procedure endRead;
       procedure beginWrite;
       procedure endWrite;
    public
       constructor Create;
       destructor Destroy; override;
    end;

    function newRWLock : IRWLock;
    begin
      result := TRWLock.Create;
    end;


{ TRWLock }


constructor TRWLock.Create;
begin
   uv_rwlock_init(@rwlock);
end;

destructor TRWLock.Destroy;
begin
  inherited;
  uv_rwlock_destroy(@rwlock);
end;

procedure TRWLock.beginRead;
begin
  uv_rwlock_rdlock(@rwlock);
end;

procedure TRWLock.endRead;
begin
  uv_rwlock_rdunlock(@rwlock);
end;


procedure TRWLock.beginWrite;
begin
  uv_rwlock_wrlock(@rwlock);
end;

procedure TRWLock.endWrite;
begin
  uv_rwlock_wrunlock(@rwlock);
end;

{ TNPTCPHandle }

constructor TNPTCPHandle.Create();
begin
  inherited Create(UV_TCP);
  duv_ok( uv_tcp_init(loop.uvloop, puv_tcp_t( FHandle )) );
  FActiveRef := self;
end;

procedure TNPTCPHandle.bind(const Aaddr: UTF8String; Aport: word);
var
  addr: Tsockaddr_in_any;
begin
  try
    duv_ok( uv_ip4_addr(PUTF8Char(Aaddr),APort,addr.ip4) );
  except
    duv_ok( uv_ip6_addr(PUTF8Char(Aaddr),APort,addr.ip6) );
  end;
  duv_ok( uv_tcp_bind(puv_tcp_t(FHandle),addr,0) );
end;

procedure TNPTCPHandle.bind6(const Aaddr: UTF8String; Aport: word;
  tcp6Only: Boolean);
var
  addr: Tsockaddr_in_any;
begin
  duv_ok( uv_ip6_addr(@Aaddr[1],APort,addr.ip6) );
  duv_ok( uv_tcp_bind(puv_tcp_t(FHandle),addr,ord(tcp6Only)) );
end;

function TNPTCPHandle.getpeername: string;
var
  port : word;
begin
  getpeername_port(result,port);
end;

procedure TNPTCPHandle.getpeername_port(out name: string; out port: word);
var
  sa: Tsockaddr_in_any;
  len : integer;
  nameBuf : array [0..128] of UTF8Char;
begin
  len := sizeof(sa);
  duv_ok( uv_tcp_getpeername(puv_tcp_t(FHandle),sa,len) );
  case sa.ip4.sin_family of
     UV_AF_INET:
        begin
          duv_ok( uv_ip4_name(PSockAddr_In(@sa), @nameBuf, sizeof(nameBuf) ) );
          name := UTF8String(PUTF8Char( @nameBuf ));
        end;
     UV_AF_INET6:
        begin
          duv_ok( uv_ip6_name(PSockAddr_In6(@sa), @nameBuf, sizeof(nameBuf) ) );
          name := UTF8String(PUTF8Char( @nameBuf ));
        end;
      else
        assert(false);
  end;
  port := uv_get_ip_port(  Psockaddr_in(@sa) );
end;

function TNPTCPHandle.getsockname: string;
var
  port : word;
begin
  getsockname_port(result, port);
end;

procedure TNPTCPHandle.getsockname_port(out name: string; out port: word);
var
  sa: Tsockaddr_in_any;
  len : integer;
  nameBuf : array [0..128] of UTF8Char;
begin
  len := sizeof(sa);
  duv_ok( uv_tcp_getsockname(puv_tcp_t(FHandle),sa,len) );
  case sa.ip4.sin_family of
     UV_AF_INET:
        begin
          duv_ok( uv_ip4_name(PSockAddr_In(@sa), @nameBuf, sizeof(nameBuf) ) );
          name := UTF8String(PUTF8Char( @nameBuf ));
        end;
     UV_AF_INET6:
        begin
          duv_ok( uv_ip6_name(PSockAddr_In6(@sa), @nameBuf, sizeof(nameBuf) ) );
          name := UTF8String(PUTF8Char( @nameBuf ));
        end;
      else
        assert(false);
  end;
  port := uv_get_ip_port(  Psockaddr_in(@sa) );
end;

procedure TNPTCPHandle.set_keepalive(enable: Boolean; delay: cardinal);
begin
  duv_ok( uv_tcp_keepalive(puv_tcp_t( FHandle ),ord(enable),delay) );
end;

procedure TNPTCPHandle.set_nodelay(enable: Boolean);
begin
  duv_ok( uv_tcp_nodelay(puv_tcp_t( FHandle ),ord(enable)) );
end;

procedure TNPTCPHandle.set_simultaneous_accepts(enable: Boolean);
begin
  duv_ok( uv_tcp_simultaneous_accepts(puv_tcp_t( FHandle ),ord(enable)) );
end;

{ TNPTCPServer }

procedure TNPTCPServer.listen(backlog: integer);
begin
  _listen(backlog);
end;

procedure TNPTCPServer.setOnClient(AOnClient: TOnTCPClient);
begin
  FOnClient := AOnClient;
end;

procedure TNPTCPServer._onConnection;
begin
  FOnClient(self);
end;

procedure __connect_cb(req: puv_connect_t; status: integer);cdecl;
var
  ud : TNPStream;
begin
  ud := uv_get_user_data(req);
  assert(assigned(ud));
  if status = 0 then
  begin
    ud.FConnected := true;
    if assigned(ud.FOnConnect) then
    try
       ud.FOnConnect();
    except
    end;
    ud.FOnConnect := nil;
  end
  else
    ud.__onError(status);
  ud.FConnectRef := nil;
end;


procedure __shutdown_cb(req: puv_shutdown_t; status: integer); cdecl;
var
  ud : TNPStream;
begin
  {TODO: move to class}
  ud := uv_get_user_data(req);
  try
//    if status = 0 then
//    begin
      if assigned( ud.FOnShutdown ) then
         ud.FOnShutdown();
      ud.FOnShutdown := nil;
//      if not ud.FRead then
      ud.Clear;
//    end
//    else
//      ud.__onError(status);

  except
  end;
  ud.FShutdownRef := nil;
end;

procedure __connection_cb(server : puv_stream_t; status: integer); cdecl;
var
  ud : TNPStream;
begin
  {TODO: move to class}
  ud := uv_get_user_data(server);
  try
    if status = 0 then
      ud._onConnection
    else
    begin
      ud.__onError(status);
    end;
  except
  end;
end;

procedure __alloc_cb(handle:puv_handle_t;suggested_size:size_t; var buf:uv_buf_t );cdecl;
var
  ud : TNPStream;
begin
  ud := uv_get_user_data(handle);
  assert(assigned(ud));
  if suggested_size > length(ud.__buf) then
  begin
    Setlength(ud.__buf, (suggested_size + $4000) and (not $3FFF));
  end;
  buf.len := suggested_size;
  buf.base := @ud.__buf[0];
end;

procedure __read_cb(stream: puv_stream_t; nread:ssize_t; const buf: uv_buf_t);cdecl;
var
  ud : TNPStream;
begin
  if nread = 0 then
    exit;

  {TODO: move to class}
  ud := uv_get_user_data(stream);
  assert(assigned(ud));
  if (nread < 0) then
  begin
    ud.read_stop;
    if (nread = UV_EOF) then
    begin
      try
        ud._onEnd;
      except
      end;
      ud.Clear;
    end
    else
      ud.__onError(nread);
    exit;
  end;
  try
    ud._OnRead(@ud.__buf[0], nread)
  except
  end;
end;

procedure __write_cb(req : puv_write_t; status : integer);cdecl;
var
  ud : TNPStream;
  wd : TNPStream.PWriteData;
begin
  ud := uv_get_user_data(req);
  assert(assigned(ud));
  wd := TNPStream.PWriteData(req);
  ud._writecb(wd,status);
end;

{ TNPStream }

//procedure TNPStream._accept(client : puv_stream_t);
//begin
//   duv_ok( uv_accept(Fstream,client) );
//end;

constructor TNPStream.Create(AHandleType: uv_handle_type);
begin
  assert( AHandleType in [UV_NAMED_PIPE, UV_TCP, UV_TTY] );
  inherited Create(AHandleType);
  FStream := puv_stream_t( FHandle );
end;

function TNPStream.is_readable: Boolean;
begin
  result := uv_is_writable(Fstream) <> 0;
end;

procedure TNPStream._listen(backlog: integer);
begin
  if not FListen then
  begin
    FListen := true;
    duv_ok( uv_listen(Fstream,backlog,@__connection_cb) );
  end;
end;

procedure TNPStream._onConnect;
begin

end;

procedure TNPStream._onConnection;
begin

end;

procedure TNPStream._onEnd;
begin
  if assigned(FOnEnd) then
      FOnEnd();
  FOnEnd := nil;
end;

procedure TNPStream._onError(status: integer);
var
  err: TNPError;
begin
  FOnData := nil;
  FOnEnd := nil;
  if assigned(FOnError) then
  begin
    err.code := status;
    err.msg := Format('%s:%s!', [uv_err_name(status), uv_strerror(status)]);
    FOnError(@err);
  end;
  FOnError := nil;
end;

procedure TNPStream._onRead(data: Pbyte; nread: size_t);
var
  arg: BufferRef;
begin
  if assigned(FOnData) then
  begin
     arg := BufferRef.CreateWeakRef(data,nread);
     FOnData(@arg);
  end;
end;

procedure TNPStream._writecb(wd: PWriteData; status : integer);
begin
  if status <> 0 then
    __onError(status)
  else
    if assigned(wd.callback) then
    try
       wd.callback();
    except
    end;
  wd.callback := nil;
  wd.streamRef := nil;
  assert( wd.buf.base <> nil );
  assert( wd.buf.len > 0 );
  FreeMem( wd.buf.base );
  dispose(wd);
end;

procedure TNPStream.__onError(status: integer);
begin
  if not FError  then
  begin
    FError := true;
    try
      _onError(status);
    except
    end;
    Clear;
  end;
end;

procedure TNPStream.read_start;
begin
  if not FRead then
  begin
    duv_ok( uv_read_start(Fstream,@__alloc_cb,@__read_cb) );
    FRead := true;
  end;
end;

procedure TNPStream.read_stop;
begin
  if FRead then
  begin
    duv_ok( uv_read_stop(FStream));
    FRead := false;
    if FShutdown then
       Clear;
  end;
end;

procedure TNPStream.setOnConnect(onConnect: TProc);
begin
  FOnConnect := onConnect;
end;

procedure TNPStream.setOnData(onData: TProc<PBufferRef>);
var
  wasAssigned : Boolean;
begin
  wasAssigned := assigned(FOnData);
  FOnData := onData;
  if assigned(FOnData) and not wasAssigned then
    read_start
  else
  if not assigned(FOnData) and wasAssigned then
    read_stop;
end;

procedure TNPStream.setOnEnd(onEnd: TProc);
begin
  FOnEnd := onEnd;
end;

procedure TNPStream.setOnError(OnError: TProc<PNPError>);
begin
  FOnError := onError;
end;

procedure TNPStream.shutdown(ACallBack:TProc);
begin
  if not is_closing and  not FError and not FShutdown  then
  begin
      if not FConnected then
         Clear
    else
    begin
      try
        FOnShutdown := ACallBack;
        uv_set_user_data(@FShutdownReq,self);
        duv_ok( uv_shutdown(@FShutdownReq,FStream,@__shutdown_cb) );
        FShutdown := true;
        FShutdownRef := self;
      except
        Clear;
      end;
    end;
  end;
end;

procedure TNPStream.tcp_connect(const address: TSockaddr_in_any);
begin
  if not FConnect then
  begin
    uv_set_user_data(@FConnectReq, self);
    duv_ok( uv_tcp_connect(@FConnectReq, puv_tcp_t(FHandle), @address, @__connect_cb) );
    FConnect := true;
    FConnectRef := self;
  end;
end;

function TNPStream.is_writable: Boolean;
begin
  result :=  uv_is_writable(FStream) <> 0;
end;

procedure TNPStream.onClose;
begin
  if FRead then
     read_stop;
  FOnData := nil;
  FOnEnd := nil;
  FOnError := nil;
  inherited;
end;

procedure TNPStream.pipe_bind(const name: UTF8String);
begin
  duv_ok( uv_pipe_bind(puv_pipe_t(FHandle),PUTF8Char(name)));
end;

procedure TNPStream.pipe_connect(const name: UTF8String);
begin
  if not FConnect then
  begin
    FConnect := true;
    uv_pipe_connect(@FConnectReq,puv_pipe_t(FHandle), PUTF8Char(name),@__connect_cb);
  end;
end;

procedure TNPStream.writeInternal(data: PByte; len: Cardinal; ACallBack: TProc);
var
  wd : PWriteData;
  status : integer;
begin
//  if len > 0 then
//  begin
    new(wd);
    wd.callback := ACallBack;
    uv_set_user_data(wd, self);
    if len > 0 then
    begin
      wd.buf.len := len;
      GetMem( wd.buf.base, len );
      move( data^, wd.buf.base^, len );
    end
    else
    begin
      wd.buf.len := 0;
      wd.buf.base := nil;
    end;
    wd.streamRef := self;
    status := uv_write(puv_write_t(wd),FStream, @wd.buf, 1, @__write_cb);
    if status <> 0 then
      _writecb(wd, status);
//  end;
end;

procedure TNPStream.write(const data: UTF8String; ACallBack: TProc);
begin
  if length(data) > 0 then
    writeInternal(@data[1],length(data), ACallBack)
  else
    writeInternal(nil,0, ACallBack)
end;

procedure TNPStream.write(const data: BufferRef; ACallBack: TProc);
begin
  writeInternal(data.ref,data.length, ACallBack)
end;

  procedure __on_close(handle: puv_handle_t); cdecl;
  var
    ud : TNPBaseHandle;
  begin
    ud :=  uv_get_user_data(handle);
    uv_set_close_cb(handle,nil);
    assert(assigned(ud));
    try
      ud.OnClose;
    except
    end;
    ud.FActiveRef := nil;
  end;

{ TNPBaseHandle }

procedure TNPBaseHandle.Clear;
begin
  if not is_closing then
  begin
    uv_close( Fhandle, uv_get_close_cb( Fhandle) );
  end;
end;

constructor TNPBaseHandle.Create(AHandleType: uv_handle_type);
var
  typeLen : size_t;
begin
  inherited Create;
  HandleType := AHandleType;
  case  HandleType  of
      UV_ASYNC         : typeLen := sizeof(uv_async_t);
      UV_CHECK         : typeLen := sizeof(uv_check_t);
      UV_IDLE          : typeLen := sizeof(uv_idle_t);
      UV_NAMED_PIPE    : typeLen := sizeof(uv_pipe_t);
      UV_PREPARE       : typeLen := sizeof(uv_prepare_t);
      UV_STREAM        : typeLen := sizeof(uv_stream_t);
      UV_TCP           : typeLen := sizeof(uv_tcp_t);
      UV_TIMER         : typeLen := sizeof(uv_timer_t);
      UV_PROCESS       : typeLen := sizeof(uv_process_t);
      UV_TTY           : typeLen := sizeof(uv_tty_t);
      else
          assert(false, Format('type %d not supported',[ord(HandleType)]));
  end;
  GetMem(FHandle, typeLen);
  FillChar(FHandle^,typeLen,0);
  uv_set_close_cb(Fhandle, @__on_close);
  uv_set_user_data(FHandle, self);
end;

destructor TNPBaseHandle.Destroy;
begin
  if assigned(Fhandle) then
  begin
    FreeMem(FHandle);
    FHandle := nil;
  end;
  inherited;
end;

function TNPBaseHandle.hasRef: Boolean;
begin
  result := uv_has_ref(Fhandle) <> 0;
end;

function TNPBaseHandle.is_closing: Boolean;
begin
  result := uv_is_closing(FHandle) <> 0;
end;

procedure TNPBaseHandle.onClose;
begin
  if assigned(FOnClose) then
  begin
    FOnClose();
  end;
  FOnClose := nil;
end;

procedure TNPBaseHandle.ref;
begin
  uv_ref(Fhandle);
end;

procedure TNPBaseHandle.setOnClose(OnClose: TProc);
begin
  FOnClose := OnClose;
end;

procedure TNPBaseHandle.unref;
begin
  uv_unref(Fhandle);
end;

function TNPBaseHandle._uv_handle: puv_handle_t;
begin
  result := FHandle;
end;

type
     TNPTimer = Class(TNPBaseHandle, INPTimer)
     protected
         procedure onClose; override;
     public
       FCallBack : Tproc;
       procedure SetRepeat(Arepeat: uint64);
       function  GetRepeat : uint64;
       procedure Again;
       constructor Create(ACallBack: TProc; Atimeout,Arepeat:uint64);
       destructor Destroy; override;
     end;

  procedure __cbTimer(handle: puv_timer_t); cdecl;
  var
    ud : TNPTimer;
    ref: INPHandle;
  begin
    ud := uv_get_user_data(handle);
    ref := ud.FActiveRef;
    if assigned(ud.FCallBack) then
    begin
      //this_timer := ud as INPTimer;
      try
        ud.FCallBack();
      except
      end;
    end;
    if  (uv_is_closing( puv_handle_t(handle) )=0) and (uv_is_active( puv_handle_t( handle ) ) = 0) then
      ref.Clear;
    //this_timer := nil;
  end;

  function Settimer(cb:TProc; Atimeout,Arepeat:uint64) : INPtimer;
  begin
    result := TNPTimer.Create(cb,ATimeout, ARepeat);
  end;

  procedure Cleartimer(var handle: INPTimer);
  begin
    if assigned(handle) then
    begin
      handle.Clear;
      handle := nil;
    end;
  end;

{ TNPTimer }

procedure TNPTimer.Again;
begin
  if (GetRepeat > 0) and (uv_is_active(FHandle) <> 0) then
    uv_timer_again(puv_timer_t(FHandle));
end;

constructor TNPTimer.Create(ACallBack: TProc; Atimeout,Arepeat:uint64);
begin
  FCallBack := ACallBack;
  inherited Create(UV_TIMER);
  uv_timer_init( loop.uvloop, puv_timer_t(FHandle) );
  duv_ok( uv_timer_start(puv_timer_t(FHandle),@__cbTimer,Atimeout,Arepeat) );
  FActiveRef := self;
end;

destructor TNPTimer.Destroy;
begin
 // outputDebugString('TNPTimer.Destroy');
  inherited;
end;

function TNPTimer.GetRepeat: uint64;
begin
  result := uv_timer_get_repeat(puv_timer_t(FHandle));
end;

procedure TNPTimer.onClose;
begin
  inherited;
  FCallBack := nil;
end;

procedure TNPTimer.SetRepeat(Arepeat: uint64);
begin
  uv_timer_set_repeat(puv_timer_t(FHandle), aRepeat);
end;


  function NextTick(p: TProc) : IQueueItem;
  begin
    result := loop.NextTick(p);
  end;
  function setImmediate(p: Tproc): IQueueItem;
  begin
    result := loop.setImmediate(p)
  end;


{ TNPTCPStream }

procedure TNPTCPStream.connect(const address: TSockAddr_in_any; ACallBack: TProc);
begin
  if assigned( ACallBack ) then
    setOnConnect(ACallBack);
  tcp_connect( address );
end;

procedure TNPTCPStream.connect(const address: UTF8String; port: word);
var
  addr: Tsockaddr_in_any;
  ref:  INPTCPConnect;
begin

  case IsIP(address) of
    4:
      begin
        duv_ok( uv_ip4_addr(PUTF8Char(address),Port,addr.ip4) );
        connect(addr);
      end;
    6:
      begin
        duv_ok( uv_ip6_addr(PUTF8Char(address),Port,addr.ip6) );
        connect(addr);
      end;
    else
    begin
      ref := self;
      dns_resolve(address,
               procedure (status: integer; resolved_address: UTF8String)
               begin
                 try
                   if status < 0 then
                     __onError(status)
                   else
                     connect(resolved_address, port);
                 except
                 end;
                 ref := nil;
               end);
    end;
  end;
end;

constructor TNPTCPStream.CreateClient(Server: INPTCPServer);
begin
   inherited Create();
   duv_ok( uv_accept( puv_stream_t(Server._uv_handle), puv_stream_t(FHandle) ) );
end;

constructor TNPTCPStream.CreateConnect();
begin
   inherited Create();
end;

destructor TNPTCPStream.Destroy;
begin
//  WriteLn('destroy: ',ClassName);
  inherited;
end;

   type
     PResolveReq = ^TResolveReq;
     TResolveReq = record
       req: uv_getaddrinfo_t;
       onResolved: TProc<integer,UTF8String>;
       addr : string;
     end;


procedure __on_resolved(req: puv_getaddrinfo_t; status:integer; res: _PAddrInfo); cdecl;
var
  lreq : PResolveReq;
  ip: UTF8String;
//  addr: UTF8String;
//  onResolved2: TProc<integer,UTF8String>;
begin
  lreq := PResolveReq(req);
  try
  if status >= 0 then
  begin
    case res.ai_family of
      2:
         begin
           SetLength(ip, 64);
           uv_ip4_name(PSockAddr_In(res.ai_addr),PAnsiChar(ip),64);
           SetLength(ip, CStrLen( PAnsiChar(ip) ));

           //move(res.ai_addr^, addr.ip4, sizeof( addr.ip4 ));
           //uv_set_ip_port(@addr.ip4,this.FConnectPort);
         end;
      23:
         begin
//           assert(false);
//           move(res.ai_addr^, addr.ip6, sizeof( addr.ip6 ));
//           uv_set_ip_port(@addr.ip4,this.FConnectPort);
            SetLength(ip, 64);
            uv_ip6_name(PSockAddr_In6(res.ai_addr),PAnsiChar(ip),64);
            SetLength(ip, CStrLen( PAnsiChar(ip) ));
         end;
    end;
  end;
  if res <> nil then
    uv_freeaddrinfo(res);
//  if status >= 0 then
    lReq.onResolved(status,ip);
//  else
//    begin
//       onResolved2 := lReq.onResolved;
//       addr := lReq.addr;
//         loop.newThread(
//             procedure
//             var
//               he : PHostEnt;
//               addrIn : TInAddr;
//             begin
//
//               he := np.winsock.gethostbyname(addr);
//               if  assigned(he) and (he.h_addrtype = AF_INET) then
//               begin
//                 addrIn.S_addr := PCardinal( he.h_address_list^ )^;
//                 ip := inet_ntoa(addrIn);
//                 status := 0;
//               end;
//             end,
//             procedure
//             begin
//               onResolved2(status,ip);
//             end
//         );
//
//    end;
  finally
    //lReq.onResolved := nil;
    dispose(lreq);
  end;
end;


   procedure dns_resolve(const addr: UTF8String; const onResolved: TProc<integer,UTF8String>);
   var
     req: PResolveReq;
   begin
     if  Assigned(onResolved) then
     begin
       new(req);
       req.addr := addr;
       req.onResolved := OnResolved;
       try
         duv_ok( uv_getaddrinfo(loop.uvloop,@req.req,@__on_resolved, PAnsiChar( addr ), nil ,nil));
       except
         req.onResolved := nil;
         dispose(req);
         raise;
       end;
     end;
   end;


{ TNPPipe }

procedure TNPPipe.connect(const AName: UTF8String);
begin
   pipe_connect(AName);
end;

constructor TNPPipe.Create();
begin
  inherited Create(UV_NAMED_PIPE);
  duv_ok( uv_pipe_init(Loop.uvloop,puv_pipe_t(FHandle),0) );
  FActiveRef := self;
end;


  type
    PHandler = ^THandler;
    THandler = record
       execute: TProc;
    end;

  procedure __cbThread(data: Pointer); cdecl;
  var
    handler : Phandler;
  begin
    handler := data;
    try
      handler.execute();
    except
    end;
    dispose(handler);
  end;

  function thread_create(p : TProc) : uv_thread_t;
  var
    handler: PHandler;
  begin
    if not assigned(p) then
       exit( 0 );

    new(handler);
    handler.execute := p;
    result := 0;
    if uv_thread_create(@result, @__cbThread, handler) <> 0 then
    begin
      dispose(handler);
      raise Exception.Create('Can not create thread');
    end;

  end;
  procedure thread_join(tid: uv_thread_t);
  begin
     if tid <> 0 then
       uv_thread_join(@tid);
  end;

{ TNPTTY }

procedure TNPTTY.beginPrint;
begin
  Inc(pcount);
end;

constructor TNPTTY.Create(fd: integer);
begin
  inherited Create(UV_TTY);
   FTTY := puv_tty_t(FHandle);
   duv_ok( uv_tty_init( loop.uvloop,FTTY,fd, 0) );
   FActiveRef := self;
end;

destructor TNPTTY.Destroy;
begin
  //Writeln('tty closed');
  inherited;
end;

procedure TNPTTY.endPrint;
begin
  dec(pcount);
  if pcount = 0 then
    flush;
end;

procedure write_cb(req: puv_write_t; status: integer); cdecl;
var
  wr: P_tty_w_req;
begin
  wr := P_tty_w_req(req);
 if status < 0 then
 begin
  //WriteLn('write_cb => "',uv_strerror( status ),'" msg:',wr.msg );
 end;
  wr.msg := '';
  Dispose(wr);
end;

procedure TNPTTY.flush;
begin
  write(pbuf);
  pbuf := '';
end;

procedure TNPTTY.get_winsize(out width, height: integer);
begin
  duv_ok( uv_tty_get_winsize(Ftty,width,height) );
  if (width = 0) or (height = 0)  then
  begin
    width  := 80;
    height := 25;
  end;

end;

procedure TNPTTY.MoveTo(x, y: integer);
begin
  Print(Format(#27'[%d;%dH', [y, x]));
end;

procedure TNPTTY.MoveTo1x1;
begin
  Print(#27'[H');
end;

procedure TNPTTY.MoveToY(y: integer);
begin
  Print(Format(#27'[%dH', [y]));
end;

procedure TNPTTY.MoveToX(x: integer);
begin
  Print(Format(#27'[;%dH', [x]));
end;

procedure TNPTTY.Print(const s: UTF8String);
begin
  if length(s) > 0 then
  begin
    beginPrint;
    pbuf := pbuf + s;
    endPrint;
  end;
end;

procedure TNPTTY.PrintLn(const s: UTF8String);
begin
  beginPrint;
     print(s);
     print(#13#10);
  endPrint;
end;



{ TNPTTY_INPUT }

constructor TNPTTY_INPUT.Create(raw:Boolean);
begin
  inherited Create(UV_TTY);
   duv_ok( uv_tty_init( loop.uvloop,puv_tty_t(FHandle), 0, 1) );
   if raw then
      uv_tty_set_mode(puv_tty_t(FHandle), UV_TTY_MODE_RAW);
   FActiveRef := self;
end;


procedure __exit_cb(process: puv_process_t; exit_status: Int64;
  term_signal: Integer); cdecl;
var
  ud : TNPSpawn;
begin
  ud := uv_get_user_data( process );
  ud._onExit(exit_status, term_signal);
//  uv_close(puv_handle_t(process), nil);

end;


{ TNPSpawn }

constructor TNPSpawn.Create();
begin
  inherited Create(UV_PROCESS);
  FProcess := puv_process_t(FHandle);
  Fargs := TStringList.Create;
  Fargs.Delimiter := ' ';
  Fargs.QuoteChar := '"';
end;

destructor TNPSpawn.Destroy;
begin
  freeAndNil(Fargs);
  if Foptions.args <> nil then
    FreeMem( Foptions.args );
  Foptions.args := nil;
  inherited;
end;

function TNPSpawn.getArgs: TStringList;
begin
  result := FArgs;
end;

function TNPSpawn.getCWD: String;
begin
  result := FCWD;
end;

function TNPSpawn.getFlags: uv_process_flags_set;
begin
   result := Foptions.flags;
end;

function TNPSpawn.getPID: integer;
begin
  result := uv_get_process_pid(FProcess);
end;

function TNPSpawn.GetStdio(inx: integer): puv_stdio_container_t;
begin
  if (inx >= Low(FStdio) ) and (inx <= High(FStdio)) then
  begin
     result := @Fstdio[inx];
     if inx >= Foptions.stdio_count then
        Foptions.stdio_count := inx+1;
  end
  else
    raise ERangeError.CreateFmt('Stdio num=%d!',[inx]);

end;

procedure TNPSpawn.kill(signnum: integer);
begin
  if FSpawn then
  begin
    duv_ok(uv_process_kill(@FProcess,signnum));
  end;
end;

procedure TNPSpawn.setCWD(const cwd: String);
begin
  if not FSpawn then
     FCWD := cwd;
end;

procedure TNPSpawn.setFlags(flags: uv_process_flags_set);
begin
  Foptions.flags := flags;
end;

procedure TNPSpawn.setOnExit(ACallBack: TProc<int64, integer>);
begin
  FOnExit := ACallBack;
end;

procedure TNPSpawn.spawn;
var
  i : integer;
  argsCount : integer;
begin
  if FSpawn then
    exit;
  FSpawn := true;
  argsCount := Fargs.Count;
  if argsCount = 0 then
    raise EArgumentException.Create('empty spawn.args');

  SetLength( Fcurrent_args, argsCount);
  for i := 0 to argsCount-1 do
  begin
    Fcurrent_args[i] := Fargs[i];
    assert(StringCodePage(Fcurrent_args[i]) = 65001);
  end;

//  fillchar( Foptions, sizeof(Foptions), 0);
  GetMem(Foptions.args,    (argsCount+1)* sizeof(PUTF8Char));
//  Fillchar(Foptions.args^, (argsCount+1)* sizeof(PUTF8Char), 0);
  for i := 0 to argsCount-1 do
    Foptions.args[i] := PUTF8Char(Fcurrent_args[i]);
  Foptions.args[argsCount] := nil;
  Foptions.&file := PUTF8Char(Foptions.args[0]);
  Foptions.exit_cb := @__exit_cb;
  if length(FCWD) > 0 then
    Foptions.cwd := PUTF8Char(FCWD);

  if FOptions.stdio_count > 0 then
     FOptions.stdio := @Fstdio;

  duv_ok( uv_spawn(Loop.uvloop,FProcess,@FOptions) );
  FActiveRef := self;
end;

procedure TNPSpawn._onExit(exit_status: Int64; term_signal: Integer);
begin
   if assigned(FOnExit) then
   try
     FOnExit(exit_status, term_signal);
   except
   end;
   Clear;
end;



  function stdOut : INPTTY;
  begin
    if not assigned(tv_stdOut) then
     tv_stdOut := TNPTTY.Create(FD_STDOUT);
    result := tv_stdOut;
  end;

  function stdErr : INPTTY;
  begin
    if not assigned(tv_stdErr) then
     tv_stdErr := TNPTTY.Create(FD_STDERR);
    result := tv_stdErr;
  end;

  function stdIn  : INPStream;
  begin
    if not assigned(tv_stdin) then
     tv_stdin := TNPTTY_INPUT.Create(false);
    result := tv_stdIn;
  end;

  function stdInRaw  : INPStream;
  begin
    if not assigned(tv_stdin) then
     tv_stdin := TNPTTY_INPUT.Create(true);
    result := tv_stdIn;
  end;




end.
