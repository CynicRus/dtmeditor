unit DTM_Structure;

interface

uses
  System.Classes, System.SysUtils, Types, Vcl.Graphics,DTM_Bitmaps;

const
  TDTMPointSize = 5 * SizeOf(integer) + SizeOf(boolean);

type
  TDTMPoint = class
  private
    Fx: integer;
    FY: integer;
    FColor: integer;
    FTolerance: integer;
    FAreaSize: integer;
    FBp: boolean;
  public
    procedure Reset;
    constructor Create;
    procedure Assign(Src: TDTMPoint);
    procedure DrawToCanvas(Render: TCanvas; aColor, Width, Height: integer);
    property x: integer read Fx write Fx;
    property y: integer read FY write FY;
    property Color: integer read FColor write FColor;
    property Tolerance: integer read FTolerance write FTolerance;
    property AreaSize: integer read FAreaSize write FAreaSize;
    property Bp: boolean read FBp write FBp;
  end;

  TDTMPointList = class
  private
    FDTMPoints: TList;
    function GetCount: integer;
    function GetDTMPoint(Index: integer): TDTMPoint;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Assign(Src: TDTMPointList);
    procedure Add(aDTMPoint: TDTMPoint); overload;
    procedure Add(aDTMPoints: TDTMPointList); overload;
    procedure Delete(Index: integer); overload;
    procedure Delete(aDTMPoint: TDTMPoint); overload;
    function IndexOf(aDTMPoint: TDTMPoint): integer;

    property Count: integer read GetCount;
    property DTMPoint[Index: integer]: TDTMPoint read GetDTMPoint; default;
  end;

  TDTMS = class
  private
    FPoints: TDTMPointList;
    FLen: integer;
    FDrawColor: integer;
    FName: string;
    FIndex: integer;
    FNormalized: boolean;
    function GetAsString: AnsiString;
    procedure SetAsString(const Value: AnsiString);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Reset;
    procedure SetPointCount(Amount: integer);
    procedure Normalize;
    procedure DrawToCanvas(aCanvas: TCanvas; W, H: integer);
    procedure SaveToFile(FileName: string);

    property Points: TDTMPointList read FPoints;
    property DrawColor: integer read FDrawColor write FDrawColor;
    property Name: string read FName write FName;
    property Index: integer read FIndex write FIndex;
    property Normalized: boolean read FNormalized write FNormalized;
    property AsString: AnsiString read GetAsString write SetAsString;

  end;

  TDTMSList = class
  private
    FDTMSs: TList;
    function GetCount: integer;
    function GeTDTMS(Index: integer): TDTMS;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Add(aDTMS: TDTMS);
    procedure Assign(Src: TDTMSList);
    function IndexOf(aItem: TDTMS): integer;
    procedure Delete(Index: integer); overload;
    procedure Delete(aItem: TDTMS); overload;

    property Count: integer read GetCount;
    property DTMS[Index: integer]: TDTMS read GeTDTMS; default;
  end;
procedure DrawAntialisedLine(Canvas: TCanvas; const AX1, AY1, AX2, AY2: real;
  const LineColor: TColor);overload

procedure DrawAntialisedLine(Bitmap: TDTMBitmap; const AX1, AY1, AX2, AY2: real;
  const LineColor: TColor);overload

implementation

uses
  DCPbase64, zlib, math, Windows;

const
  ErrItemNotFound = 'DTMPoint not found!';

  { Helper functions }
procedure DrawAntialisedLine(Canvas: TCanvas; const AX1, AY1, AX2, AY2: real;
  const LineColor: TColor); overload;

var
  swapped: boolean;

  procedure plot(const x, y, c: real);
  var
    resclr: TColor;
  begin
    if swapped then
      resclr := Canvas.Pixels[Round(y), Round(x)]
    else
      resclr := Canvas.Pixels[Round(x), Round(y)];
    resclr := RGB(Round(GetRValue(resclr) * (1 - c) + GetRValue(LineColor) * c),
      Round(GetGValue(resclr) * (1 - c) + GetGValue(LineColor) * c),
      Round(GetBValue(resclr) * (1 - c) + GetBValue(LineColor) * c));
    if swapped then
      Canvas.Pixels[Round(y), Round(x)] := resclr
    else
      Canvas.Pixels[Round(x), Round(y)] := resclr;
  end;

  function rfrac(const x: real): real; inline;
  begin
    rfrac := 1 - frac(x);
  end;

  procedure swap(var a, b: real);
  var
    tmp: real;
  begin
    tmp := a;
    a := b;
    b := tmp;
  end;

var
  x1, x2, y1, y2, dx, dy, gradient, xend, yend, xgap, xpxl1, ypxl1, xpxl2,
    ypxl2, intery: real;
  x: integer;

begin

  x1 := AX1;
  x2 := AX2;
  y1 := AY1;
  y2 := AY2;

  dx := x2 - x1;
  dy := y2 - y1;
  swapped := abs(dx) < abs(dy);
  if swapped then
  begin
    swap(x1, y1);
    swap(x2, y2);
    swap(dx, dy);
  end;
  if x2 < x1 then
  begin
    swap(x1, x2);
    swap(y1, y2);
  end;

  gradient := dy / dx;

  xend := Round(x1);
  yend := y1 + gradient * (xend - x1);
  xgap := rfrac(x1 + 0.5);
  xpxl1 := xend;
  ypxl1 := floor(yend);
  plot(xpxl1, ypxl1, rfrac(yend) * xgap);
  plot(xpxl1, ypxl1 + 1, frac(yend) * xgap);
  intery := yend + gradient;

  xend := Round(x2);
  yend := y2 + gradient * (xend - x2);
  xgap := frac(x2 + 0.5);
  xpxl2 := xend;
  ypxl2 := floor(yend);
  plot(xpxl2, ypxl2, rfrac(yend) * xgap);
  plot(xpxl2, ypxl2 + 1, frac(yend) * xgap);

  for x := Round(xpxl1) + 1 to Round(xpxl2) - 1 do
  begin
    plot(x, floor(intery), rfrac(intery));
    plot(x, floor(intery) + 1, frac(intery));
    intery := intery + gradient;
  end;

end;

procedure DrawAntialisedLine(Bitmap: TDTMBitmap; const AX1, AY1, AX2, AY2: real;
  const LineColor: TColor); overload;

var
  swapped: boolean;

  procedure plot(const x, y, c: real);
  var
    resclr: TColor;
  begin
    if swapped then
      resclr := Bitmap.FastGetPixel(Round(y), Round(x))
    else
      resclr := Bitmap.FastGetPixel(Round(x), Round(y));
    resclr := RGB(Round(GetRValue(resclr) * (1 - c) + GetRValue(LineColor) * c),
      Round(GetGValue(resclr) * (1 - c) + GetGValue(LineColor) * c),
      Round(GetBValue(resclr) * (1 - c) + GetBValue(LineColor) * c));
    if swapped then
      Bitmap.FastSetColor(Round(y), Round(x),resclr)
    else
      Bitmap.FastSetColor(Round(x), Round(y),resclr);
  end;

  function rfrac(const x: real): real; inline;
  begin
    rfrac := 1 - frac(x);
  end;

  procedure swap(var a, b: real);
  var
    tmp: real;
  begin
    tmp := a;
    a := b;
    b := tmp;
  end;

var
  x1, x2, y1, y2, dx, dy, gradient, xend, yend, xgap, xpxl1, ypxl1, xpxl2,
    ypxl2, intery: real;
  x: integer;

begin

  x1 := AX1;
  x2 := AX2;
  y1 := AY1;
  y2 := AY2;

  dx := x2 - x1;
  dy := y2 - y1;
  swapped := abs(dx) < abs(dy);
  if swapped then
  begin
    swap(x1, y1);
    swap(x2, y2);
    swap(dx, dy);
  end;
  if x2 < x1 then
  begin
    swap(x1, x2);
    swap(y1, y2);
  end;

  gradient := dy / dx;

  xend := Round(x1);
  yend := y1 + gradient * (xend - x1);
  xgap := rfrac(x1 + 0.5);
  xpxl1 := xend;
  ypxl1 := floor(yend);
  plot(xpxl1, ypxl1, rfrac(yend) * xgap);
  plot(xpxl1, ypxl1 + 1, frac(yend) * xgap);
  intery := yend + gradient;

  xend := Round(x2);
  yend := y2 + gradient * (xend - x2);
  xgap := frac(x2 + 0.5);
  xpxl2 := xend;
  ypxl2 := floor(yend);
  plot(xpxl2, ypxl2, rfrac(yend) * xgap);
  plot(xpxl2, ypxl2 + 1, frac(yend) * xgap);

  for x := Round(xpxl1) + 1 to Round(xpxl2) - 1 do
  begin
    plot(x, floor(intery), rfrac(intery));
    plot(x, floor(intery) + 1, frac(intery));
    intery := intery + gradient;
  end;

end;

function RotatePoint(const p: TPoint; const angle, mx, my: Extended)
  : TPoint; inline;
begin
  Result.x := Round(mx + cos(angle) * (p.x - mx) - sin(angle) * (p.y - my));
  Result.y := Round(my + sin(angle) * (p.x - mx) + cos(angle) * (p.y - my));
end;

function HexToInt(const HexNum: string): LongInt; inline;
begin
  Result := StrToInt('$' + HexNum);
end;
{ }

{ TDTMPoint }

procedure TDTMPoint.Assign(Src: TDTMPoint);
begin
  x := Src.x;
  y := Src.y;
  Color := Src.Color;
  Tolerance := Src.Tolerance;
  AreaSize := Src.AreaSize;
  Bp := Src.Bp;
end;

constructor TDTMPoint.Create;
begin
  inherited;
  Reset;
end;

procedure TDTMPoint.DrawToCanvas(Render: TCanvas;
  aColor, Width, Height: integer);
var
  rx, ry, z, W, H: integer;
begin
  z := Max(AreaSize shr 1, 1);
  W := Width;
  H := Height;
  for rx := -z to z do
    for ry := -z to z do
      if (x + rx >= 0) and (x + rx < W) and (y + ry >= 0) and (y + ry < H) then
        Render.Pixels[x + rx, y + ry] := aColor;
  // render.Picture.Assign(bmpBuffer);
end;

procedure TDTMPoint.Reset;
begin
  x := 0;
  y := 0;
  Color := 0;
  Tolerance := 0;
  AreaSize := 0;
  Bp := false;
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

procedure TDTMPointList.Delete(Index: integer);
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
  I: integer;
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
  I: integer;
begin
  for I := 0 to Count - 1 do
    TDTMPoint(FDTMPoints[I]).Free;
  FDTMPoints.Clear;
end;

function TDTMPointList.GetCount: integer;
begin
  Result := FDTMPoints.Count;
end;

function TDTMPointList.GetDTMPoint(Index: integer): TDTMPoint;
begin
  if (Index >= 0) and (Index < Count) then
    Result := TDTMPoint(FDTMPoints[Index])
  else
    Result := nil;
end;

function TDTMPointList.IndexOf(aDTMPoint: TDTMPoint): integer;
begin
  Result := FDTMPoints.IndexOf(aDTMPoint);
end;

{ TDTMS }

constructor TDTMS.Create;
begin
  inherited;
  FPoints := TDTMPointList.Create;
  Reset;
end;

destructor TDTMS.Destroy;
begin
  FPoints.Free;
  inherited;
end;

function TDTMS.GetAsString: AnsiString;
var
  I, len: integer;
  Ptr, Start: pbyte;
  Destlen: cardinal;
  s: string;
  BufferString: PChar;
  BufferLen: LongWord;
  procedure WriteInteger(int: integer);
  begin
    PLongInt(Ptr)^ := int;
    Inc(Ptr, SizeOf(int));
  end;
  procedure WriteBool(bool: boolean);
  begin;
    PBoolean(Ptr)^ := bool;
    Inc(Ptr, SizeOf(bool));
  end;

begin
  FLen := FPoints.Count;
  Result := '';
  BufferLen := 524288;
  BufferString := StrAlloc(BufferLen);
  if Points.Count < 1 then
    exit;
  len := Points.Count * TDTMPointSize + SizeOf(integer);
  GetMem(Start, len);
  try
    Ptr := Start;
    WriteInteger(FLen);
    for I := 0 to FLen - 1 do
      WriteInteger(FPoints[I].x);
    for I := 0 to FLen - 1 do
      WriteInteger(FPoints[I].y);
    for I := 0 to FLen - 1 do
      WriteInteger(FPoints[I].Color);
    for I := 0 to FLen - 1 do
      WriteInteger(FPoints[I].Tolerance);
    for I := 0 to FLen - 1 do
      WriteInteger(FPoints[I].AreaSize);
    for I := 0 to FLen - 1 do
      WriteBool(FPoints[I].Bp);
    Destlen := BufferLen;
    if compress(@BufferString[0], Destlen, Start, len) = Z_OK then
    begin
      setlength(Result, Destlen + SizeOf(integer));
      PInteger(@Result[1])^ := len;
      Move(BufferString[0], Result[1 + SizeOf(integer)], Destlen);
      Result := 'm' + Base64EncodeStr(Result);
    end;
  finally
    Freemem(Start, len);
    StrDispose(BufferString);
  end;
end;

procedure TDTMS.Reset;
begin
  Name := '';
  Index := 0;
  DrawColor := 0;
  FLen := 0;
  Normalized := false;
end;

procedure TDTMS.SetPointCount(Amount: integer);
var
  I: integer;
begin
  FPoints.Clear;
  for I := 0 to Amount - 1 do
  begin
    FPoints.Add(TDTMPoint.Create);
  end;
end;

procedure TDTMS.SetAsString(const Value: AnsiString);
var
  Source: AnsiString;
  Destlen: LongWord;
  I, ii, c, size: integer;
  Ptr: pbyte;
  Res: boolean;
  BufferString: PChar;
  BufferLen: LongWord;
  function ReadInteger: integer;
  begin
    Result := PInteger(Ptr)^;
    Inc(Ptr, SizeOf(integer));
  end;
  function ReadBoolean: boolean;
  begin
    Result := PBoolean(Ptr)^;
    Inc(Ptr, SizeOf(boolean));
  end;

begin
  BufferLen := 524288;
  BufferString := StrAlloc(BufferLen);
  Res := false;
  ii := Length(Value);
  if (ii = 0) then
    exit;
  if Value[1] = 'm' then
  begin
    if ii < 9 then
      raise Exception.CreateFMT
        ('Invalid DTM-String passed to StringToDTM: %s', [Value]);
    Source := Base64DecodeStr(copy(Value, 2, ii - 1));
    Move(Source[1], Destlen, 4);
    if I < 1 then
      raise Exception.CreateFMT
        ('Invalid DTM-String passed to StringToDTM: %s', [Value]);
    Destlen := BufferLen;
    Ptr := @Source[1 + SizeOf(LongInt)];
    if uncompress(pbyte(BufferString), Destlen, pbyte(Ptr),
      Length(Source) - SizeOf(integer)) = Z_OK then
    begin
      Ptr := @BufferString[0];
      ii := ReadInteger;
      if (ii * TDTMPointSize) <> (Destlen - SizeOf(integer)) then
        raise Exception.CreateFMT
          ('Invalid DTM-String passed to StringToDTM: %s', [Value]);
      SetPointCount(ii);
      // DPoints := Self.FPoints;
      for I := 0 to ii - 1 do
        FPoints[I].x := ReadInteger;
      for I := 0 to ii - 1 do
        FPoints[I].y := ReadInteger;
      for I := 0 to ii - 1 do
        FPoints[I].Color := ReadInteger;
      for I := 0 to ii - 1 do
        FPoints[I].Tolerance := ReadInteger;
      for I := 0 to ii - 1 do
        FPoints[I].AreaSize := ReadInteger;
      for I := 0 to ii - 1 do
        FPoints[I].Bp := ReadBoolean;
      Res := true;
    end;
  end
  else
  begin
    if (ii mod 2 <> 0) then
      exit;
    ii := ii div 2;
    setlength(Source, ii);
    for I := 1 to ii do
      Source[I] := AnsiChar(HexToInt(Value[I * 2 - 1] + Value[I * 2]));
    Destlen := BufferLen;
    if uncompress(pbyte(BufferString), Destlen, pbyte(Source), ii) = Z_OK then
    begin;
      if (Destlen mod 36) > 0 then
        raise Exception.CreateFMT
          ('Invalid DTM-String passed to StringToDTM: %s', [Value]);
      Destlen := Destlen div 36;
      // Self.Count:= DestLen;
      SetPointCount(Destlen);
      // DPoints := Self.FPoints;
      Ptr := @BufferString[0];
      for I := 0 to Destlen - 1 do
      begin;
        FPoints[I].x := PInteger(PChar(Ptr) + 1)^;
        FPoints[I].y := PInteger(PChar(Ptr) + 5)^;
        FPoints[I].AreaSize := PInteger(PChar(Ptr) + 12)^;
        // DPoints.ash[i] := PInteger(@b^[c+16])^;
        FPoints[I].Color := PInteger(PChar(Ptr) + 20)^;
        FPoints[I].Tolerance := PInteger(PChar(Ptr) + 24)^;
        FPoints[I].Bp := false;
        Inc(PInteger(Ptr), 36);
      end;
      Res := true;
    end;
  end;
  if Res then
    Normalize;
  StrDispose(BufferString);
end;

procedure TDTMS.SaveToFile(FileName: string);
var
  Str: TStringList;
  I: integer;
begin
  Str := TStringList.Create;
  try
    for I := 0 to Points.Count - 1 do
    begin
      Str.Add(IntToStr(I) + ': x =' + IntToStr(Points.DTMPoint[I].x) + ': y =' +
        IntToStr(Points.DTMPoint[I].y) + ': color =' +
        IntToStr(Points.DTMPoint[I].Color))
    end;
    Str.SaveToFile(FileName);
  finally
    Str.Free;
  end;

end;

procedure TDTMS.Normalize;
var
  I: integer;
  m: TPoint;
begin
  Normalized := true;
  if (self = nil) or (FPoints.Count < 1) or
    ((FPoints[0].x = 0) and (FPoints[0].y = 0)) then // Already normalized
    exit;
  for I := 1 to FPoints.Count - 1 do
  begin
    self.Points[I].x := self.Points[I].x - self.Points[0].x;
    self.Points[I].y := self.Points[I].y - self.Points[0].y;
  end;
  self.Points[0].x := 0;
  self.Points[0].y := 0;
  { M:=Point(0,0);
    for I := FPoints.Count -1 downto 0 do
    m := Point(Min(Points[i].x, m.x), Min(Points[i].y, m.y));
    //Self.Points[0].x := Self.Points[0].x - m.x;
    //Self.Points[0].y := Self.Points[0].y - m.y;
    for I := FPoints.Count -1 downto 0 do
    begin
    Self.Points[i].x := Self.Points[i].x - m.x;
    Self.Points[i].y := Self.Points[i].y - m.y;
    end; }
end;

procedure TDTMS.DrawToCanvas(aCanvas: TCanvas; W, H: integer);
var
  Pt: TDTMPoint;
  I: integer;
begin
  if Points.Count > 0 then
  begin
    aCanvas.Pen.Color := DrawColor;
    for I := 0 to Points.Count - 1 do
    begin
      Pt := Points[I];
      // DrawDTMPoint(pt,DrawingColor);
      Pt.DrawToCanvas(aCanvas, DrawColor, W, H);
      {aCanvas.MoveTo(Round(Max(Min(Points[0].x, W - 1), 0)),
        Round(Max(Min(Points[0].y, H - 1), 0)));}
        DrawAntialisedLine(aCanvas,Round(Max(Min(Points[0].x, W - 1), 0)),Round(Max(Min(Points[0].y, H - 1), 0)),
        Round(Max(Min(Pt.x, W - 1), 0)),Round(Max(Min(Pt.y, H - 1), 0)),DrawColor);
      {aCanvas.LineTo(Round(Max(Min(Pt.x, W - 1), 0)),
        Round(Max(Min(Pt.y, H - 1), 0))); }
    end;
  end;
end;

constructor TDTMSList.Create;
begin
  FDTMSs := TList.Create;
end;

procedure TDTMSList.Delete(Index: integer);
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
  I: integer;
begin
  Clear;
  for I := 0 to Src.Count - 1 do
    Add(Src[I]);
end;

procedure TDTMSList.Clear;
var
  I: integer;
begin
  for I := 0 to FDTMSs.Count - 1 do
    DTMS[I].Free;
  FDTMSs.Clear;
end;

function TDTMSList.GetCount: integer;
begin
  Result := FDTMSs.Count;
end;

function TDTMSList.GeTDTMS(Index: integer): TDTMS;
begin
  if (Index >= 0) and (Index < Count) then
    Result := TDTMS(FDTMSs[Index])
  else
    Result := nil;
end;

function TDTMSList.IndexOf(aItem: TDTMS): integer;
begin
  Result := FDTMSs.IndexOf(aItem);
end;

end.
