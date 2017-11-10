program ex08_httpClient;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  np.core,
  np.buffer,
  np.ut,
  System.SysUtils,
  uHttpConnect in 'uHttpConnect.pas',
  onf_aes in 'H:\VideoServerForWeb_xe10\source\onf_aes.pas';


function encryptText(const KeyEnc: ExpandedKey; json: UTF8String): BufferRef;
var
  res : BufferRef;
  src,dst, prev : PByte;
  len : integer;
begin
   prev := nil;
   SetLengthZ(RawByteString(json), (length(json)+15) and not $f);
   len := length(json);
   result := Buffer.Create(len);
   dst := result.ref;
   src := @json[1];
   while len <> 0 do
   begin
     if prev <> nil then
     begin
        PUint64(src)^ := PUint64(src)^ xor PUint64(prev)^;
        PUint64(src+8)^ := PUint64(src+8)^ xor PUint64(prev+8)^;
     end;
     prev := dst;
     Encrypt(KeyEnc,src,dst);
     inc(src,16);
     inc(dst,16);
     dec(len,16);
   end;
end;


procedure Main;
  var
    c: THttpConnect;
    r_image,
    r_login : TBaseHttpRequest;
    sessionId: string;
    key: ExpandedKey;
    pkey : BufferRef;
    sLogin : TProc;
    timeout : INPTimer;
    noObj : boolean;
  begin
     noObj := false;
     pKey := Buffer.CreateFromHex('6d1f3385b613214fba643f891ce18630');
     KeySetupEnc(key,pKey.ref);
//    stdInRaw.setOnData(
//          procedure(data:Pbyte; len: cardinal)
//          begin
//          end
//    );
//    //https://127.0.0.1:4433/api/1/live/73
     c := THttpConnect.Create('http://127.0.0.1:8282');

//     setTimeout(
//       procedure
//       begin
//          WriteLn('timeout');
//          c.Shutdown;
//       end,10000);

     c.on_(ev_BeforeProcess,
       procedure (arg: Pointer)
       var
         req: TBaseHttpRequest;
       begin
         req := arg;
         WriteLn(req.ReqMethod,' ',req.ReqPath);
       end
     );
     c.on_(ev_connected,
        procedure
        begin
           WriteLn('connected!');
        end);
     c.on_(ev_disconnected,
     procedure
     begin
       WriteLn('disconnected!');
     end);
     c.on_(ev_connecting,
     procedure
     begin
       WriteLn('ev_connecting',' ',c.url.HttpHost);
     end);
//   r := TBaseHttpRequest.Create(c);
//   r.beginHeader('GET','/api/1/live/73');
//   r.endHeader();
//   r.CompleteReaction := crReuse;
     r_image := TBaseHttpRequest.Create(c);
     r_image.on_(ev_BeforeProcess,
               procedure
               begin
                 assert( sessionId <> '');
                 r_image.beginHeader('GET','/api/1/live/73');
                 r_image.beginCookie;
                 r_image.addCookie('VIDEOSESID',sessionId);
                 r_image.endCookie;
                 r_image.endHeader();
               end);
     r_image.on_(ev_Complete,
              procedure
              var
                timeout : INPTimer;
              begin
                if (r_image.statusCode = 403) then
                begin
                   r_login.resume;
                end
                else
                if r_image.statusCode <> 200 then
                begin
                  ///r_image.CompleteReaction := crFree;
                  ///c.Shutdown;
                  WriteLn('Error ',r_image.statusCode,' ', r_image.statusReason);
//                  SetTimeout(
//                      procedure
//                      begin
//                         if assigned( r_image ) then
//                           r_image.resume;
//                      end,5000).unref;
                end
                else
                begin
                  // WriteLn(r_image.ResponseHeader.Fields['content-type'],' ', r_image.ResponseHeader.Fields['content-length']);
                   r_image.resume;
                end;
              end);
                  //need login
    r_login := TBaseHttpRequest.Create(c);
    r_login.on_(ev_BeforeProcess,
              procedure
               var
                 ts : integer;
                 br : BufferRef;
                 token : UTF8String;
              begin
                ts := CurrentTimeStamp div 1000;
                token := Format('%d%d|%d|bot|1234567|*|%d', [random(MaxInt),random(MaxInt),ts,ts]);
                br := encryptText(key, token);
                r_login.beginHeader('GET','/api/1/login/'+br.ToHex);
                r_login.endHeader();
              end);

    r_login.on_(ev_Complete,
         procedure
         begin
           sessionId := r_login.ResponseHeader.Fields['set-cookie.videosesid'];
           if (r_login.statusCode = 200) and (sessionId <> '') then
           begin
              WriteLn('session ', sessionId);
              r_image.resume;
           end
           else
           begin
               WriteLn(r_login.statusCode,' ', r_login.statusReason );
               SetTimeout(
                     procedure
                     begin
                       if assigned(r_login) then
                          r_login.resume;
                     end, 5000);
           end;
         end);
    r_login.resume;
  end;
  var
    i : integer;
begin
  try
      main;


    LoopHere;
    WriteLn('Loop exit');
    readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
