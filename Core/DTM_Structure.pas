unit DTM_Structure;

interface
   uses
    System.Classes,System.SysUtils,Types,Vcl.Graphics;

 const
  TDTMPointSize = 5*SizeOf(integer)+Sizeof(boolean);
 type
  TDTMPoint = class
   private
    Fx: Integer;
    FY: Integer;
    FColor: Integer;
    FTolerance: integer;
    FAreaSize: integer;
    FBp: boolean;
    public
     procedure Reset;
     constructor Create;
     procedure DrawToCanvas(Render: TCanvas;aColor,Width,Height: integer);
     property x: Integer read Fx write Fx;
     property y: Integer read FY write FY;
     property Color: Integer read FColor write FColor;
     property Tolerance: Integer read FTolerance write FTolerance;
     property AreaSize: integer read FAreaSize write FAreaSize;
     property Bp: boolean read FBp write FBp;
  end;

  TDTMPointList = class
  private
    FDTMPoints: TList;
    function GetCount: Integer;
    function GetDTMPoint(Index: Integer): TDTMPoint;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Assign(Src: TDTMPointList);
    procedure Add(aDTMPoint: TDTMPoint); overload;
    procedure Add(aDTMPoints: TDTMPointList); overload;
    procedure Delete(Index: Integer); overload;
    procedure Delete(aDTMPoint: TDTMPoint); overload;
    function IndexOf(aDTMPoint: TDTMPoint): Integer;

    property Count: Integer read GetCount;
    property DTMPoint[Index: Integer]: TDTMPoint read GetDTMPoint; default;
  end;

  TDTMS = class
    private
      FPoints : TDTMPointList;
      FLen    : integer;
      FDrawColor: integer;
      FName : string;
      FIndex : integer;
      FNormalized: boolean;
      function GetAsString: AnsiString;
      procedure SetAsString(const Value: AnsiString);
    public
      constructor Create;
      destructor Destroy;override;
      procedure Reset;
      procedure SetPointCount(Amount: integer);
      procedure Normalize;
      procedure DrawToCanvas(aCanvas: TCanvas;W,H: integer);

      property Points: TDTMPointList read FPoints;
      property DrawColor: integer read FDrawColor write FDrawColor;
      property Name: string read FName write FName;
      property Index: Integer read FIndex write FIndex;
      property Normalized: Boolean read FNormalized write FNormalized;
      property AsString: AnsiString read GetAsString write SetAsString;

  end;

  TDTMSList = class
  private
    FDTMSs: TList;
    function GetCount: Integer;
    function GeTDTMS(Index: Integer): TDTMS;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Add(aDTMS: TDTMS);
    procedure Assign(Src: TDTMSList);
    function IndexOf(aItem: TDTMS): Integer;
    procedure Delete(Index: Integer); overload;
    procedure Delete(aItem: TDTMS); overload;

    property Count: Integer read GetCount;
    property DTMS[Index: Integer]: TDTMS read GeTDTMS; default;
  end;

implementation
 uses
  DCPbase64,zlib,math;

 const
  ErrItemNotFound ='DTMPoint not found!';

{Helper functions}
function RotatePoint(const p: TPoint;const angle, mx, my: Extended): TPoint; inline;
begin
  Result.X := Round(mx + cos(angle) * (p.x - mx) - sin(angle) * (p.y - my));
  Result.Y := Round(my + sin(angle) * (p.x - mx) + cos(angle) * (p.y- my));
end;

function HexToInt(const HexNum: string): LongInt;inline;
begin
   Result:=StrToInt('$' + HexNum);
end;
{}

{ TDTMPoint }

constructor TDTMPoint.Create;
begin
 inherited;
 Reset;
end;

procedure TDTMPoint.DrawToCanvas(Render: TCanvas;AColor,Width,Height: integer);
var
  rx, ry, z, w, h: Integer;
begin
 z := Max(AreaSize shr 1, 1);
 w := Width;
 h := Height;
  for rx := -z to z do
    for ry := -z to z do
      if (x + rx >= 0) and (x + rx < w) and (y + ry >= 0) and (y + ry < h) then
          Render.Pixels[x + rx , y + ry ] := AColor;
     // render.Picture.Assign(bmpBuffer);
end;

procedure TDTMPoint.Reset;
begin
 x:=0;
 y:=0;
 Color:=0;
 Tolerance:=0;
 AreaSize:=0;
 BP:=false;
end;

constructor TDTMPointList.Create;
begin
  FDTMPoints := TList.Create;
end;

destructor TDTMPointList.Destroy;
begin
  Clear;
  FDTMPoints.Free;
  inherited;
end;

procedure TDTMPointList.Delete(Index: Integer);
begin
  if (Index < 0) or (Index >= Count) then
    raise Exception.Create(ErrItemNotFound);

  DTMPoint[Index].Free;
  FDTMPoints.Delete(Index);
end;

procedure TDTMPointList.Delete(aDTMPoint: TDTMPoint);
begin
  Delete(IndexOf(aDTMPoint));
end;

procedure TDTMPointList.Add(aDTMPoints: TDTMPointList);
var
  I: Integer;
begin
  for I := 0 to aDTMPoints.Count - 1 do
    Add(aDTMPoints[I]);
end;

procedure TDTMPointList.Add(aDTMPoint: TDTMPoint);
begin
  FDTMPoints.Add(aDTMPoint);
end;

procedure TDTMPointList.Assign(Src: TDTMPointList);
begin
  Clear;
  Add(Src);
end;

procedure TDTMPointList.Clear;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    DTMPoint[I].Free;
  FDTMPoints.Clear;
end;


function TDTMPointList.GetCount: Integer;
begin
  Result := FDTMPoints.Count;
end;

function TDTMPointList.GetDTMPoint(Index: Integer): TDTMPoint;
begin
  if (Index >= 0) and (Index < Count) then
    Result := TDTMPoint(FDTMPoints[Index])
  else
    Result := nil;
end;

function TDTMPointList.IndexOf(aDTMPoint: TDTMPoint): Integer;
begin
  Result := FDTMPoints.IndexOf(aDTMPoint);
end;

{ TDTMS }

constructor TDTMS.Create;
begin
 inherited;
 FPoints:=TDTMPointList.Create;
 Reset;
end;

destructor TDTMS.Destroy;
begin
  FPoints.Free;
  inherited;
end;

function TDTMS.GetAsString: AnsiString;
var
  i,len : integer;
  Ptr,Start : pbyte;
  Destlen : cardinal;
  s: string;
  BufferString: PChar;
  BufferLen: LongWord;
procedure WriteInteger(int : integer);
begin
  PLongInt(Ptr)^ := int;
  Inc(ptr,sizeof(Int));
end;
procedure WriteBool(bool : boolean);
begin;
  PBoolean(Ptr)^ := bool;
  inc(ptr,sizeof(bool));
end;

begin
  FLen:=FPoints.Count;
  result := '';
  try
   BufferLen:=524288;
   BufferString := StrAlloc(BufferLEn);
  if Points.Count < 1 then
    exit;
  len := Points.Count * TDTMPointSize + SizeOf(Integer);
  GetMem(Start,len);
  Ptr := Start;
  WriteInteger(FLen);
  for i := 0 to FLen-1 do
    WriteInteger(FPoints[i].x);
  for i := 0 to FLen-1 do
    WriteInteger(FPoints[i].y);
  for i := 0 to FLen-1 do
    WriteInteger(FPoints[i].Color);
  for i := 0 to FLen-1 do
    WriteInteger(FPoints[i].Tolerance);
  for i := 0 to FLen-1 do
    WriteInteger(FPoints[i].AreaSize);
  for i := 0 to FLen-1 do
    WriteBool(FPoints[i].bp);
  Destlen :=BufferLen;
  if compress(@BufferString[0],destlen,start,len) = Z_OK then
  begin
    setlength(result,Destlen + SizeOf(Integer));
    PInteger(@result[1])^ := len;
    Move(bufferstring[0],result[1 + sizeof(integer)],Destlen);
    Result := 'm' + Base64EncodeStr(result);
  end;
  finally
  Freemem(start,len);
  StrDispose(BufferString);
end;
end;

procedure TDTMS.Reset;
begin
  Name:='';
  Index:=0;
  DrawColor:=0;
  FLen:=0;
  Normalized:=false;
end;

procedure TDTMS.SetPointCount(Amount: integer);
var
 i: Integer;
begin
 FPoints.Clear;
 for I := 0 to Amount - 1 do
  begin
    FPoints.Add(TDTMPoint.Create);
  end;
end;

procedure TDTMS.SetAsString(const Value: AnsiString);
var
  Source : AnsiString;
  DestLen : longword;
  i,ii,c,size : integer;
  Ptr : pbyte;
  Res: Boolean;
  BufferString: PChar;
  BufferLen: LongWord;
  function ReadInteger : integer;
  begin
    Result := PInteger(ptr)^;
    inc(ptr,sizeof(integer));
  end;
  function ReadBoolean : boolean;
  begin
    result := PBoolean(ptr)^;
    inc(ptr,sizeof(boolean));
  end;

begin
  BufferLen:=524288;
  BufferString := StrAlloc(BufferLen);
  Res := false;
  ii := Length(Value);
  if (ii = 0) then
    exit;
  if Value[1] = 'm' then
  begin
    if ii < 9 then
      raise Exception.CreateFMT('Invalid DTM-String passed to StringToDTM: %s',[Value]);
    Source := Base64DecodeStr(copy(Value,2,ii-1));
    Move(Source[1], DestLen,4);
    if i < 1 then
      raise Exception.CreateFMT('Invalid DTM-String passed to StringToDTM: %s',[Value]);
    DestLen := BufferLen;
    ptr := @Source[1 + sizeof(longint)];
    if uncompress(Pbyte(BufferString),DestLen,PByte(ptr),length(source)-sizeof(integer)) = Z_OK then
    begin
      ptr := @BufferString[0];
      ii := ReadInteger;
      if (ii * TDTMPointSize) <> (Destlen - SizeOf(integer)) then
        raise Exception.CreateFMT('Invalid DTM-String passed to StringToDTM: %s',[Value]);
      SetPointCount(ii);
     // DPoints := Self.FPoints;
      for i := 0 to ii-1 do
        FPoints[i].x := ReadInteger;
      for i := 0 to ii-1 do
        FPoints[i].y := ReadInteger;
      for i := 0 to ii-1 do
        FPoints[i].Color := ReadInteger;
      for i := 0 to ii-1 do
        FPoints[i].Tolerance := ReadInteger;
      for i := 0 to ii-1 do
        FPoints[i].AreaSize := ReadInteger;
      for i := 0 to ii-1 do
        FPoints[i].bp := ReadBoolean;
      Res := true;
    end;
  end else
  begin
    if (ii mod 2 <> 0) then
      exit;
    ii := ii div 2;
    SetLength(Source,ii);
    for i := 1 to ii do
      Source[i] := AnsiChar(HexToInt(Value[i * 2 - 1] + Value[i * 2]));
    DestLen := BufferLen;
    if uncompress(Pbyte(Bufferstring),Destlen,pbyte(Source), ii) = Z_OK then
    begin;
      if (Destlen mod 36) > 0 then
        raise Exception.CreateFMT('Invalid DTM-String passed to StringToDTM: %s',[Value]);
      DestLen := DestLen div 36;
      //Self.Count:= DestLen;
      SetPointCount(DestLen);
     // DPoints := Self.FPoints;
      ptr := @bufferstring[0];
      for i := 0 to DestLen - 1 do
      begin;
        fPoints[i].x :=PInteger(PChar(ptr) + 1)^;
        fPoints[i].y := PInteger(PChar(ptr) + 5)^;
        fPoints[i].AreaSize := PInteger(PChar(ptr) + 12)^;
  //    DPoints.ash[i] := PInteger(@b^[c+16])^;
        fPoints[i].Color := PInteger(PChar(ptr) + 20)^;
        fPoints[i].Tolerance := PInteger(PChar(ptr) + 24)^;
        fPoints[i].bp := False;
        inc(Pinteger(ptr),36);
      end;
      Res := true;
    end;
  end;
  if res then
    Normalize;
   StrDispose(BufferString);
end;

procedure TDTMS.Normalize;
var
   i:integer;
   m: TPoint;
begin
  Normalized:=true;
  if (self = nil) or (FPoints.count < 1) or ((FPoints[0].x = 0) and (FPoints[0].y = 0)) then  //Already normalized
    exit;
  for i := 1 to FPoints.Count - 1 do
  begin
    Self.Points[i].x := Self.Points[i].x - Self.Points[0].x;
    Self.Points[i].y := Self.Points[i].y - Self.Points[0].y;
  end;
  Self.Points[0].x := 0;
  Self.Points[0].y := 0;
  M:=Point(0,0);
  for I := FPoints.Count -1 downto 0 do
      m := Point(Min(Points[i].x, m.x), Min(Points[i].y, m.y));
  //Self.Points[0].x := Self.Points[0].x - m.x;
  //Self.Points[0].y := Self.Points[0].y - m.y;
  for I := FPoints.Count -1 downto 0 do
  begin
    Self.Points[i].x := Self.Points[i].x - m.x;
    Self.Points[i].y := Self.Points[i].y - m.y;
  end;
end;

procedure TDTMS.DrawToCanvas(aCanvas: TCanvas;W,H: integer);
var
 Pt: TDTMPoint;
 i: integer;
begin
  if Points.Count > 0 then
   begin
   aCanvas.Pen.Color:=DrawColor;
     for i:=0  to Points.count - 1 do
       begin
          pt:=Points[i];
          //DrawDTMPoint(pt,DrawingColor);
          Pt.DrawToCanvas(aCanvas,DrawColor,w,h);
          aCanvas.MoveTo(Round(Max(Min(Points[0].x, W - 1), 0)), Round(Max(Min(Points[0].y, H - 1), 0)));
          aCanvas.LineTo(Round(Max(Min(pt.x, W - 1), 0)), Round(Max(Min(pt.y, H - 1), 0)));
       end;
   end;
end;

constructor TDTMSList.Create;
begin
  FDTMSs := TList.Create;
end;

procedure TDTMSList.Delete(Index: Integer);
begin
  if (Index < 0) or (Index >= Count) then
    raise Exception.Create(ErrItemNotFound);

  TDTMS(FDTMSs[Index]).Free;
  FDTMSs.Delete(Index);
end;

procedure TDTMSList.Delete(aItem: TDTMS);
begin
  Delete(IndexOf(aItem));
end;

destructor TDTMSList.Destroy;
begin
  Clear;
  FDTMSs.Free;
  inherited;
end;

procedure TDTMSList.Add(aDTMS: TDTMS);
begin
  FDTMSs.Add(aDTMS);
end;

procedure TDTMSList.Assign(Src: TDTMSList);
var
  I: Integer;
begin
  Clear;
  for I := 0 to Src.Count - 1 do
    Add(Src[I]);
end;

procedure TDTMSList.Clear;
var
  I: Integer;
begin
  for I := 0 to FDTMSs.Count - 1 do
    DTMS[I].Free;
  FDTMSs.Clear;
end;


function TDTMSList.GetCount: Integer;
begin
  result:=FDTMSs.Count;
end;

function TDTMSList.GeTDTMS(Index: Integer): TDTMS;
begin
  if (Index >= 0) and (Index < Count) then
    Result := TDTMS(FDTMSs[Index])
  else
    Result := nil;
end;

function TDTMSList.IndexOf(aItem: TDTMS): Integer;
begin
 Result := FDTMSs.IndexOf(aItem);
end;


end.

