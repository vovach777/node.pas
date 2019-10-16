unit np.fs;

interface
  uses sysUtils, np.common, np.libuv, np.core;

  const
    oct777 = 511;
    oct666 = 438;
    oct444 = 292;
  type
   fs = record
   type
      TRWCallback = TProc<PNPError, size_t, TBytes>;
      TDirentWithTypes = record
                            name : UTF8String;
                            type_ : uv_dirent_type_t;
                         end;
      TCallback = TProc<PNPError>;
      TReadlinkCallBack = TProc<PNPError,UTF8String>;
      TStatCallback = TProc<PNPError, puv_stat_t>;
      TDirentCallBack = TProc<PNPError, TArray<UTF8String>>;
      TDirentArray = TArray<UTF8String>;
      TDirentWithTypesArray = TArray<TDirentWithTypes>;
      TDirentWithTypesCallBack = TProc<PNPError, TDirentWithTypesArray>;
      class procedure open(const path: UTF8String; flags:integer; mode:integer; cb : TProc<PNPError,uv_file>);static;
      class procedure close(Afile : uv_file; cb : TCallback); static;
      class procedure read(Afile : uv_file; Abuffer:TBytes; Aoffset : size_t; Alength: size_t; APosition:int64; cb : TRWCallback); overload; static;
      class procedure read(Afile : uv_file; Abuffer:TBytes; Aoffset : size_t; Alength: size_t; cb : TRWCallback); overload; static;
      class procedure read(Afile : uv_file; Abuffer:TBytes; APosition:int64; cb : TRWCallback); overload; static;
      class procedure read(Afile : uv_file; Abuffer:TBytes; cb : TRWCallback); overload; static;
      class procedure write(Afile : uv_file; Abuffer:TBytes; Aoffset : size_t; Alength: size_t; APosition:int64; cb : TRWCallback); overload; static;
      class procedure write(Afile : uv_file; Abuffer:TBytes; Aoffset : size_t; Alength: size_t; cb : TRWCallback); overload; static;
      class procedure write(Afile : uv_file; Abuffer:TBytes; APosition:int64; cb : TRWCallback); overload; static;
      class procedure write(Afile : uv_file; Abuffer:TBytes; cb : TRWCallback); overload; static;
      class procedure ftruncate(Afile : uv_file;offset:int64; cb: TCallback); overload; static;
      class procedure ftruncate(Afile : uv_file;cb: TCallback); overload; static;
      class procedure unlink(const path:UTF8String; cb: TCallback); static;
      class procedure stat(const path:UTF8String; cb: TStatCallback); static;
      class procedure fstat(const aFile:uv_file; cb: TStatCallback); static;
      class procedure lstat(const path:UTF8String; cb: TStatCallback); static;
      class procedure utime(const path:UTF8String;Aatime:Double; Amtime:Double; cb: TCallback); static;
      class procedure futime(const aFile:uv_file;Aatime:Double; Amtime:Double; cb: TCallback); static;
      class procedure fsync(Afile: uv_file; cb : TCallBack); static;
      class procedure access(const path: UTF8String; mode: integer; cb: TCallBack); static;
      class procedure fdatasync(Afile: uv_file; cb : TCallBack); static;
      class procedure mkdir(const path:UTF8String; mode:integer; cb: TCallBack); static;
      class procedure mkdtemp(const path:UTF8String; mode:integer; cb: TCallBack); static;
      class procedure rmdir(const path:UTF8String; mode:integer; cb: TCallBack); static;
      class procedure readdir(const path:UTF8String; cb: TDirentCallBack); overload;  static;
      class procedure readdir(const path:UTF8String; cb: TDirentWithTypesCallBack); overload;  static;
      class procedure rename(const path:UTF8String; const new_path : UTF8String; cb : TCallBack); static;
      class procedure copyfile(const path:UTF8String; const new_path : UTF8String; flags: integer; cb : TCallBack); overload; static;
      class procedure copyfile(const path:UTF8String; const new_path : UTF8String; cb : TCallBack); overload; static;
      class procedure symlink(const path:UTF8String; const new_path : UTF8String; flags: integer; cb : TCallBack); overload; static;
      class procedure link(const path:UTF8String; const new_path : UTF8String; cb : TCallBack); overload; static;
      class procedure readlink(const path:UTF8String; cb : TReadlinkCallBack); static;
      class procedure realpath(const path:UTF8String; cb : TReadlinkCallBack); static;
   end;


implementation
  uses generics.collections;

 type
   PReqInternal = ^TReqInternal;
   TReqInternal = packed record
      base: uv_fs_t;
      //path: UTF8String; //keep ref
      callback_open:   TProc<PNPError,uv_file>;
      callback_error:  fs.TCallback;
      buffer: TBytes;
      callback_rw:  fs.TRWCallback;
      callback_stat: fs.TStatCallback;
      callback_dirent: fs.TDirentCallBack;
      callback_direntWithTypes: fs.TDirentWithTypesCallBack;
      callback_readlink : fs.TReadlinkCallBack;
   end;

   procedure fs_cb(req :puv_fs_t); cdecl;
   var
      cast : PReqInternal;
      error : TNPError;
      perror: PNPError;
      res   : SSIZE_T;
      dirent: uv_dirent_t;
      direntResWt : TList<fs.TDirentWithTypes>;
      direntRes   : TList<UTF8String>;
      direntItem : fs.TDirentWithTypes;
      stat : puv_stat_t;
   begin
      cast := PReqInternal(req);
      perror := nil;
      res := uv_fs_get_result(req);
      if res < 0 then
      begin
        error.Init( integer(res) );
        perror := @error;
      end;
      try
        case uv_fs_get_type(req) of
           UV_FS_OPEN_:
                begin
                  if assigned( cast.callback_open ) then
                     cast.callback_open(pError, res );
                end;
           UV_FS_READ_,UV_FS_WRITE_:
                begin
                   if assigned( cast.callback_rw ) then
                      cast.callback_rw(perror,res,cast.buffer);
                end;
           UV_FS_STAT_, UV_FS_LSTAT_, UV_FS_FSTAT_:
                begin
                   if assigned( cast.callback_stat) then
                   begin
                      if res >= 0 then
                      begin
                         stat := uv_fs_get_statbuf(cast.base);
                         cast.callback_stat(nil, stat);
                      end
                      else
                        cast.callback_stat(perror, nil);
                   end;
                end;
           UV_FS_SCANDIR_:
                begin
                  if assigned(perror) then
                  begin
                      if assigned(cast.callback_direntWithTypes) then
                          cast.callback_direntWithTypes(perror,nil)
                      else
                      if assigned(cast.callback_dirent) then
                          cast.callback_dirent(perror,nil);
                  end
                  else
                  if assigned(cast.callback_direntWithTypes) then
                  begin
                      direntResWt := TList<fs.TDirentWithTypes>.Create;
                      try
                        while uv_fs_scandir_next( req, @dirent ) >= 0 do
                        begin
                           direntItem.name := CStrUtf8( dirent.name );
                           direntItem.type_ := dirent.&type;
                           direntResWt.Add( direntItem );
                        end;
                        cast.callback_direntWithTypes(nil, direntResWt.ToArray);
                      finally
                        direntResWt.Free;
                      end;
                  end
                  else
                  if assigned(cast.callback_dirent) then
                  begin
                      direntRes := TList<UTF8String>.Create;
                      try
                        while uv_fs_scandir_next( req, @dirent ) >= 0 do
                        begin
                           direntRes.Add( CStrUtf8( dirent.name ) );
                        end;
                        cast.callback_dirent(nil, direntRes.ToArray);
                      finally
                        direntRes.Free;
                      end;
                  end;
                end;
           UV_FS_READLINK_, UV_FS_REALPATH_:
                begin
                   if assigned( cast.callback_readlink ) then
                   begin
                      if assigned(pError) then
                        cast.callback_readlink(pError,'')
                      else
                        cast.callback_readlink(pError,CStrUtf8( uv_fs_get_ptr(req) ));
                   end;
                end;
           else
                begin
                   if assigned( cast.callback_error ) then
                      cast.callback_error(pError)
                end;
        end;
      finally
        uv_fs_req_cleanup(req);
        Dispose(cast);
      end;
   end;

{ fs }

class procedure fs.access(const path: UTF8String; mode: integer; cb: TCallBack);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_access(loop.uvloop, @req.base, @path[1], mode, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error)
          end;
       end);
   end;
end;

class procedure fs.close(Afile: uv_file; cb: TProc<PNPError>);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_close(loop.uvloop, @req.base, aFile, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error)
          end;
       end);
   end;
end;

class procedure fs.ftruncate(Afile: uv_file; cb: TCallback);
begin
  fs.ftruncate(aFile,0,cb);
end;

class procedure fs.ftruncate(Afile: uv_file; offset: int64; cb: TCallback);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_ftruncate(loop.uvloop, @req.base, aFile, offset, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error)
          end;
       end);
   end;
end;

class procedure fs.open(const path: UTF8String; flags, mode: integer;
  cb: TProc<PNPError,uv_file>);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   //req.path := path; //keep ref...but why?!
   req.callback_open := cb;
   res := uv_fs_open(loop.uvloop, @req.base, @path[1], flags, mode, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
         procedure
         var
           error : TNPError;
         begin
           if assigned(cb) then
           begin
              error.Init(res);
              cb(@error,res);
           end;
         end);
   end;
end;

class procedure fs.read(Afile : uv_file; Abuffer:TBytes;
                  Aoffset : size_t; Alength: size_t;
                  APosition:int64;
                  cb : TRWCallback);
var
  req : PReqInternal;
  res : Integer;
  buf : uv_buf_t;
begin
   if Alength > High(buf.len) then
      ALength := High(buf.len);
   if ALength + AOffset > Length(Abuffer) then
      raise ERangeError.CreateFmt('range error buffer[%d..%d] length = %d', [AOffset,AOffset + ALength-1, Length(ABuffer)] );
   New(req);
   req.callback_rw := cb;
   req.buffer := Abuffer;
   buf.len := Alength;
   buf.base := @ABuffer[AOffset];
   res := uv_fs_read(loop.uvloop, @req.base, Afile, @buf, 1, APosition, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
         procedure
         var
           error : TNPError;
         begin
           if assigned(cb) then
           begin
              error.Init(res);
              cb(@error,0,ABuffer);
           end;
         end);
   end;
end;

class procedure fs.write(Afile : uv_file; Abuffer:TBytes;
                  Aoffset : size_t; Alength: size_t;
                  APosition:int64;
                  cb : TRWCallback);
var
  req : PReqInternal;
  res : Integer;
  buf : uv_buf_t;
begin
   if ALength + AOffset > Length(Abuffer) then
      raise ERangeError.CreateFmt('range error buffer[%d..%d] length = %d', [AOffset,AOffset + ALength-1, Length(ABuffer)] );
   New(req);
   req.callback_rw := cb;
   req.buffer := Abuffer;
   if Alength > High(buf.len) then
      ALength := High(buf.len);
   buf.len := Alength;
   buf.base := @ABuffer[AOffset];
   res := uv_fs_write(loop.uvloop, @req.base, Afile, @buf, 1, APosition, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
         procedure
         var
           error : TNPError;
         begin
           if assigned(cb) then
           begin
              error.Init(res);
              cb(@error,0,ABuffer);
           end;
         end);
   end;
end;


class procedure fs.read(Afile : uv_file; Abuffer:TBytes; Aoffset : size_t; Alength: size_t; cb : TRWCallback);
begin
  fs.read(Afile,ABuffer,Aoffset, Alength, -1, cb);
end;
class procedure fs.read(Afile : uv_file; Abuffer:TBytes; APosition:int64; cb : TRWCallback);
begin
  fs.read(Afile,ABuffer,0, length(ABuffer), APosition, cb);
end;
class procedure fs.read(Afile : uv_file; Abuffer:TBytes; cb : TRWCallback);
begin
  fs.read(Afile,ABuffer, -1, cb);
end;

class procedure fs.readdir(const path: UTF8String;
  cb: TDirentWithTypesCallBack);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_direntWithTypes := cb;
   res := uv_fs_scandir(loop.uvloop, @req.base, @path[1],0, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error,nil);
          end;
       end);
   end;
end;

class procedure fs.readlink(const path: UTF8String; cb: TReadlinkCallBack);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_readlink := cb;
   res := uv_fs_readlink(loop.uvloop, @req.base, @path[1],@fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error,'');
          end;
       end);
   end;
end;

class procedure fs.realpath(const path: UTF8String; cb: TReadlinkCallBack);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_readlink := cb;
   res := uv_fs_realpath(loop.uvloop, @req.base, @path[1],@fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error,'');
          end;
       end);
   end;
end;

class procedure fs.rename(const path, new_path: UTF8String; cb:TCallBack);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_rename(loop.uvloop, @req.base, @path[1],@new_path[1], @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error);
          end;
       end);
   end;
end;

class procedure fs.readdir(const path: UTF8String; cb: TDirentCallBack);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_dirent := cb;
   res := uv_fs_scandir(loop.uvloop, @req.base, @path[1],0, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error,nil);
          end;
       end);
   end;
end;

class procedure fs.stat(const path: UTF8String; cb: TStatCallback);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_stat := cb;
   res := uv_fs_stat(loop.uvloop, @req.base, @path[1], @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error,nil);
          end;
       end);
   end;
end;

class procedure fs.symlink(const path, new_path: UTF8String; flags: integer;
  cb: TCallBack);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_symlink(loop.uvloop, @req.base, @path[1],@new_path[1],flags, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error);
          end;
       end);
   end;
end;

class procedure fs.link(const path, new_path: UTF8String; cb: TCallBack);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_link(loop.uvloop, @req.base, @path[1],@new_path[1],@fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error);
          end;
       end);
   end;
end;

class procedure fs.lstat(const path: UTF8String; cb: TStatCallback);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_stat := cb;
   res := uv_fs_lstat(loop.uvloop, @req.base, @path[1], @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error,nil);
          end;
       end);
   end;
end;

class procedure fs.mkdir(const path: UTF8String; mode: integer; cb: TCallBack);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_mkdir(loop.uvloop, @req.base, @path[1],mode, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error);
          end;
       end);
   end;
end;

class procedure fs.mkdtemp(const path: UTF8String; mode: integer; cb: TCallBack);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_mkdtemp(loop.uvloop, @req.base, @path[1], @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error);
          end;
       end);
   end;
end;

class procedure fs.rmdir(const path: UTF8String; mode: integer; cb: TCallBack);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_rmdir(loop.uvloop, @req.base, @path[1], @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error);
          end;
       end);
   end;
end;

class procedure fs.fstat(const afile: uv_file; cb: TStatCallback);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_stat := cb;
   res := uv_fs_fstat(loop.uvloop, @req.base, afile, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error,nil);
          end;
       end);
   end;
end;

class procedure fs.fsync(afile: uv_file; cb: TCallback);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_fsync(loop.uvloop, @req.base, afile, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error);
          end;
       end);
   end;
end;

class procedure fs.copyfile(const path, new_path: UTF8String; flags: integer;
  cb: TCallBack);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_copyfile(loop.uvloop, @req.base, @path[1],@new_path[1],flags, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error);
          end;
       end);
   end;
end;

class procedure fs.copyfile(const path, new_path: UTF8String; cb: TCallBack);
begin
  copyfile(path, new_path,0,cb);
end;

class procedure fs.fdatasync(afile: uv_file; cb: TCallback);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_fdatasync(loop.uvloop, @req.base, afile, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error);
          end;
       end);
   end;
end;

class procedure fs.unlink(const path: UTF8String; cb: TCallback);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_unlink(loop.uvloop, @req.base, @path[1], @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error)
          end;
       end);
   end;
end;

class procedure fs.futime(const aFile:uv_file;Aatime:Double; Amtime:Double; cb: TCallback);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_futime(loop.uvloop, @req.base,afile,Aatime,Amtime, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error)
          end;
       end);
   end;
end;

class procedure fs.utime(const path: UTF8String; Aatime:Double; Amtime:Double; cb: TCallback);
var
  req : PReqInternal;
  res : Integer;
begin
   New(req);
   req.callback_error := cb;
   res := uv_fs_utime(loop.uvloop, @req.base, @path[1],Aatime,Amtime, @fs_cb);
   if res < 0 then
   begin
     Dispose(req);
     NextTick(
       procedure
       var
          error : TNPError;
       begin
          if assigned(cb) then
          begin
             error.Init(res);
             cb(@error)
          end;
       end);
   end;
end;

class procedure fs.write(Afile: uv_file; Abuffer: TBytes; cb: TRWCallback);
begin
  fs.write(afile,aBuffer,0,length(aBuffer),cb);
end;

class procedure fs.write(Afile: uv_file; Abuffer: TBytes; APosition: int64;
  cb: TRWCallback);
begin
  fs.write(afile,aBuffer,0,length(aBuffer),APosition,cb);
end;

class procedure fs.write(Afile: uv_file; Abuffer: TBytes; Aoffset,
  Alength: size_t; cb: TRWCallback);
begin
   fs.write(afile,ABuffer,AOffset,ALength,-1,cb);
end;

end.
