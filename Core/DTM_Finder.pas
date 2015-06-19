unit DTM_Finder;

interface

uses
  System.Classes, System.SysUtils, Types, Windows, DTM_Bitmaps, DTM_Structure,
  DTM_TPA;

type
  TCTSNoInfo = record // No tolerance
    B, G, R: byte;
  end;

  PCTSNoInfo = ^TCTSNoInfo;

  TCTS0Info = record
    B, G, R: byte;
    Tol: Integer;
  end;

  PCTS0Info = ^TCTS0Info;

  TCTS1Info = record
    B, G, R: byte;
    Tol: Integer; { Squared }
  end;

  PCTS1Info = ^TCTS1Info;

  TCTS2Info = record
    H, S, L: extended;
    hueMod, satMod: extended;
    Tol: Integer;
  end;

  PCTS2Info = ^TCTS2Info;

  TCTS3Info = record
    L, A, B: extended;
    Tol: Integer; { Squared * CTS3Modifier }
  end;

  PCTS3Info = ^TCTS3Info;

  TCTSInfo = Pointer;
  TCTSInfoArray = Array of TCTSInfo;
  TCTSInfo2DArray = Array of TCTSInfoArray;
  TCTSCompareFunction = function(ctsInfo: Pointer; C2: TRGBTriple): boolean;
  TPixels = array of pPixelArray;
  PPixels = ^TPixels;

  TFinder = class
  private
    FCachedWidth, FCachedHeight: Integer;
    FClientTPA: TPointArray;
    FhueMod, FsatMod: extended;
    FCTS3Modifier: extended;
    FCTS: Integer;
    FTarget: TDTMBitmap;
    Procedure UpdateCachedValues(NewWidth, NewHeight: Integer);
    procedure LoadSpiralPath(startX, startY, x1, y1, x2, y2: Integer);
    procedure SetTarget(const Value: TDTMBitmap);
  public
    // WarnOnly : boolean;
    function SimilarColors(Color1, Color2, Tolerance: Integer): boolean;

    function FindDTM(DTM: TDTMs; out x, y: Integer;
      x1, y1, x2, y2: Integer): boolean;
    function FindDTMs(DTM: TDTMs; out Points: TPointArray;
      x1, y1, x2, y2: Integer; maxToFind: Integer = 0): boolean;
    function FindDTMRotated(DTM: TDTMs; out x, y: Integer;
      x1, y1, x2, y2: Integer; sAngle, eAngle, aStep: extended;
      out aFound: extended; Alternating: boolean): boolean;
    function FindDTMsRotated(DTM: TDTMs; out Points: TPointArray;
      x1, y1, x2, y2: Integer; sAngle, eAngle, aStep: extended;
      out aFound: T2DExtendedArray; Alternating: boolean;
      maxToFind: Integer = 0): boolean;

    // tol speeds
    procedure SetToleranceSpeed(nCTS: Integer);
    function GetToleranceSpeed: Integer;
    procedure SetToleranceSpeed2Modifiers(const nHue, nSat: extended);
    procedure GetToleranceSpeed2Modifiers(out hMod, sMod: extended);
    procedure SetToleranceSpeed3Modifier(modifier: extended);
    function GetToleranceSpeed3Modifier: extended;

    { }
    function Create_CTSInfo(Color, Tolerance: Integer): Pointer; overload;
    function Create_CTSInfo(R, G, B, Tolerance: Integer): Pointer; overload;
    function Create_CTSInfoArray(Color, Tolerance: array of Integer)
      : TCTSInfoArray;
    function Create_CTSInfo2DArray(w, H: Integer; data: PPixels;
      Tolerance: Integer): TCTSInfo2DArray;

    constructor Create();
    procedure Reset;
    destructor Destroy; override;

    property CachedWidth: Integer read FCachedWidth write FCachedWidth;
    property CachedHeight: Integer read FCachedHeight write FCachedHeight;
    property CTS: Integer read FCTS write FCTS;
    property ClientTPA: TPointArray read FClientTPA write FClientTPA;
    property hueMod: extended read FhueMod write FhueMod;
    property satMod: extended read FsatMod write FsatMod;
    property CTS3Modifier: extended read FCTS3Modifier write FCTS3Modifier;
    property Target: TDTMBitmap read FTarget write SetTarget;
  end;

implementation

uses Math;
// helpers functions

var
  Percentage: array [0 .. 255] of extended;

Function RGBtoColor(R, G, B: byte): Integer; overload;
begin;
  Result := R or G shl 8 or B shl 16;
end;

Procedure ColorToRGB(Color: Integer; out R, G, B: byte); overload;
begin
  R := Color and $FF;
  G := Color shr 8 and $FF;
  B := Color shr 16 and $FF;
end;

Procedure RGBToXYZ(R, G, B: byte; out x, y, z: extended);
var
  Red, Green, Blue: extended;
begin;
  Red := R / 255;
  Green := G / 255;
  Blue := B / 255;
  if Red > 0.04045 then
    Red := Power((Red + 0.055) / 1.055, 2.4) * 100
  else
    Red := Red * 7.73993808;
  if Green > 0.04045 then
    Green := Power((Green + 0.055) / 1.055, 2.4) * 100
  else
    Green := Green * 7.73993808;
  if Blue > 0.04045 then
    Blue := Power((Blue + 0.055) / 1.055, 2.4) * 100
  else
    Blue := Blue * 7.73993808;
  x := Red * 0.4124 + Green * 0.3576 + Blue * 0.1805;
  y := Red * 0.2126 + Green * 0.7152 + Blue * 0.0722;
  z := Red * 0.0193 + Green * 0.1192 + Blue * 0.9505;
end;

Procedure RGBToHSL(RR, GG, BB: byte; out H, S, L: extended);
var
  R, G, B, D, Cmax, Cmin: extended;
begin
  R := RR / 255;
  G := GG / 255;
  B := BB / 255;
  Cmin := R;
  if G < Cmin then
    Cmin := G;
  if B < Cmin then
    Cmin := B;
  Cmax := R;
  if G > Cmax then
    Cmax := G;
  if B > Cmax then
    Cmax := B;
  L := 0.5 * (Cmax + Cmin);
  if Cmax = Cmin then
  begin
    H := 0;
    S := 0;
  end
  else
  begin;
    D := Cmax - Cmin;
    if L < 0.5 then
      S := D / (Cmax + Cmin)
    else
      S := D / (2 - Cmax - Cmin);
    if R = Cmax then
      H := (G - B) / D
    else if G = Cmax then
      H := 2 + (B - R) / D
    else
      H := 4 + (R - G) / D;
    H := H / 6;
    if H < 0 then
      H := H + 1;
  end;
  H := H * 100;
  S := S * 100;
  L := L * 100;
end;

procedure XYZtoCIELab(x, y, z: extended; out L, A, B: extended);
begin
  x := x / 95.047;
  y := y / 100.000;
  z := z / 108.883;

  if (x > 0.008856) then
    x := Power(x, 1.0 / 3.0)
  else
    x := (7.787 * x) + (16.0 / 116.0);
  if (y > 0.008856) then
    y := Power(y, 1.0 / 3.0)
  else
    y := (7.787 * y) + (16.0 / 116.0);
  if (z > 0.008856) then
    z := Power(z, 1.0 / 3.0)
  else
    z := (7.787 * z) + (16.0 / 116.0);

  L := (116.0 * y) - 16.0;
  A := 500.0 * (x - y);
  B := 200.0 * (y - z);
end;

{ Colour Same functions }
function ColorSame_ctsNo(ctsInfo: Pointer; C2: TRGBTriple): boolean;
var
  C1: TCTSNoInfo;
begin
  C1 := PCTSNoInfo(ctsInfo)^;
  Result := (C1.B = C2.rgbtBlue) and (C1.G = C2.rgbtGreen) and
    (C1.R = C2.rgbtRed);
end;

function ColorSame_cts0(ctsInfo: Pointer; C2: TRGBTriple): boolean;

var
  C1: TCTS0Info;
begin
  C1 := PCTS0Info(ctsInfo)^;
  Result := (Abs(C1.B - C2.rgbtBlue) <= C1.Tol) and
    (Abs(C1.G - C2.rgbtGreen) <= C1.Tol) and (Abs(C1.R - C2.rgbtRed) <= C1.Tol);
end;

function ColorSame_cts1(ctsInfo: Pointer; C2: TRGBTriple): boolean;

var
  C1: TCTS1Info;
  R, G, B: Integer;
begin
  C1 := PCTS1Info(ctsInfo)^;
  B := C1.B - C2.rgbtBlue;
  G := C1.G - C2.rgbtGreen;
  R := C1.R - C2.rgbtRed;
  Result := (B * B + G * G + R * R) <= C1.Tol;
end;

function ColorSame_cts2(ctsInfo: Pointer; C2: TRGBTriple): boolean;

var
  R, G, B: extended;
  Cmin, Cmax, D: extended;
  H, S, L: extended;
  i: TCTS2Info;
begin
  i := PCTS2Info(ctsInfo)^;

  B := Percentage[C2.rgbtBlue];
  G := Percentage[C2.rgbtGreen];
  R := Percentage[C2.rgbtRed];

  Cmin := R;
  Cmax := R;
  if G < Cmin then
    Cmin := G;
  if B < Cmin then
    Cmin := B;
  if G > Cmax then
    Cmax := G;
  if B > Cmax then
    Cmax := B;
  L := 0.5 * (Cmax + Cmin);
  // The L-value is already calculated, lets see if the current point meats the requirements!
  if Abs(L * 100 - i.L) > i.Tol then
    exit(false);
  if Cmax = Cmin then
  begin
    // S and H are both zero, lets check if it mathces the tol
    if (i.H <= (i.hueMod)) and (i.S <= (i.satMod)) then
      exit(true)
    else
      exit(false);
  end;
  D := Cmax - Cmin;
  if L < 0.5 then
    S := D / (Cmax + Cmin)
  else
    S := D / (2 - Cmax - Cmin);
  // We've Calculated the S, check match
  if Abs(S * 100 - i.S) > i.satMod then
    exit(false);
  if R = Cmax then
    H := (G - B) / D
  else if G = Cmax then
    H := 2 + (B - R) / D
  else
    H := 4 + (R - G) / D;
  H := H / 6;
  if H < 0 then
    H := H + 1;
  // Finally lets test H2

  H := H * 100;

  if H > i.H then
    Result := min(H - i.H, Abs(H - (i.H + 100))) <= i.hueMod
  else
    Result := min(i.H - H, Abs(i.H - (H + 100))) <= i.hueMod;
end;

function ColorSame_cts3(ctsInfo: Pointer; C2: TRGBTriple): boolean;

var
  i: TCTS3Info;
  R, G, B: extended;
  x, y, z, L, A, BB: extended;
begin
  i := PCTS3Info(ctsInfo)^;
  { RGBToXYZ(C2^.R, C2^.G, C2^.B, X, Y, Z); }
  { XYZToCIELab(X, Y, Z, L, A, B); }
  R := Percentage[C2.rgbtRed];
  G := Percentage[C2.rgbtGreen];
  B := Percentage[C2.rgbtBlue];
  if R > 0.04045 then
    R := Power((R + 0.055) / 1.055, 2.4) * 100
  else
    R := R * 7.73993808;
  if G > 0.04045 then
    G := Power((G + 0.055) / 1.055, 2.4) * 100
  else
    G := G * 7.73993808;
  if B > 0.04045 then
    B := Power((B + 0.055) / 1.055, 2.4) * 100
  else
    B := B * 7.73993808;

  y := (R * 0.2126 + G * 0.7152 + B * 0.0722) / 100.000;
  if (y > 0.008856) then
    y := Power(y, 1.0 / 3.0)
  else
    y := (7.787 * y) + (16.0 / 116.0);

  x := (R * 0.4124 + G * 0.3576 + B * 0.1805) / 95.047;
  if (x > 0.008856) then
    x := Power(x, 1.0 / 3.0)
  else
    x := (7.787 * x) + (16.0 / 116.0);

  z := (R * 0.0193 + G * 0.1192 + B * 0.9505) / 108.883;
  if (z > 0.008856) then
    z := Power(z, 1.0 / 3.0)
  else
    z := (7.787 * z) + (16.0 / 116.0);

  L := (116.0 * y) - 16.0;
  A := 500.0 * (x - y);
  BB := 200.0 * (y - z);

  L := L - i.L;
  A := A - i.A;
  BB := BB - i.B;

  Result := (L * L + A * A + BB * BB) <= i.Tol;
end;

function Create_CTSInfo_helper(CTS: Integer; Color, Tol: Integer;
  hueMod, satMod, CTS3Modifier: extended): Pointer; overload;
var
  R, G, B: byte;
  x, y, z: extended;
begin
  case CTS of
    - 1:
      begin
        Result := AllocMem(SizeOf(TCTSNoInfo));
        ColorToRGB(Color, PCTSNoInfo(Result)^.R, PCTSNoInfo(Result)^.G,
          PCTSNoInfo(Result)^.B);
      end;
    0:
      begin
        Result := AllocMem(SizeOf(TCTS0Info));
        ColorToRGB(Color, PCTS0Info(Result)^.R, PCTS0Info(Result)^.G,
          PCTS0Info(Result)^.B);
        PCTS0Info(Result)^.Tol := Tol;
      end;
    1:
      begin
        Result := AllocMem(SizeOf(TCTS1Info));
        ColorToRGB(Color, PCTS1Info(Result)^.R, PCTS1Info(Result)^.G,
          PCTS1Info(Result)^.B);

        PCTS1Info(Result)^.Tol := Tol * Tol;
      end;
    2:
      begin
        Result := AllocMem(SizeOf(TCTS2Info));
        ColorToRGB(Color, R, G, B);
        RGBToHSL(R, G, B, PCTS2Info(Result)^.H, PCTS2Info(Result)^.S,
          PCTS2Info(Result)^.L);
        PCTS2Info(Result)^.hueMod := Tol * hueMod;
        PCTS2Info(Result)^.satMod := Tol * satMod;
        PCTS2Info(Result)^.Tol := Tol;
      end;
    3:
      begin
        Result := AllocMem(SizeOf(TCTS3Info));
        ColorToRGB(Color, R, G, B);
        RGBToXYZ(R, G, B, x, y, z);
        XYZtoCIELab(x, y, z, PCTS3Info(Result)^.L, PCTS3Info(Result)^.A,
          PCTS3Info(Result)^.B);
        { XXX: TODO: Make all Tolerance extended }
        PCTS3Info(Result)^.Tol := Ceil(Sqr(Tol * CTS3Modifier));
      end;
  end;
end;

function Create_CTSInfo_helper(CTS: Integer; R, G, B, Tol: Integer;
  hueMod, satMod, CTS3Modifier: extended): Pointer; overload;

var
  Color: Integer;

begin
  Color := RGBtoColor(R, G, B);
  Result := Create_CTSInfo_helper(CTS, Color, Tol, hueMod, satMod,
    CTS3Modifier);
end;

procedure Free_CTSInfo(i: Pointer);
begin
  if assigned(i) then
    FreeMem(i)
  else
    raise Exception.Create('Free_CTSInfo: Invalid TCTSInfo passed');
end;

{ TODO: Not universal, mainly for DTM }
function Create_CTSInfoArray_helper(CTS: Integer;
  Color, Tolerance: array of Integer; hueMod, satMod, CTS3Modifier: extended)
  : TCTSInfoArray;

var
  i: Integer;
begin
  if length(Color) <> length(Tolerance) then
    raise Exception.Create('Create_CTSInfoArray: Length(Color) <>' +
      ' Length(Tolerance');
  SetLength(Result, length(Color));

  for i := High(Result) downto 0 do
    Result[i] := Create_CTSInfo_helper(CTS, Color[i], Tolerance[i], hueMod,
      satMod, CTS3Modifier);
end;

{ TODO: Not universal, mainly for Bitmap }
function Create_CTSInfo2DArray_helper(CTS, w, H: Integer; data: PPixels;
  Tolerance: Integer; hueMod, satMod, CTS3Modifier: extended): TCTSInfo2DArray;
var
  x, y: Integer;
begin
  SetLength(Result, H + 1, w + 1);

  for y := 0 to H do
    for x := 0 to w do
      Result[y][x] := Create_CTSInfo_helper(CTS, data^[y][x].rgbtRed,
        data^[y][x].rgbtGreen, data^[y][x].rgbtBlue, Tolerance, hueMod, satMod,
        CTS3Modifier);
end;

procedure Free_CTSInfoArray(i: TCTSInfoArray);
var
  c: Integer;
begin
  for c := high(i) downto 0 do
    Free_CTSInfo(i[c]);
  SetLength(i, 0);
end;

procedure Free_CTSInfo2DArray(i: TCTSInfo2DArray);
var
  x, y: Integer;
begin
  for y := high(i) downto 0 do
    for x := high(i[y]) downto 0 do
      Free_CTSInfo(i[y][x]);
  SetLength(i, 0);
end;

function Get_CTSCompare(CTS: Integer): TCTSCompareFunction;

begin
  case CTS of
    - 1:
      Result := @ColorSame_ctsNo;
    0:
      Result := @ColorSame_cts0;
    1:
      Result := @ColorSame_cts1;
    2:
      Result := @ColorSame_cts2;
    3:
      Result := @ColorSame_cts3;
  end;
end;

{ TFinder }

procedure TFinder.LoadSpiralPath(startX, startY, x1, y1, x2, y2: Integer);
var
  i, c, Ring: Integer;
  CurrBox: TBox;
begin
  i := 0;
  Ring := 1;
  c := 0;
  CurrBox.x1 := startX - 1;
  CurrBox.y1 := startY - 1;
  CurrBox.x2 := startX + 1;
  CurrBox.y2 := startY + 1;
  if (startX >= x1) and (startX <= x2) and (startY >= y1) and (startY <= y2)
  then
  begin;
    ClientTPA[c] := Point(startX, startY);
    Inc(c);
  end;
  repeat
    if (CurrBox.x2 >= x1) and (CurrBox.x1 <= x2) and (CurrBox.y1 >= y1) and
      (CurrBox.y1 <= y2) then
      for i := CurrBox.x1 + 1 to CurrBox.x2 do
        if (i >= x1) and (i <= x2) then
        begin;
          ClientTPA[c] := Point(i, CurrBox.y1);
          Inc(c);
        end;
    if (CurrBox.x2 >= x1) and (CurrBox.x2 <= x2) and (CurrBox.y2 >= y1) and
      (CurrBox.y1 <= y2) then
      for i := CurrBox.y1 + 1 to CurrBox.y2 do
        if (i >= y1) and (i <= y2) then
        begin;
          ClientTPA[c] := Point(CurrBox.x2, i);
          Inc(c);
        end;
    if (CurrBox.x2 >= x1) and (CurrBox.x1 <= x2) and (CurrBox.y2 >= y1) and
      (CurrBox.y2 <= y2) then
      for i := CurrBox.x2 - 1 downto CurrBox.x1 do
        if (i >= x1) and (i <= x2) then
        begin;
          ClientTPA[c] := Point(i, CurrBox.y2);
          Inc(c);
        end;
    if (CurrBox.x1 >= x1) and (CurrBox.x1 <= x2) and (CurrBox.y2 >= y1) and
      (CurrBox.y1 <= y2) then
      for i := CurrBox.y2 - 1 downto CurrBox.y1 do
        if (i >= y1) and (i <= y2) then
        begin;
          ClientTPA[c] := Point(CurrBox.x1, i);
          Inc(c);
        end;
    Inc(Ring);
    CurrBox.x1 := startX - Ring;
    CurrBox.y1 := startY - Ring;
    CurrBox.x2 := startX + Ring;
    CurrBox.y2 := startY + Ring;
  until (CurrBox.x1 < x1) and (CurrBox.x2 > x2) and (CurrBox.y1 < y1) and
    (CurrBox.y2 > y2);
end;

{ Initialise the variables for TMFinder }
constructor TFinder.Create();
begin
  inherited Create;

  Reset;

end;

procedure TFinder.Reset;
var
  i: Integer;
begin
  // WarnOnly := False;
  Self.CTS := 1;
  Self.hueMod := 0.2;
  Self.satMod := 0.2;
  Self.CTS3Modifier := 1;
  if (Percentage[255] <> 1) then
    for i := 0 to 255 do
      Percentage[i] := i / 255;
end;

destructor TFinder.Destroy;
begin
  { We don't really have to free stuff here.
    The array is managed, so that is automatically freed.
    The rest is either references to objects we may not destroy
  }

  inherited;
end;

procedure TFinder.SetTarget(const Value: TDTMBitmap);
begin
  UpdateCachedValues(Value.Width, Value.Height);

  FTarget := Value;
end;

procedure TFinder.SetToleranceSpeed(nCTS: Integer);
begin
  if (nCTS < 0) or (nCTS > 3) then
    raise Exception.CreateFmt('The given CTS ([%d]) is invalid.', [nCTS]);
  Self.CTS := nCTS;
end;

function TFinder.GetToleranceSpeed: Integer;
begin
  Result := Self.CTS;
end;

procedure TFinder.SetToleranceSpeed2Modifiers(const nHue, nSat: extended);
begin
  Self.hueMod := nHue;
  Self.satMod := nSat;
end;

procedure TFinder.GetToleranceSpeed2Modifiers(out hMod, sMod: extended);
begin
  hMod := Self.hueMod;
  sMod := Self.satMod;
end;

procedure TFinder.SetToleranceSpeed3Modifier(modifier: extended);
begin
  CTS3Modifier := modifier;
end;

function TFinder.GetToleranceSpeed3Modifier: extended;
begin
  Result := CTS3Modifier;
end;

function TFinder.Create_CTSInfo(Color, Tolerance: Integer): Pointer;
begin
  Result := Create_CTSInfo_helper(Self.CTS, Color, Tolerance, Self.hueMod,
    Self.satMod, Self.CTS3Modifier);
end;

function TFinder.Create_CTSInfo(R, G, B, Tolerance: Integer): Pointer;
begin
  Result := Create_CTSInfo_helper(Self.CTS, R, G, B, Tolerance, Self.hueMod,
    Self.satMod, Self.CTS3Modifier);
end;

function TFinder.Create_CTSInfoArray(Color, Tolerance: array of Integer)
  : TCTSInfoArray;
begin
  Result := Create_CTSInfoArray_helper(Self.CTS, Color, Tolerance, Self.hueMod,
    Self.satMod, Self.CTS3Modifier);
end;

function TFinder.Create_CTSInfo2DArray(w, H: Integer; data: PPixels;
  Tolerance: Integer): TCTSInfo2DArray;
begin
  Result := Create_CTSInfo2DArray_helper(Self.CTS, w, H, data, Tolerance,
    Self.hueMod, Self.satMod, Self.CTS3Modifier);
end;

procedure TFinder.UpdateCachedValues(NewWidth, NewHeight: Integer);
begin
  CachedWidth := NewWidth;
  CachedHeight := NewHeight;
  SetLength(FClientTPA, NewWidth * NewHeight);
end;

procedure Swap(var A, B: Integer);
var
  c: Integer;
begin
  c := A;
  A := B;
  B := c;
end;

function TFinder.SimilarColors(Color1, Color2, Tolerance: Integer): boolean;
var
  compare: TCTSCompareFunction;
  ctsInfo: TCTSInfo;
  Col2: TRGBTriple;

begin
  ctsInfo := Create_CTSInfo(Color1, Tolerance);
  compare := Get_CTSCompare(Self.CTS);
  ColorToRGB(Color2, Col2.rgbtRed, Col2.rgbtGreen, Col2.rgbtBlue);

  Result := compare(ctsInfo, Col2);

  Free_CTSInfo(ctsInfo);
end;

function TFinder.FindDTM(DTM: TDTMs; out x, y: Integer;
  x1, y1, x2, y2: Integer): boolean;
var
  P: TPointArray;
begin
  Result := Self.FindDTMs(DTM, P, x1, y1, x2, y2, 1);
  if Result then
  begin
    x := P[0].x;
    y := P[0].y;
  end;
end;

function ValidMainPointBox(var DTM: TDTMs; const x1, y1, x2, y2: Integer)
  : TBox; overload;
var
  i: Integer;
  B: TBox;
begin
  DTM.Normalize;

  FillChar(B, SizeOf(TBox), 0); // Sets all the members to 0
  B.x1 := MaxInt;
  B.y1 := MaxInt;
  for i := 0 to DTM.Points.Count - 1 do
  begin
    B.x1 := min(B.x1, DTM.Points[i].x); // - dtm.asz[i]);
    B.y1 := min(B.y1, DTM.Points[i].y); // - dtm.asz[i]);
    B.x2 := max(B.x2, DTM.Points[i].x); // + dtm.asz[i]);
    B.y2 := max(B.y2, DTM.Points[i].y); // + dtm.asz[i]);
  end;

  // writeln(Format('DTM Bounding Box: %d, %d : %d, %d', [b.x1, b.y1,b.x2,b.y2]));
  Result.x1 := x1 - B.x1;
  Result.y1 := y1 - B.y1;
  Result.x2 := x2 - B.x2;
  Result.y2 := y2 - B.y2;
end;

function ValidMainPointBox(const TPA: TPointArray;
  const x1, y1, x2, y2: Integer): TBox; overload;
var
  i: Integer;
  B: TBox;
begin
  B := GetTPABounds(TPA);
  Result.x1 := x1 - B.x1;
  Result.y1 := y1 - B.y1;
  Result.x2 := x2 - B.x2;
  Result.y2 := y2 - B.y2;
end;

// MaxToFind, if it's < 1 it won't stop looking
function TFinder.FindDTMs(DTM: TDTMs; out Points: TPointArray;
  x1, y1, x2, y2, maxToFind: Integer): boolean;

  function PtAppend(var V: TPointArray; const R: TPoint): Integer;
  begin
    Result := length(V);
    SetLength(V, Result + 1);
    V[Result] := R;
  end;

var
  H, w, i: Integer;
  dx, dy, col: Integer;
  Dpt, subDpt: TDTMPoint;
  ValidFlag: boolean;
begin
  H := 0;
  Result := false;
  try
    DTM.SaveToFile('C:\dtm.txt');
    // TempDTM.SaveToFile('C:\tempdtm.txt');
    while H < y2 do
    begin
      w := 0;
      while w < x2 do
      begin
        Dpt := DTM.Points.DTMPoint[0];
        if (w = 123) then
          sleep(1);

        if SimilarColors(Target.FastGetPixel(w, H), Dpt.Color, Dpt.Tolerance)
        then
        begin
          ValidFlag := true;
          for i := 1 to DTM.Points.Count - 1 do
          begin
            subDpt := DTM.Points.DTMPoint[i];
            col := 0;
            col := Target.FastGetPixel(subDpt.x + w, subDpt.y + H);
            if not SimilarColors(Target.FastGetPixel(subDpt.x + w,
              subDpt.y + H), subDpt.Color, subDpt.Tolerance) then
            begin
              ValidFlag := false;
              Break;
            end;
          end;
          if ValidFlag then
            PtAppend(Points, Point(w, H));
        end;
        Inc(w);
      end;
      Inc(H);
    end;
  finally
    Result := length(Points) > 0;
  end;
end;

function TFinder.FindDTMRotated(DTM: TDTMs; out x, y: Integer;
  x1, y1, x2, y2: Integer; sAngle, eAngle, aStep: extended;
  out aFound: extended; Alternating: boolean): boolean;

var
  P: TPointArray;
  F: T2DExtendedArray;
begin
  Result := FindDTMsRotated(DTM, P, x1, y1, x2, y2, sAngle, eAngle, aStep, F,
    Alternating, 1);
  if not Result then
    exit;

  aFound := F[0][0];
  x := P[0].x;
  y := P[0].y;
  exit(true);
end;

procedure RotPoints_DTM(const P: TPointArray; var RotTPA: TPointArray;
  const A: extended); inline;
var
  i, L: Integer;
begin
  L := High(P);
  for i := 0 to L do
  begin
    RotTPA[i].x := Round(cos(A) * P[i].x - sin(A) * P[i].y);
    RotTPA[i].y := Round(sin(A) * P[i].x + cos(A) * P[i].y);
  end;
end;

function TFinder.FindDTMsRotated(DTM: TDTMs; out Points: TPointArray;
  x1, y1, x2, y2: Integer; sAngle, eAngle, aStep: extended;
  out aFound: T2DExtendedArray; Alternating: boolean;
  maxToFind: Integer): boolean;
var
  // Cached variables
  Len: Integer;

  DTPA: TPointArray;
  RotTPA: TPointArray;

  // Bitwise
  B: Array of Array of Integer;
  ch: Array of Array of Integer;

  // bounds
  w, H: Integer;
  MA: TBox;
  MaxX, MaxY: Integer; // The maximum value a (subpoint) can have!

  // for loops, etc
  xx, yy: Integer;
  i, xxx, yyy: Integer;
  startX, startY, EndX, EndY: Integer;

  Found: boolean;

  // If we search alternating, we start in the middle and then +,-,+,- the angle step outwars
  MiddleAngle: extended;
  // Count the amount of anglesteps, mod 2 determines whether it's a + or a - search, and div 2 determines the amount of steps
  // you have to take.
  AngleSteps: Integer;

  // point count
  pc: Integer;

  goodPoints: Array of boolean;
  S: extended;

  col_arr, tol_arr: Array of Integer;
  ctsinfoarray: TCTSInfoArray;
  compare: TCTSCompareFunction;

label theEnd;
label AnotherLoopEnd;

begin
  pc := 0;

  DTM.Normalize;;

  Len := DTM.Points.Count;

  SetLength(goodPoints, Len);
  for i := 0 to Len - 1 do
    goodPoints[i] := not DTM.Points[i].bp;

  MaxX := x2 - x1;
  MaxY := y2 - y1;

  // Init data structure B.
  w := x2 - x1;
  H := y2 - y1;
  SetLength(B, (w + 1));
  SetLength(ch, (w + 1));
  for i := 0 to w do
  begin
    SetLength(B[i], (H + 1));
    FillChar(B[i][0], SizeOf(Integer) * (H + 1), 0);
    SetLength(ch[i], (H + 1));
    FillChar(ch[i][0], SizeOf(Integer) * (H + 1), 0);
  end;

  {
    When we search for a rotated DTM, everything is the same, except the coordinates..
    Therefore we create a TPA of the 'original' DTM, containing all the Points.
    This then will be used to rotate the points }
  SetLength(DTPA, Len);
  SetLength(RotTPA, Len);
  for i := 0 to Len - 1 do
    DTPA[i] := Point(DTM.Points[i].x, DTM.Points[i].y);

  SetLength(col_arr, Len);
  SetLength(tol_arr, Len);
  // C = DTM.C
  for i := 0 to Len - 1 do
  begin
    col_arr[i] := DTM.Points[i].Color;
    tol_arr[i] := DTM.Points[i].Tolerance;
  end;

  ctsinfoarray := Create_CTSInfoArray(col_arr, tol_arr);
  compare := Get_CTSCompare(Self.CTS);

  SetLength(aFound, 0);
  SetLength(Points, 0);
  if Alternating then
  begin
    MiddleAngle := (sAngle + eAngle) / 2.0;
    S := MiddleAngle; // Start in the middle!
    AngleSteps := 0;
  end
  else
    S := sAngle;
  while S < eAngle do
  begin
    RotPoints_DTM(DTPA, RotTPA, S);
    // DTMRot now has the same points as the original DTM, just rotated!
    // The other stuff in the structure doesn't matter, as it's the same as the original DTM..
    // So from now on if we want to see what 'point' we're at, use RotTPA, for the rest just use the original DTM
    MA := ValidMainPointBox(RotTPA, x1, y1, x2, y2);
    // CD(ClientData) starts at 0,0.. We must adjust the MA, since this is still based on the xs,ys,xe,ye box.
    MA.x1 := MA.x1 - x1;
    MA.y1 := MA.y1 - y1;
    MA.x2 := MA.x2 - x1;
    MA.y2 := MA.y2 - y1;
    // MA is now fixed to the new (0,0) box...
    for yy := MA.y1 to MA.y2 do
      // (xx,yy) is now the coord of the mainpoint in the search area
      for xx := MA.x1 to MA.x2 do
      begin
        // Mainpoint can have area size as well, so we must check that just like any subpoint.
        for i := 0 to Len - 1 do
        begin // change to use other areashapes too.
          Found := false;
          // With area it can go out of bounds, therefore this max/min check
          startX := max(0, xx - DTM.Points[i].AreaSize + RotTPA[i].x);
          startY := max(0, yy - DTM.Points[i].AreaSize + RotTPA[i].y);
          EndX := min(MaxX, xx + DTM.Points[i].AreaSize + RotTPA[i].x);
          EndY := min(MaxY, yy + DTM.Points[i].AreaSize + RotTPA[i].y);
          for xxx := startX to EndX do // The search area for the subpoint
          begin
            for yyy := startY to EndY do
            begin
              // If we have not checked this point, check it now.
              if ch[xxx][yyy] and (1 shl i) = 0 then
              begin
                // Checking point i now. (Store that we matched it)
                ch[xxx][yyy] := ch[xxx][yyy] or (1 shl i);

                if compare(ctsinfoarray[i], Target.ScanLine[yyy]^[xxx]) then
                  B[xxx][yyy] := B[xxx][yyy] or (1 shl i);
              end;

              // Check if the point matches the subpoint
              if (B[xxx][yyy] and (1 shl i) <> 0) then
              begin
                // Check if it was supposed to be a goodpoint..
                if goodPoints[i] then
                begin
                  Found := true;
                  Break;
                end
                else // It was not supposed to match!!
                  goto AnotherLoopEnd;
              end;
            end;
            if Found then
              Break; // Optimalisation, we must break out of this second for loop, since we already found the subpoint
          end;
          if (not Found) and (goodPoints[i]) then
            // This sub-point wasn't found, while it should.. Exit this mainpoint search
            goto AnotherLoopEnd;
        end;
        // We survived the sub-point search, add this mainpoint to the results.
        Inc(pc);
        SetLength(Points, pc);
        Points[pc - 1] := Point(xx + x1, yy + y1);
        SetLength(aFound, pc);
        SetLength(aFound[pc - 1], 1);
        aFound[pc - 1][0] := S;
        if (pc = maxToFind) then
          goto theEnd;
      AnotherLoopEnd:
      end;
    if Alternating then
    begin
      if AngleSteps mod 2 = 0 then
        // This means it's an even number, thus we must add a positive step
        S := MiddleAngle + (aStep * (AngleSteps div 2 + 1))
        // Angle steps starts at 0, so we must add 1.
      else
        S := MiddleAngle - (aStep * (AngleSteps div 2 + 1));
      // We must search in the negative direction
      Inc(AngleSteps);
    end
    else
      S := S + aStep;
  end;
theEnd:

  Free_CTSInfoArray(ctsinfoarray);

  Result := (pc > 0);
  { Don't forget to pre calculate the rotated points at the start.
    Saves a lot of rotatepoint() calls. }
  // raise Exception.CreateFmt('Not done yet!', []);
end;

end.
