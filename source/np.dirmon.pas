unit np.dirmon;

interface
    uses sysUtils, np.common, np.core, np.fs, np.promise, np.libuv, np.value, np.EventEmitter;
const
   RefreshDelayDefault = 2000;
    evScanComplete = 1;
    evResourceChanged = 2;
    evResourceInitialized = 3;
    evScanProgress = 4;
type
    TResourceStat = class;
    PResourceChanged = ^TResourceChanged;
    TResourceHash = class;
    IResourceStat = IValue<TResourceStat>;
    IResourceHash  = IValue<TResourceHash>;

    TResourceChanged = record
       name:   string;
       error:  PNPError;
       status: TResourceStat;
    end;
    PScanComplete = ^IResourceHash;


    TResourceStat = Class(TSelfValue,IResourceStat)
    private
       Flink : IResourceHash;
       Fid : string;
       Fversion : integer;
       FchangeTime : Double;
       Fcontent_type: string;
       Fcontent : TBytes;
       Fcontent_version: integer;
       Fdelay: INPTimer;
       FupdateMode: Boolean;
       Fupdate: record
                 version : integer;
                 changeTime : Double;
                 content: TBytes;
                 prevent_destroy_while_update_self_link : IResourceStat;
               end;
       procedure LoadVersion;
       procedure LoadVersionBegin;
       procedure LoadVersionDo;
       procedure LoadVersionDoAgain;
       procedure LoadVersionEnd(Error: PNPError);
       function this : TResourceStat;
       constructor Create(const ADirHash:IResourceHash; const resId:string);
    public
       property name : String read FId;
       property content : TBytes read Fcontent;
       property version: integer read Fcontent_version;
       property last_modified : Double read FchangeTime;
       property RSRCHash: IResourceHash read Flink;
    end;

    TResourceHash = Class(TEventEmitterAnyObject, IResourceHash )
    private
       Fdir : String;
       FRefreshDelay: integer;
       FWatchLink : IResourceHash;
       FScanLink  : IResourceHash;
       FScanComplete : Boolean;
       function this: TResourceHash;
       procedure runScan;
       procedure runWatch;
    protected
       function _add(id: integer; p: TProc; once: Boolean; hasArg: Boolean) : IEventHandler; override;
    public
       constructor Create(const ADirectory: String; ARefreshDelay:integer = RefreshDelayDefault);
       function GetStat(const resourceId : string; ACreate:Boolean = false) : IResourceStat;
       property Dir : string read FDir;
    end;


implementation

{ TResourceStat }

constructor TResourceStat.Create(const ADirHash:IResourceHash; const resId:string);
begin
   inherited Create();
   Flink := ADirHash;
   Fid := resId;
end;

{ TResourceHash }

constructor TResourceHash.Create(const ADirectory: String;
  ARefreshDelay: integer);
begin
  inherited Create();
  Fdir := ADirectory;
  FRefreshDelay := ARefreshDelay;
  FScanLink := self;
  FWatchLink := self;
  NextTick(
     procedure
     begin
       RunScan;
     end);
  once(evScanComplete,
       procedure
       begin
         FScanComplete := true;
       end);
end;

function TResourceHash.GetStat(const resourceId: string; ACreate: Boolean): IResourceStat;
var
  tmp : IValue;
begin
   tmp := getValue(resourceId);
   if not (tmp is TResourceStat) then
   begin
      if not ACreate then
        exit(nil);
      tmp := TResourceStat.Create(self, resourceId);
      SetValue(resourceId, tmp);
   end;
   result := tmp as IResourceStat;
   if not ACreate and (result.this.version = 0) then
      result := nil;
end;


procedure TResourceHash.runWatch;
begin
  setFSWatch(
       procedure(event: TFS_Event; Afile:UTF8String)
       begin
           GetStat(AFile, true).this.LoadVersion;
       end, FDir);
end;

procedure TResourceHash.runScan;
var
  scaning_count : integer;
begin
  scaning_count := 0;
  fs.readdir(
        Fdir,
        procedure (error: PNPError; list: fs.TDirentWithTypesArray)
        var
          i : integer;
          this : IResourceHash;
        begin
           if error <> nil then
           begin
              raise ENPException.Create(error.code);
           end;
           for i := low(list) to high(list) do
           begin
              if list[i].type_ = UV_DIRENT_FILE then
              begin
                 with GetStat(list[i].name, true ).this do
                 begin
                   inc( scaning_count );
                   LoadVersionBegin;

                 end;
              end;
           end;
           FScanLink := nil;
           if scaning_count = 0 then
           begin
              this := self;
              emit(evScanComplete, @this  );
              this := nil;
           end;

           runWatch;
        end
  );
  on_(evResourceInitialized,
        procedure
        var
          this : IResourceHash;
        begin
          dec( scaning_count );
          if scaning_count = 0 then
          begin
            this := self;
            emit(evScanComplete, @this  );
            this := nil;
          end;
        end);

end;

procedure TResourceStat.LoadVersionEnd(error: PNPError);
var
   arg : TResourceChanged;
begin
   FupdateMode := false;
   arg.name := FId;
   arg.error := error;
   arg.status := self;
   if assigned(Flink) then
   begin
     if error <> nil then
     begin
       //stderr.PrintLn(Format('%s error "%s"',[Fid, error.msg] ));
       Fversion := 0;
       Flink.this.DeleteKey(Fid);
       Flink.this.emit(evResourceChanged,  @arg );
       Flink := nil;
     end
     else
     begin
       //stdout.PrintLn(Format('%s updated! (ver. %d)',[Fid,Fversion] ));
       Flink.this.emit(evResourceChanged,  @arg );
     end;
   end;
   Fupdate.prevent_destroy_while_update_self_link := nil;
end;

function TResourceStat.this: TResourceStat;
begin
   result := Self;
end;

procedure TResourceStat.LoadVersion;
begin
  if assigned( Fdelay ) then
     Cleartimer(Fdelay);
  Fdelay := SetTimeout(
     procedure
     begin
        Fdelay := nil;
        LoadVersionBegin;
     end,Flink.this.FRefreshDelay);
end;

procedure TResourceStat.LoadVersionBegin;
begin
    inc(Fversion);
    //stdout.PrintLn(Format('%s updating... (ver. %d->%d)',[Fid,Fversion-1,Fversion] ));
    if FupdateMode then
       exit;
    FupdateMode := true;
    LoadVersionDo;
end;

procedure TResourceStat.LoadVersionDo;
var
  path : string;
begin
  assert(FupdateMode);
  Fupdate.prevent_destroy_while_update_self_link := self;
  Fupdate.version := Fversion;
  path := Flink.this.Fdir + PathDelim + Fid;
  fs.stat(path,
     procedure (error: PNPError; stat1 : puv_stat_t )
     begin
       if assigned(error) then
       begin
         LoadVersionEnd(error);
         exit;
       end;
       Fupdate.changeTime := stat1.st_mtim.toTimeStamp;
       SetLength( Fupdate.content, stat1.st_size );
       fs.open(path,UV_FS_O_RDONLY,oct666,
             procedure (error: PNPError; fd : uv_file)
             begin
               if assigned(error) then
               begin
                 LoadVersionEnd(error);
                 exit;
               end;
                 fs.read(fd, Fupdate.content,
                     procedure (error:PNPError; num: size_t; buf: TBytes )
                     begin
                       if assigned(error) then
                       begin
                         LoadVersionEnd(error);
                         exit;
                       end;
                       if length(buf) <> num then
                       begin
                         LoadVersionDoAgain;
                       end;
                       fs.fstat(fd,
                          procedure(error:PNPError; stat1: puv_stat_t)
                          begin
                             fs.close(fd,nil);
                             if assigned(error) then
                             begin
                               LoadVersionEnd(error);
                               exit;
                             end;
                            if (Fupdate.changeTime = stat1.st_mtim.toTimeStamp) and
                               (length(Fupdate.content) = stat1.st_size)  then
                            begin
                                Fcontent := Fupdate.content;
                                Fcontent_version := Fupdate.version;
                                FchangeTime := Fupdate.changeTime;
                                if Fupdate.version = 1 then
                                   FLink.this.emit(evResourceInitialized);
                                FupdateMode := Fupdate.version <> Fversion;
                                if FupdateMode then
                                begin
                                  LoadVersionDoAgain;
                                end
                                else
                                begin
                                  LoadVersionEnd(nil);
                                end;
                            end
                            else
                            begin
                              LoadVersionDoAgain;
                            end;
                          end);
                     end);
             end);
     end);
end;


procedure TResourceStat.LoadVersionDoAgain;
begin
  SetTimeout(
    procedure
    begin
      LoadVersionDo;
    end, 1000);
end;

function TResourceHash.this: TResourceHash;
begin
  result := self;
end;

function TResourceHash._add(id: integer; p: TProc; once,
  hasArg: Boolean): IEventHandler;
var
  imd : IEventHandler;
  this : IResourceHash;
begin
    result := inherited _add(id,p,once,hasArg);
    if (id = evScanComplete) and (FScanComplete) then
    begin
      imd := result;
      this := self;
      NextTick(
         procedure
         begin
            imd.invoke(@this);
         end);
    end;
end;

end.
