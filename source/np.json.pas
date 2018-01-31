unit np.json;

interface
  uses sysUtils, Generics.Collections;

  type
    TJSONType = (json_null, json_int, json_text, json_object, json_array, json_boolean);
    TJSONPair = class;
    TJSONArray = TObjectList<TJSONPair>;
    TJSONObject = TDictionary<String,TJSONPair>;
    PSearchControl = ^TSearchControl;
    TSearchControl = record
       level : Cardinal;
       state : (cNormal,cStopLevel,cStopAll);
    end;
    TJSONTypes = set of TJSONType;
    TJSONPair = class
    private
      FArray  : TJSONArray;
      FObject : TJSONObject;
      function GetAsBoolean: Boolean;
      function GetAsObject(const Key: String): TJSONPair;
      procedure OnObjectNotify(Sender: TObject; const Item: TJSONPair; Action: TCollectionNotification);
      procedure OnArrayNotify(Sender: TObject; const Item: TJSONPair; Action: TCollectionNotification);
      procedure SetAsBoolean(const Value: Boolean);
      procedure SetAsObject(const Key: String; const Value: TJSONPair);
      function GetAsInteger: int64;
      procedure SetAsInteger(const Value: int64);
      function GetAsString: String;
      function InternalToString(sb : TStringBuilder ) : integer;
      procedure SetAsString(const Value: String);
      function GetAsArray(i: integer): TJSONPair;
      procedure SetAsArray(i: integer; const Value: TJSONPair);
    public
      name   : string;
      typeIs : TJSONType;
      IsString  : String;
      IsInteger : int64;
      owner  : TJSONPair;
      constructor Create(const Value: string); overload;
      destructor Destroy; override;
      procedure Clear;
      function count : integer;
      procedure Increment;
      function Parse(const JSON : string;var I : integer) : TJSONPair; overload;
      function Parse(const JSON : string): TJSONPair; overload;
      function find(const s : array of string; out AResult: TJSONPair) : Boolean;
      procedure forAll( proc : TProc<TJSONPair,PSearchControl>; control: PSearchControl );
      function IsNull : Boolean;
      function Clone : TJSONPair;
      procedure assign( pair : TJSONPair; overrideName : Boolean = true; aDelete: Boolean = false);
      function IsEmpty : Boolean;
      class function EncodeJSONText(const s: string): string; static;
      class function DecodeJSONText(const JSON : string): string; overload; static;
      class function DecodeJSONText(const JSON : string; var Index: Integer): string; overload; static;

      function ToString : string; override;
      function IsArray  : TJSONArray;
      function IsObject : TJSONObject;
//      function save(out v : TJSONPair) : TJSONPair;
      property AsInteger: int64 read GetAsInteger write SetAsInteger;
      property AsBoolean: Boolean read GetAsBoolean write SetAsBoolean;
      property AsObject[const Key: String]: TJSONPair read GetAsObject write
          SetAsObject; default;
      property AsArray[i : integer] : TJSONPair read GetAsArray write SetAsArray;
      property AsString: String read GetAsString write SetAsString;
    end;

  const
    ValueTypes : TJSONTypes = [json_null, json_boolean, json_int, json_text];


implementation

constructor TJSONPair.Create(const Value: string);
begin
  Parse(Value);
end;

{ TJSONPair }

//constructor TJSONPair.Create( Parent : TJSONPair; theType : TJSONType);
//begin
//  typeIs
//end;

function TJSONPair.Clone: TJSONPair;
var
  I : Integer;
  enum : TJSONPair;
begin
  result := TJSONPair.Create;
  result.name := name;
  case typeIs of
    json_int:
         result.AsInteger := AsInteger;
    json_text:
         result.AsString := AsString;
    json_boolean:
         result.AsBoolean := AsBoolean;
    json_array:
         begin
            for i := 0 to Count-1 do
              result.AsArray[i] := AsArray[i].Clone;
         end;
    json_object:
         begin
            for enum in IsArray do
              result.AsObject[enum.name] := enum.Clone;
         end;
  end;
end;

function TJSONPair.IsEmpty : Boolean;
var
 child : TJSONPair;
begin
  case typeIs of
     json_object,
     json_array:
        begin
           for child in IsArray do
             if not child.IsEmpty then
                 exit(false);
           exit(true);
        end;
     json_null:
        exit(true);
     else
        exit(false);
  end;

end;

function TJSONPair.count: integer;
begin
  if assigned(FArray) then
     result := FArray.Count
  else
     result := 0;
end;

destructor TJSONPair.Destroy;
begin
  if assigned(owner) and assigned(owner.FArray) then
    owner.FArray.Extract(self);
  FreeAndNil(FObject);
  FreeAndNil(FArray);
  inherited;
end;

procedure TJSONPair.assign(pair: TJSONPair; overrideName : Boolean; Adelete : Boolean);
var
  item, cloneItem : TJSONPair;
begin
  Clear;
  if pair = nil then
    exit;
  if overrideName then
    name := pair.name;
  typeIs := pair.typeIs;
  IsString := pair.IsString;
  IsInteger := pair.IsInteger;
  for item in pair.IsArray do
  begin
    cloneItem := item.Clone;
    cloneItem.owner := self;
    IsArray.Add(cloneItem);
    if typeIs = json_object then
      IsObject.AddOrSetValue(cloneItem.name,cloneItem);
  end;
  if Adelete then
    pair.Free;
end;


procedure TJSONPair.Clear;
begin
  IsString  := '';
  IsInteger := 0;
  typeIs := json_null;
  if assigned(FObject) then
     FObject.Clear;
  if assigned(FArray) then
     FArray.Clear;
end;

class function TJSONPair.DecodeJSONText(const JSON : string; var Index: Integer):
    string;
var
  L : Integer;
begin
  if Index < 1 then
     Index := 1;

  Result := '';
  L := Length(JSON);
  repeat
    While (Index<=L) and (JSON[Index] <> '"') DO
      Inc(Index);
    Inc(Index); //skip left "
  until (Index > L) or (Index=2) or (JSON[Index-2] <> '\');
  While (Index<=L) DO
  BEGIN
    case JSON[Index] of
       '"':
         begin
           Inc(Index); //Skip rigth "
           break;
         end;
       #0..#$1f:
          INC(Index);//ignore
       '\':
           begin
             if Index+1 <= L then
             begin
                case JSON[Index+1] of
                  '"','\','/' :
                       begin
                         Result := Result + JSON[Index+1];
                         INC(Index,2);
                       end;
                  'u':
                      begin
                          Result := Result + char(word(
                             StrToIntDef('$'+copy(JSON,Index+2,4),ord('?'))
                                       ));
                         INC(Index,6);
                      end;
                   'b':
                      begin
                         Result := Result + #8;
                         INC(Index,2);
                      end;
                   'f':
                      begin
                         Result := Result + #12;
                         INC(Index,2);
                      end;
                   'n':
                      begin
                        Result := Result + #10;
                        INC(Index,2);
                      end;
                   'r':
                      begin
                        Result := Result + #13;
                        INC(Index,2);
                      end;
                   't':
                      begin
                        Result := Result + #9;
                        INC(Index,2);
                      end;
                   else
                      INC(Index,2); //Ignore
                end;
             end;
           end;
       else
       begin
          Result := Result +  JSON[Index];
          INC(Index);
       end;
    end;
  END;
end;

class function TJSONPair.DecodeJSONText(const JSON : string): string;
var
  i : integer;
begin
  i := 1;
  Result := DecodeJSONText(JSON,i);
end;

function TJSONPair.GetAsArray(i: integer): TJSONPair;
begin
  if i < 0 then i := 0;

  case typeIs of
  json_boolean,
  json_int,
  json_text,
  json_null:
      begin
        result := TJSONPair.Create
        ('');
        asArray[0] := result;
      end;
  json_array,json_object:
      begin
        if i < IsArray.Count then
           exit(isArray[i])
        else
        begin
          result := TJSONPair.Create;
          asArray[i] := result
        end;
      end;
    else
      assert(false);
  end;

end;

function TJSONPair.GetAsBoolean: Boolean;
begin
  case typeIs of
  json_boolean,
  json_int:
      exit(IsInteger <> 0);
  json_text:
      exit( IsString = 'true');
  json_null:
      exit(false);
  else
    result := (Count > 0);
  end;
end;

function TJSONPair.GetAsInteger: int64;
begin
  case typeIs of
     json_null:  exit(0);
     json_int:   exit(IsInteger);
     json_text:
          begin
             if not TryStrToInt64(IsString, result) then
               exit(0);
          end;
     else
          begin
             if Count > 0 then
                 exit(FArray[0].AsInteger)
             else
                 exit(0);
          end;
  end;
end;

function TJSONPair.GetAsObject(const Key: String): TJSONPair;
begin
  if (typeIs <> json_object) or not IsObject.TryGetValue(Key,result) then
  begin
     result := TJSONPair.Create;
     asObject[Key] := result;
  end;
end;

function TJSONPair.GetAsString: String;
begin
  case typeIs of
//     json_null:
//           exit('');
     json_boolean:
          if AsBoolean then
            Exit('true')
          else
            exit('false');
      json_int:
           exit(IntToStr(IsInteger));
      json_text:
           exit(IsString);
      else
//      else
//        if (Count > 0) then
//           exit(IsArray[0].AsString)
//        else
           exit('');
  end;
end;

procedure TJSONPair.Increment;
begin
   AsInteger := AsInteger + 1;
end;

function TJSONPair.IsArray: TJSONArray;
begin
  if not Assigned(FArray) then
  begin
     FArray := TJSONArray.Create;
     FArray.OnNotify := OnArrayNotify;
  end;
  result := FArray;
end;

function TJSONPair.IsObject: TJSONObject;
begin
  if not Assigned(FObject) then
  begin
    FObject := TJSONObject.Create;
    FObject.OnValueNotify := OnObjectNotify;
  end;
  result := FObject;
end;

function TJSONPair.IsNull: Boolean;
begin
  result := typeIs = json_null;
end;

//function TJSONPair.save(out v: TJSONPair): TJSONPair;
//begin
//   result := self;
//   v := self;
//end;

procedure TJSONPair.OnObjectNotify(Sender: TObject; const Item: TJSONPair;
  Action: TCollectionNotification);
begin
   if (Action = cnRemoved) and Assigned(FArray) then
      FArray.Remove(Item)
end;

function TJSONPair.Parse(const JSON: string; var I: integer) : TJSONPair;
VAR
  L : INTEGER;
  J:INTEGER;
  INT: INTEGER;
  K,V: String;
  child : TJSONPair;
begin
  result := self;
  if I < 1 then I := 1;
  Clear;
  L := Length(JSON);
  While I<=L DO
  BEGIN
    CASE JSON[I] OF
      '{':
         begin
            repeat
              K := DecodeJSONText(JSON,I);
              While (I<=L) and (JSON[I] <> ':') DO INC(I);
              INC(I);
              AsObject[K] := TJSONPair.Create.Parse(JSON,I);
              While (I<=L) and not (JSON[I] in [',','}']) DO INC(I);
              INC(I);
            until not((I<=L) and (I>1) and (JSON[I-1]=','));
         end;
      '[':
         begin
           J := 0;
           INC(I);
           repeat
             AsArray[count] := TJSONPair.Create.Parse(JSON,I); //TODO: fix empty array : "array" : [] =>  "array.count = 0"
             While (I<=L) and not (JSON[I] in [',',']']) DO INC(I);
             INC(I);
           until not((I<=L) and (I>1) and (JSON[I-1]=','));
           {if (count = 1) and AsArray[0].IsNull then
               AsArray[0].Free;}

         end;
      '"':
         begin
            //sb.Append('<').Append(path).Append('>').Append(V).Append('</').Append(path).Append('>');
            AsString := DecodeJSONText(JSON,I);
         end;
        #0..#$20:
           begin
            INC(I);
            continue;
           end;
       else
         begin
           V := '';
           //unknown reserver world like "true" "false" "null"... try sync
           While (I<=L) and not (JSON[I] in [',',']','}']) DO
           begin
             if (word(JSON[I]) > $20) and ( word(JSON[I]) < $80) then
               V :=  V + JSON[I];
             INC(I);
           end;
           if  V <> '' then
           begin
             if sameText(v,'null') then
             else
             if sameText(v,'true') then
             begin
                AsBoolean := true;
             end
             else
             if sameText(v,'false') then
             begin
                asBoolean := false;
             end
             else
             begin
               if TryStrToInt64(V, IsInteger) then
                 result.typeIs := json_int
               else
               begin
                 result.typeIs := json_text;
                 result.IsString := V;
               end;
             end;
           end;
         end;
    END;
    break;
  END;
end;

procedure TJSONPair.OnArrayNotify(Sender: TObject; const Item: TJSONPair;
  Action: TCollectionNotification);
begin
  if (Action in [cnRemoved,cnExtracted]) and assigned(FObject) then
  begin
    FObject.ExtractPair(Item.name);
  end;
end;

function TJSONPair.Parse(const JSON : string): TJSONPair;
var
  i : integer;
begin
  i := 1;
  Result := Parse(JSON,I);
end;

procedure TJSONPair.SetAsArray(i: integer; const Value: TJSONPair);
var
  index : Integer;
begin
  if value = nil then
  begin
    if Assigned(FArray) then
      FArray.Delete(i);
    exit;
  end;
  if i < 0 then
   i := count;
  if Assigned(Value.owner) and (Value.owner <> self) and assigned(Value.owner.FArray) then
  begin
    value.Owner.FArray.Extract(Value);
  end;
  if (typeIs <> json_array) and (typeIs <> json_object) then
  begin
    Clear;
    typeIs := json_array;
  end;
  value.owner := self;
  value.name := IntToStr(i);
  while IsArray.Count < i do
    IsArray.add(TJSONPair.Create);
  if I = IsArray.Count then
    IsArray.Add(Value)
  else
    IsArray[i] := Value;
end;

procedure TJSONPair.SetAsBoolean(const Value: Boolean);
begin
  if typeIs <> json_boolean then
  begin
    Clear;
    typeIs := json_boolean
  end;
  IsInteger := ord(Value);
end;

procedure TJSONPair.SetAsInteger(const Value: int64);
begin
  if typeIs <> json_int then
  begin
    Clear;
    typeIs := json_int
  end;
  IsInteger := Value;
end;

procedure TJSONPair.SetAsObject(const Key: String; const Value: TJSONPair);
var
  copyItems : TJSONPair;
begin
  if Value = nil then
  begin
    if assigned(FObject) then
      FObject.Remove(Key);
    exit;
  end;

  if typeIs = json_array then
  begin
    //convert to object
    for copyItems in IsArray do
     IsObject.AddOrSetValue(copyItems.name,copyItems);
    typeIs := json_object;
  end;

  if typeIs <> json_object then
  begin
    Clear;
    typeIs := json_object;
  end;
  if assigned(Value.owner) and (Value.owner <> self) and assigned( Value.owner.FArray) then
     Value.owner.FArray.Extract(Value);
  Value.name := Key;
  Value.owner := self;
  IsObject.AddOrSetValue(Key,Value);
  IsArray.Add(value);
end;


procedure TJSONPair.SetAsString(const Value: String);
begin
  if typeIs <> json_text then
  begin
    Clear;
    typeIs := json_text;
  end;
  IsString := value;
end;

function TJSONPair.ToString: string;
var
  sb : TStringBuilder;
begin
  sb := TStringBuilder.Create;
  try
     InternalToString(sb);
     result := sb.ToString;
  finally
    sb.Free;
  end;
end;

function TJSONPair.InternalToString(sb : TStringBuilder ) : integer;
var
  item : TJSONPair;
  sv1,sv2 : integer;
begin
  result := 0;
  sv2 := sb.Length;
  case typeIs of
    json_boolean:
          begin
            if AsBoolean then
               sb.Append('true')
            else
               sb.Append('false');
            inc(result);
          end;
    json_int:
          begin
             sb.Append(AsInteger);
             inc(result);
          end;
    json_text:
          begin
            sb.Append('"').Append(EncodeJSONText(AsString)).Append('"');
            inc(result);
          end;
    json_array:
           begin
             sb.Append('[');
                for item in IsArray do
                begin
                   if not item.IsNull then
                   begin
                     sv1 := sb.Length;
                     if result > 0 then
                         sb.Append(',');
                     if item.InternalToString(sb) = 0 then
                       sb.Length := sv1
                     else
                       inc(result);
                   end;
                end;
             sb.Append(']');
           end;
    json_object:
           begin
             sb.Append('{');
                for item in IsArray do
                begin
                   if not item.IsNull then
                   begin
                     sv1 := sb.Length;
                     if result > 0 then
                       sb.Append(',');
                     sb.Append('"').Append(EncodeJSONText(item.name)).Append('":');
                     if item.InternalToString(sb) = 0 then
                       sb.Length := sv1
                     else
                       inc(result);
                   end;
                end;
             sb.Append('}');
           end;
  end;
  if result = 0 then
    sb.Length := sv2;
end;

class function TJSONPair.EncodeJSONText(const s: string): string;
var
  sb : TStringBuilder;
  ch : char;
begin
  sb := TStringBuilder.Create;
  try
    for ch in s do
    begin
      case ch of
         //#0..#7:;
         #8:  sb.Append('\b');
         #9:  sb.Append('\t');
         #10: sb.Append('\n');
         //#11:;
         #12: sb.Append('\f');
         #13: sb.Append('\r');
         //#14..#$1f:;
         '"': sb.Append('\"');
         '\': sb.Append('\\');
         '/': sb.Append('\/');
         #$80..#$ffff:
              sb.AppendFormat('\u%.4x',[word(ch)]);
         else
           begin
              case ch of
                #$20..#$7f: sb.Append(ch);
              end;
           end;
      end;
    end;
    result := sb.ToString;
  finally
    sb.Free;
  end;

end;


function TJSONPair.find(const s: array of string;
  out AResult: TJSONPair): Boolean;
var
  tmp: TJSONPair;
  i : integer;
  index: int64;
begin
  Aresult := nil;
  tmp := self;
  for i := low(s) to High(s) do
  begin
    case tmp.typeIs of
     json_array :
         begin
           if TryStrToInt64(s[i],index) and (tmp.FArray.Count > index) and (index >= 0) then
           begin
              tmp := tmp.FArray[index];
              continue;
           end;
         end;
     json_object:
       if  tmp.FObject.TryGetValue(s[i],tmp) then
          continue;
     end;
     exit(False);
  end;
  Aresult := tmp;
  Exit(True);
end;

procedure TJSONPair.forAll(proc: TProc<TJSONPair, PSearchControl>; control : PSearchControl);
var
  item : TJSONPair;
  newControl : TSearchControl;
begin
  if not assigned(proc) then
    exit;
   if self = nil then
      exit;
   if IsNull then
     exit;
  if control = nil then
  begin
    newControl.level := 0;
    control := @newControl;
    control.state := cNormal;
  end
  else
  if control.state <> cNormal then
    exit;
  proc(self, control);
  if control.state <> cNormal then
    exit;
  case typeis of
    json_object,
    json_array:
      begin
        inc(control.level);
        for item in IsArray do
        begin
          item.forAll(proc,control);
          case control.state of
            cStopLevel:
                begin
                  control.state := cNormal;
                  break;
                end;
            cStopAll:
                exit;
          end;
        end;
        dec(control.level);
      end;
  end;
end;

end.
