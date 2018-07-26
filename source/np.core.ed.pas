//event driven classes
unit np.core.ed;

interface
  uses
     system.sysUtils,
     np.core,
     np.EventEmitter,
     np.Buffer;

  const

    ev_open = 1;
    ev_connect = 1;
    ev_data = 2;
    ev_error = 3;
    ev_end  = 4;
    ev_close = 5;
    ev_sub_data = 10;

  Type
     IRWStream = interface( IEventEmitter )
        procedure resume;
        procedure pause;
        procedure write(const s : UTF8String; const cb : TProc = nil); overload;
        procedure write(const buf : BufferRef; const cb : TProc = nil); overload;
        procedure _end(const cb: TProc=nil);
        procedure unref;
     end;
     IEDTCPConnect = interface (IRWStream)
     end;
     IEDTCPClient = interface (IRWStream)
     end;

     //stream wrapper tcp connect
     TSWTCPConnect = class(TIEventEmitter, IEDTCPConnect, IRWStream)
     private
        this : IEventEmitter;
        connected: Boolean;
        flowing : Boolean;
        flowing_null: Boolean;
        procedure resume;
        procedure pause;
        procedure _end(const cb: Tproc);
        procedure write(const s : UTF8String; const cb: TProc = nil); overload;
        procedure write(const buf: BufferRef; const cb: Tproc = nil); overload;
        procedure unref;
     public
        stream: INPTCPConnect;
        constructor Create(const addr: string; port : word);
        destructor Destroy; override;
     end;

     TSWTCPClient = class(TIEventEmitter, IEDTCPClient, IRWStream)
     private
        this : IEventEmitter;
        flowing : Boolean;
        flowing_null: Boolean;
        procedure resume;
        procedure pause;
        procedure _end(const cb: Tproc);
        procedure write(const s : UTF8String; const cb: TProc = nil); overload;
        procedure write(const buf: BufferRef; const cb: Tproc = nil); overload;
        procedure unref;
     public
        stream: INPTCPStream;
        constructor Create(const server: INPTCPServer);
        destructor Destroy; override;
     end;


implementation


constructor TSWTCPConnect.Create( const addr: string; port : word );
var
  _readers : integer;
begin
  _readers := 0;
  inherited Create;
  this := self;
  flowing_null := true;
  FEventEmitter.onHandlerChange := procedure(id:integer; op : TEventEmitter.THandlerOperation)
                                   begin
                                      if (id = ev_data) then
                                      begin
                                        if (op = hoAdd) then
                                        begin
                                          inc(_readers);
                                          if (flowing_null) then
                                             resume;
                                        end
                                        else
                                        begin
                                          dec( _readers );
                                          if (_readers = 0) and (flowing) then
                                          begin
                                              pause;
                                              flowing_null := true;
                                          end;
                                        end;
                                      end;
                                   end;
  stream := TNPTCPStream.CreateConnect;
  stream.set_nodelay(true);
  stream.setOnConnect(
      procedure
      begin
        connected := true;
        if flowing then
          stream.setOnData(
             procedure(data: PBufferRef)
             begin
               this.emit(ev_data,data);
             end);
        this.emit(ev_open);
      end);
  stream.setOnEnd(
       procedure
       begin
         this.emit(ev_end);
       end);
  stream.setOnClose(
       procedure
       begin
         FEventEmitter.onHandlerChange := nil;
         this.emit(ev_close);
         this.RemoveAll; //remove cyrcular ref can be used in callbacks... fix here
         this := nil;
       end);
  stream.setOnError(
       procedure (error: PNPError)
       begin
         this.emit(ev_error, error);
       end);
  stream.connect(addr, port);
end;

destructor TSWTCPConnect.Destroy;
begin
//  WriteLn('TSWTCPConnect.Destroy');
  inherited;
end;

procedure TSWTCPConnect.pause;
begin
  flowing_null := false;
  if flowing then
  begin
     stream.setOnData(nil);
     flowing := false;
  end;
end;

procedure TSWTCPConnect.resume;
begin
  flowing_null := false;
  if not flowing then
  begin
    if connected then
      stream.setOnData(
           procedure(data: PBufferRef)
           begin
             this.emit(ev_data,data);
           end);
    flowing := true;
  end;
end;

procedure TSWTCPConnect.unref;
begin
  stream.unref;
end;

procedure TSWTCPConnect.write(const s: UTF8String; const cb: TProc);
begin
   stream.write(s,cb);
end;

procedure TSWTCPConnect.write(const buf: BufferRef; const cb: Tproc);
begin
   stream.write(buf,cb);
end;

procedure TSWTCPConnect._end(const cb: Tproc);
begin
  stream.shutdown(cb);
end;

{ TSWTCPClient }

constructor TSWTCPClient.Create(const server: INPTCPServer);
var
  _readers : integer;
begin
  _readers := 0;
  inherited Create;
  this := self;
  flowing_null := true;
  FEventEmitter.onHandlerChange := procedure(id:integer; op : TEventEmitter.THandlerOperation)
                                   begin
                                      if (id = ev_data) then
                                      begin
                                        if (op = hoAdd) then
                                        begin
                                          inc(_readers);
                                          if (flowing_null) then
                                             resume;
                                        end
                                        else
                                        begin
                                          dec( _readers );
                                          if (_readers = 0) and (flowing) then
                                          begin
                                            pause;
                                            flowing_null := true;
                                          end;
                                        end;
                                      end;
                                   end;
  stream := TNPTCPStream.CreateClient(server);
  stream.set_nodelay(true);
  stream.setOnEnd(
       procedure
       begin
         this.emit(ev_end);
       end);
  stream.setOnClose(
       procedure
       begin
         FEventEmitter.onHandlerChange := nil;
         this.emit(ev_close);
         this.RemoveAll; //remove cyrcular ref can be used in callbacks... fix here
         this := nil;
       end);
  stream.setOnError(
       procedure (error: PNPError)
       begin
         this.emit(ev_error, error);
       end);
  this.emit(ev_open);
end;


destructor TSWTCPClient.Destroy;
begin
//  WriteLn('TSWTCPClient.Destroy');
  inherited;
end;

procedure TSWTCPClient.pause;
begin
  flowing_null := false;
  if flowing then
  begin
     stream.setOnData(nil);
     flowing := false;
  end;
end;

procedure TSWTCPClient.resume;
begin
  flowing_null := false;
  if not flowing then
  begin
    stream.setOnData(
           procedure(data: PBufferRef)
           begin
             this.emit(ev_data,data);
           end);
    flowing := true;
  end;
end;

procedure TSWTCPClient.unref;
begin
  stream.unref;
end;

procedure TSWTCPClient.write(const s: UTF8String; const cb: TProc);
begin
   stream.write(s,cb);
end;

procedure TSWTCPClient.write(const buf: BufferRef; const cb: Tproc);
begin
   stream.write(buf,cb);
end;

procedure TSWTCPClient._end(const cb: Tproc);
begin
  stream.shutdown(cb);
end;

end.
