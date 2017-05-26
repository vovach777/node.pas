unit np.buildData;

interface
  uses classes, np.buffer;

  type
    PBuildData = ^TBuildData;
    TBuildData = record
       buf: BufferRef;
       function append(const Str : UTF8String) : PBuildData; overload;
       function appendOrdinal<T>(data:T) : PBuildData;
       function append(data:Pointer; dataLen: Cardinal) : PBuildData; overload;
       function append(const data: BufferRef) : PBuildData; overload;
    end;

implementation

{ TBuildData }

function TBuildData.append(const Str: UTF8String): PBuildData;
begin
  if length(str) > 0 then
  begin
     optimized_append(buf,BufferRef.CreateWeakRef(@Str[1],Length(Str)));
  end;
  result := @self;
end;

function TBuildData.append(data: Pointer; dataLen: Cardinal): PBuildData;
begin
  if dataLen > 0 then
    optimized_append(buf,BufferRef.CreateWeakRef(data,DataLen));
  result := @self;
end;

function TBuildData.append(const data: BufferRef): PBuildData;
begin
  optimized_append(buf,data);
  result := @self;
end;

function TBuildData.appendOrdinal<T>(data: T): PBuildData;
begin
  optimized_append(buf,Buffer.pack<T>(data));
  result := @self;
end;

end.
