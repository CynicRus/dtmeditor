unit DTM_Finder;

interface
  uses
    System.Classes,System.SysUtils,Types,Windows,DTM_Bitmaps,DTM_Structure,DTM_TPA;

  type
  TCTSNoInfo = record    //No tolerance
      B, G, R:byte;
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
      Tol: Integer; { Squared * CTS3Modifier}
  end;
  PCTS3Info = ^TCTS3Info;

  TCTSInfo = Pointer;
  TCTSInfoArray = Array of TCTSInfo;
  TCTSInfo2DArray = Array of TCTSInfoArray;
  TCTSCompareFunction = function (ctsInfo: Pointer; C2: TRGBTriple): boolean;
  TPixels = array of pPixelArray;
  PPixels = ^TPixels;
  TFinder = class
  private
    FCachedWidth, FCachedHeight : integer;
    FClientTPA : TPointArray;
    FhueMod, FsatMod: Extended;
    FCTS3Modifier: Extended;
    FCTS: Integer;
    FTarget: TDTMBitmap;
    Procedure UpdateCachedValues(NewWidth,NewHeight : integer);
    procedure LoadSpiralPath(startX, startY, x1, y1, x2, y2: Integer);
    procedure SetTarget(const Value: TDTMBitmap);
  public
    //WarnOnly : boolean;
    function SimilarColors(Color1,Color2,Tolerance : Integer) : boolean;

    function FindDTM(DTM: TDTMs; out x, y: Integer; x1, y1, x2, y2: Integer): Boolean;
    function FindDTMs(DTM: TDTMs; out Points: TPointArray; x1, y1, x2, y2 : integer; maxToFind: Integer = 0): Boolean;
    function FindDTMRotated(DTM: TDTMs; out x, y: Integer; x1, y1, x2, y2: Integer; sAngle, eAngle, aStep: Extended; out aFound: Extended; Alternating : boolean): Boolean;
    function FindDTMsRotated(DTM: TDTMs; out Points: TPointArray; x1, y1, x2, y2: Integer; sAngle, eAngle, aStep: Extended; out aFound: T2DExtendedArray;Alternating : boolean; maxToFind: Integer = 0): Boolean;

    // tol speeds
    procedure SetToleranceSpeed(nCTS: Integer);
    function GetToleranceSpeed: Integer;
    procedure SetToleranceSpeed2Modifiers(const nHue, nSat: Extended);
    procedure GetToleranceSpeed2Modifiers(out hMod, sMod: Extended);
    procedure SetToleranceSpeed3Modifier(modifier: Extended);
    function GetToleranceSpeed3Modifier: Extended;

    { }
    function Create_CTSInfo(Color, Tolerance: Integer): Pointer; overload;
    function Create_CTSInfo(R, G, B, Tolerance: Integer): Pointer; overload;
    function Create_CTSInfoArray(color, tolerance: array of integer): TCTSInfoArray;
    function Create_CTSInfo2DArray(w, h: integer; data: PPixels; Tolerance: Integer): TCTSInfo2DArray;

    constructor Create();
    procedure Reset;
    destructor Destroy; override;

    property CachedWidth: integer read FCachedWidth write FCachedWidth;
    property CachedHeight: integer read FCachedHeight write FCachedHeight;
    property CTS: integer read FCTS write FCTS;
    property ClientTPA: TPointArray read  FClientTPA write FClientTPA;
    property HueMod: Extended read FhueMod write FhueMod;
    property SatMod: Extended read FsatMod write FsatMod;
    property CTS3Modifier: Extended read FCTS3Modifier write FCTS3Modifier;
    property Target: TDTMBitmap read FTarget write SetTarget;
  end;
implementation
  uses Math;
//helpers functions

var
  Percentage : array[0..255] of Extended;

Function RGBtoColor(r,g,b : byte): integer; overload;
begin;
  Result := R or g shl 8 or b shl 16;
end;

Procedure ColorToRGB(Color : integer;out r,g,b : byte); overload;
begin
  R := Color and $ff;
  G := Color shr 8 and $ff;
  B := Color shr 16 and $ff;
end;

Procedure RGBToXYZ(R,G,B : byte;out x,y,z : Extended);
var
  Red,Green,Blue : Extended;
begin;
  Red := R / 255;
  Green := G / 255;
  Blue := B / 255;
  if Red > 0.04045  then
    Red := Power( ( Red + 0.055 ) / 1.055  , 2.4) * 100
  else
    Red := Red * 7.73993808;
  if Green > 0.04045  then
    Green := Power( ( Green + 0.055 ) / 1.055 , 2.4) *  100
  else
    Green := Green * 7.73993808;
  if  Blue > 0.04045 then
    Blue := Power(  ( Blue + 0.055 ) / 1.055  , 2.4) * 100
  else
    Blue := Blue * 7.73993808;
  X := Red * 0.4124 + Green * 0.3576 + Blue * 0.1805;
  Y := Red * 0.2126 + Green * 0.7152 + Blue * 0.0722;
  Z := Red * 0.0193 + Green * 0.1192 + Blue * 0.9505;
end;

Procedure RGBToHSL(RR,GG,BB : byte;out H,S,L : Extended);
var
  R,  G,  B,   D,  Cmax, Cmin: Extended;
begin
  R := RR / 255;
  G := GG / 255;
  B := BB / 255;
  CMin := R;
  if G < Cmin then Cmin := G;
  if B  < Cmin then Cmin := B;
  CMax := R;
  if G > Cmax then Cmax := G;
  if B  > Cmax then Cmax := B;
  L := 0.5 * (Cmax + Cmin);
  if Cmax = Cmin then
  begin
    H := 0;
    S := 0;
  end else
  begin;
    D := Cmax - Cmin;
    if L < 0.5 then
      S := D / (Cmax + Cmin)
    else
      S := D / (2 - Cmax - Cmin);
    if R = Cmax then
      H := (G - B) / D
    else
      if G = Cmax then
        H  := 2 + (B - R) / D
      else
        H := 4 +  (R - G) / D;
    H := H / 6;
    if H < 0 then
      H := H + 1;
  end;
  H := H * 100;
  S := S * 100;
  L := L * 100;
end;

procedure XYZtoCIELab(X, Y, Z: Extended; out L, a, b: Extended);
begin
  X := X / 95.047;
  Y := Y / 100.000;
  Z := Z / 108.883;

  if ( X > 0.008856 ) then
    X := Power(X, 1.0/3.0)
  else
    X := ( 7.787 * X ) + ( 16.0 / 116.0 );
  if ( Y > 0.008856 ) then
    Y := Power(Y, 1.0/3.0)
  else
    Y := ( 7.787 * Y ) + ( 16.0 / 116.0 );
  if ( Z > 0.008856 ) then
    Z := Power(Z, 1.0/3.0)
  else
    Z := ( 7.787 * Z ) + ( 16.0 / 116.0 );

  L := (116.0 * Y ) - 16.0;
  a := 500.0 * ( X - Y );
  b := 200.0 * ( Y - Z );
end;
{ Colour Same functions }
function ColorSame_ctsNo(ctsInfo: Pointer; C2: TRGBTriple): boolean;
var
    C1: TCTSNoInfo;
begin
  C1 := PCTSNoInfo(ctsInfo)^;
  Result := (C1.B = C2.rgbtBlue)
        and (C1.G = C2.rgbtGreen)
        and (C1.R = C2.rgbtRed);
end;

function ColorSame_cts0(ctsInfo: Pointer; C2: TRGBTriple): boolean;

var
    C1: TCTS0Info;
begin
  C1 := PCTS0Info(ctsInfo)^;
  Result := (Abs(C1.B - C2.rgbtBlue) <= C1.Tol)
        and (Abs(C1.G - C2.rgbtGreen) <= C1.Tol)
        and (Abs(C1.R - C2.rgbtRed) <= C1.Tol);
end;

function ColorSame_cts1(ctsInfo: Pointer; C2: TRGBTriple): boolean;

var
    C1: TCTS1Info;
    r,g,b: integer;
begin
  C1 := PCTS1Info(ctsInfo)^;
  b := C1.B - C2.rgbtBlue;
  g := C1.G - C2.rgbtGreen;
  r := C1.R - C2.rgbtRed;
  Result := (b*b + g*g + r*r) <= C1.Tol;
end;

function ColorSame_cts2(ctsInfo: Pointer; C2: TRGBTriple): boolean;

var
    r,g ,b: extended;
    CMin, CMax,D : extended;
    h,s,l : extended;
    i: TCTS2Info;
begin
  i := PCTS2Info(ctsInfo)^;

  B := Percentage[C2.rgbtBlue];
  G := Percentage[C2.rgbtGreen];
  R := Percentage[C2.rgbtRed];

  CMin := R;
  CMax := R;
  if G  < Cmin then CMin := G;
  if B  < Cmin then CMin := B;
  if G  > Cmax then CMax := G;
  if B  > Cmax then CMax := B;
  l := 0.5 * (Cmax + Cmin);
  //The L-value is already calculated, lets see if the current point meats the requirements!
  if abs(l*100 - i.L) > i.Tol then
    exit(false);
  if Cmax = Cmin then
  begin
    //S and H are both zero, lets check if it mathces the tol
    if (i.H <= (i.hueMod)) and
       (i.S <= (i.satMod)) then
      exit(true)
    else
      exit(false);
  end;
  D := Cmax - Cmin;
  if l < 0.5 then
    s := D / (Cmax + Cmin)
  else
    s := D / (2 - Cmax - Cmin);
  // We've Calculated the S, check match
  if abs(S*100 - i.S) > i.satMod then
    exit(false);
  if R = Cmax then
    h := (G - B) / D
  else
    if G = Cmax then
      h  := 2 + (B - R) / D
    else
      h := 4 +  (R - G) / D;
  h := h / 6;
  if h < 0 then
    h := h + 1;
  //Finally lets test H2

  h := h * 100;

  if h > i.H then
    Result := min(h - i.H, abs(h - (i.H + 100) )) <= i.hueMod
  else
    Result := min(i.H - h, abs(i.H - (h + 100) )) <= i.hueMod;
end;

function ColorSame_cts3(ctsInfo: Pointer; C2: TRGBTriple): boolean;

var
    i: TCTS3Info;
    r, g, b : extended;
    x, y, z, L, A, bb: Extended;
begin
  i := PCTS3Info(ctsInfo)^;
  { RGBToXYZ(C2^.R, C2^.G, C2^.B, X, Y, Z); }
  { XYZToCIELab(X, Y, Z, L, A, B); }
  R := Percentage[C2.rgbtRed];
  G := Percentage[C2.rgbtGreen];
  B := Percentage[C2.rgbtBlue];
  if r > 0.04045  then
    r := Power( ( r + 0.055 ) / 1.055  , 2.4) * 100
  else
    r := r * 7.73993808;
  if g > 0.04045  then
    g := Power( ( g + 0.055 ) / 1.055 , 2.4) * 100
  else
    g := g * 7.73993808;
  if  b > 0.04045 then
    b := Power(  ( b + 0.055 ) / 1.055  , 2.4) * 100
  else
    b := b * 7.73993808;

  y := (r * 0.2126 + g * 0.7152 + b * 0.0722)/100.000;
  if ( Y > 0.008856 ) then
    Y := Power(Y, 1.0/3.0)
  else
    Y := ( 7.787 * Y ) + ( 16.0 / 116.0 );

  x := (r * 0.4124 + g * 0.3576 + b * 0.1805)/95.047;
  if ( X > 0.008856 ) then
    X := Power(X, 1.0/3.0)
  else
    X := ( 7.787 * X ) + ( 16.0 / 116.0 );

  z := (r * 0.0193 + g * 0.1192 + b * 0.9505)/108.883;
  if ( Z > 0.008856 ) then
    Z := Power(Z, 1.0/3.0)
  else
    Z := ( 7.787 * Z ) + ( 16.0 / 116.0 );

  l := (116.0 * Y ) - 16.0;
  a := 500.0 * ( X - Y );
  bb := 200.0 * ( Y - Z );

  L := L - i.L;
  A := A - i.A;
  Bb := Bb - i.B;

  Result := (L*L + A*A + bB*Bb) <= i.Tol;
end;

function Create_CTSInfo_helper(cts: integer; Color, Tol: Integer;
                        hueMod, satMod, CTS3Modifier: extended): Pointer; overload;
var
    R, G, B: byte;
    X, Y, Z: Extended;
begin
  case cts of
      -1:
      begin
        Result :=  AllocMem(SizeOf(TCTSNoInfo));
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
        RGBToXYZ(R, G, B, X, Y, Z);
        XYZToCIELab(X, Y, Z, PCTS3Info(Result)^.L, PCTS3Info(Result)^.A,
                  PCTS3Info(Result)^.B);
        { XXX: TODO: Make all Tolerance extended }
        PCTS3Info(Result)^.Tol := Ceil(Sqr(Tol*CTS3Modifier));
      end;
  end;
end;

function Create_CTSInfo_helper(cts: integer; R, G, B, Tol: Integer;
                        hueMod, satMod, CTS3Modifier: extended): Pointer; overload;

var Color: Integer;

begin
  Color := RGBToColor(R, G, B);
  Result := Create_CTSInfo_helper(cts, Color, Tol, hueMod, satMod, CTS3Modifier);
end;

procedure Free_CTSInfo(i: Pointer);
begin
  if assigned(i) then
      FreeMem(i)
  else
      raise Exception.Create('Free_CTSInfo: Invalid TCTSInfo passed');
end;


{ TODO: Not universal, mainly for DTM }
function Create_CTSInfoArray_helper(cts: integer; color, tolerance: array of integer;
    hueMod, satMod, CTS3Modifier: extended): TCTSInfoArray;

var
   i: integer;
begin
  if length(color) <> length(tolerance) then
    raise Exception.Create('Create_CTSInfoArray: Length(Color) <>'
                          +' Length(Tolerance');
  SetLength(Result, Length(color));

  for i := High(result) downto 0 do
    result[i] := Create_CTSInfo_helper(cts, color[i], tolerance[i], hueMod, satMod,
        CTS3Modifier);
end;


{ TODO: Not universal, mainly for Bitmap }
function Create_CTSInfo2DArray_helper(cts, w, h: integer; data: PPixels;
    Tolerance: Integer; hueMod, satMod, CTS3Modifier: Extended): TCTSInfo2DArray;
var
   x, y: integer;
begin
  SetLength(Result,h+1,w+1);

  for y := 0 to h do
    for x := 0 to w do
      Result[y][x] := Create_CTSInfo_helper(cts,
          data^[y][x].rgbtRed, data^[y][x].rgbtGreen, data^[y][x].rgbtBlue,
          Tolerance, hueMod, satMod, CTS3Modifier);
end;

procedure Free_CTSInfoArray(i: TCTSInfoArray);
var
   c: integer;
begin
  for c := high(i) downto 0 do
    Free_CTSInfo(i[c]);
  SetLength(i, 0);
end;

procedure Free_CTSInfo2DArray(i: TCTSInfo2DArray);
var
   x, y: integer;
begin
  for y := high(i) downto 0 do
    for x := high(i[y]) downto 0 do
      Free_CTSInfo(i[y][x]);
  SetLength(i, 0);
end;

function Get_CTSCompare(cts: Integer): TCTSCompareFunction;

begin
  case cts of
      -1: Result := @ColorSame_ctsNo;
      0: Result := @ColorSame_cts0;
      1: Result := @ColorSame_cts1;
      2: Result := @ColorSame_cts2;
      3: Result := @ColorSame_cts3;
  end;
end;


{ TFinder }

procedure TFinder.LoadSpiralPath(startX, startY, x1, y1, x2, y2: Integer);
var
  i,c,Ring : integer;
  CurrBox : TBox;
begin
  i := 0;
  Ring := 1;
  c := 0;
  CurrBox.x1 := Startx-1;
  CurrBox.y1 := Starty-1;
  CurrBox.x2 := Startx+1;
  CurrBox.y2 := Starty+1;
  if (startx >= x1) and (startx <= x2) and (starty >= y1) and (starty <= y2) then
  begin;
    ClientTPA[c] := Point(Startx, StartY);
    Inc(c);
  end;
  repeat
    if (CurrBox.x2 >= x1) and (CurrBox.x1 <= x2) and (Currbox.y1 >= y1) and (Currbox.y1 <= y2)  then
      for i := CurrBox.x1 + 1 to CurrBox.x2 do
        if (I >= x1) and ( I <= x2) then
        begin;
          ClientTPA[c] := Point(i,CurrBox.y1);
          Inc(c);
        end;
    if (CurrBox.x2 >= x1) and (CurrBox.x2 <= x2) and (Currbox.y2 >= y1) and (Currbox.y1 <= y2)  then
      for i := CurrBox.y1 + 1 to CurrBox.y2 do
        if (I >= y1) and ( I <= y2) then
        begin;
          ClientTPA[c] := Point(Currbox.x2, I);
          Inc(c);
        end;
    if (CurrBox.x2 >= x1) and (CurrBox.x1 <= x2) and (Currbox.y2 >= y1) and (Currbox.y2 <= y2)  then
      for i := CurrBox.x2 - 1 downto CurrBox.x1 do
        if (I >= x1) and ( I <= x2) then
        begin;
          ClientTPA[c] := Point(i,CurrBox.y2);
          Inc(c);
        end;
    if (CurrBox.x1 >= x1) and (CurrBox.x1 <= x2) and (Currbox.y2 >= y1) and (Currbox.y1 <= y2)  then
      for i := CurrBox.y2 - 1 downto CurrBox.y1 do
        if (I >= y1) and ( I <= y2) then
        begin;
          ClientTPA[c] := Point(Currbox.x1, I);
          Inc(c);
        end;
    Inc(ring);
    CurrBox.x1 := Startx-ring;
    CurrBox.y1 := Starty-Ring;
    CurrBox.x2 := Startx+Ring;
    CurrBox.y2 := Starty+Ring;
  until (Currbox.x1 < x1) and (Currbox.x2 > x2) and (currbox.y1 < y1)
        and (currbox.y2 > y2);
end;

{ Initialise the variables for TMFinder }
constructor TFinder.Create();
begin
  inherited Create;

  Reset;

end;

procedure TFinder.Reset;
var
 i: integer;
begin
  //WarnOnly := False;
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
    {   We don't really have to free stuff here.
        The array is managed, so that is automatically freed.
        The rest is either references to objects we may not destroy
    }

  inherited;
end;

procedure TFinder.SetTarget(const Value: TDTMBitmap);
begin
  UpdateCachedValues(Value.Width,Value.Height);

  FTarget := Value;
end;

procedure TFinder.SetToleranceSpeed(nCTS: Integer);
begin
  if (nCTS < 0) or (nCTS > 3) then
    raise Exception.CreateFmt('The given CTS ([%d]) is invalid.',[nCTS]);
  Self.CTS := nCTS;
end;

function TFinder.GetToleranceSpeed: Integer;
begin
  Result := Self.CTS;
end;

procedure TFinder.SetToleranceSpeed2Modifiers(const nHue, nSat: Extended);
begin
  Self.hueMod := nHue;
  Self.satMod := nSat;
end;

procedure TFinder.GetToleranceSpeed2Modifiers(out hMod, sMod: Extended);
begin
  hMod := Self.hueMod;
  sMod := Self.satMod;
end;

procedure TFinder.SetToleranceSpeed3Modifier(modifier: Extended);
begin
  CTS3Modifier := modifier;
end;

function TFinder.GetToleranceSpeed3Modifier: Extended;
begin
  Result := CTS3Modifier;
end;

function TFinder.Create_CTSInfo(Color, Tolerance: Integer): Pointer;
begin
  Result := Create_CTSInfo_helper(Self.cts, Color, Tolerance, Self.hueMod,
              Self.satMod, Self.CTS3Modifier);
end;

function TFinder.Create_CTSInfo(R, G, B, Tolerance: Integer): Pointer;
begin
  Result := Create_CTSInfo_helper(Self.cts, R, G, B, Tolerance, Self.hueMod,
              Self.satMod, Self.CTS3Modifier);
end;

function TFinder.Create_CTSInfoArray(color, tolerance: array of integer): TCTSInfoArray;
begin
  Result := Create_CTSInfoArray_helper(Self.cts, color, tolerance, Self.hueMod,
      Self.satMod, Self.CTS3Modifier);
end;

function TFinder.Create_CTSInfo2DArray(w, h: integer; data: PPixels;
    Tolerance: Integer): TCTSInfo2DArray;
begin
  Result := Create_CTSInfo2DArray_helper(Self.cts, w, h, data, tolerance, Self.hueMod,
              Self.satMod, Self.CTS3Modifier);
end;

procedure TFinder.UpdateCachedValues(NewWidth, NewHeight: integer);
begin
  CachedWidth := NewWidth;
  CachedHeight := NewHeight;
  SetLength(FClientTPA,NewWidth * NewHeight);
end;

procedure Swap(var A,B : integer);
var
  c : integer;
begin
  c := a;
  a := b;
  b := c;
end;



function TFinder.SimilarColors(Color1, Color2, Tolerance: Integer) : boolean;
var
   compare: TCTSCompareFunction;
   ctsinfo: TCTSInfo;
   Col2: TRGBTriple;

begin
  ctsinfo := Create_CTSInfo(Color1, Tolerance);
  compare := Get_CTSCompare(Self.CTS);
  ColorToRGB(Color2, Col2.rgbtRed, Col2.rgbtGreen, Col2.rgbtBlue);

  Result := compare(ctsinfo, Col2);

  Free_CTSInfo(ctsinfo);
end;

function TFinder.FindDTM(DTM: TDTMS; out x, y: Integer; x1, y1, x2, y2: Integer): Boolean;
var
   P: TPointArray;
begin
  Result := Self.FindDTMs(DTM, P, x1, y1, x2, y2, 1);
  if Result then
  begin
    x := p[0].x;
    y := p[0].y;
  end;
end;

function ValidMainPointBox(var dtm: TDTMs; const x1, y1, x2, y2: Integer): TBox; overload;
var
   i: Integer;
   b: TBox;
begin
  dtm.Normalize;

  FillChar(b, SizeOf(TBox), 0); //Sets all the members to 0
  b.x1 := MaxInt;
  b.y1 := MaxInt;
  for i := 0 to dtm.Points.Count - 1 do
  begin
    b.x1 := min(b.x1, dtm.Points[i].x);// - dtm.asz[i]);
    b.y1 := min(b.y1, dtm.Points[i].y);// - dtm.asz[i]);
    b.x2 := max(b.x2, dtm.Points[i].x);// + dtm.asz[i]);
    b.y2 := max(b.y2, dtm.Points[i].y);// + dtm.asz[i]);
  end;

  //writeln(Format('DTM Bounding Box: %d, %d : %d, %d', [b.x1, b.y1,b.x2,b.y2]));
  Result.x1 := x1 - b.x1;
  Result.y1 := y1 - b.y1;
  Result.x2 := x2 - b.x2;
  Result.y2 := y2 - b.y2;
end;

function ValidMainPointBox(const TPA: TPointArray; const x1, y1, x2, y2: Integer): TBox;overload;
var
  i: Integer;
  b: TBox;
begin
  b := GetTPABounds(TPA);
  Result.x1 := x1 - b.x1;
  Result.y1 := y1 - b.y1;
  Result.x2 := x2 - b.x2;
  Result.y2 := y2 - b.y2;
end;

//MaxToFind, if it's < 1 it won't stop looking
function TFinder.FindDTMs(DTM: TDTMS; out Points: TPointArray; x1, y1, x2, y2, maxToFind: Integer): Boolean;
var
   //Cache DTM stuff
   Len : integer;       //Len of the points

   // Bitwise
   b: Array of Array of Integer;
   ch: array of array of integer;

   // bounds
   W, H: integer;
   MA: TBox;
   MaxX,MaxY : integer; //The maximum value X/Y can take (for subpoints)

   // for loops, etc
   xx, yy: integer;
   i, xxx,yyy: Integer;

   StartX,StartY,EndX,EndY : integer;

   // point count
   pc: Integer;
   Found : boolean;

   goodPoints: Array of Boolean;

   col_arr, tol_arr: Array of Integer;
   ctsinfoarray: TCTSInfoArray;
   compare: TCTSCompareFunction;

    BMP: TDTMBitmap;

   label theEnd;
   label AnotherLoopEnd;


begin
  pc:=0;
  // Is the area valid?
 // DefaultOperations(x1, y1, x2, y2);
  SetLength(FClientTPA,0);

  // Get the area we should search in for the Main Point.
  MA := ValidMainPointBox(DTM, x1, y1, x2, y2);
  //Load the DTM-cache variables
  Len := dtm.points.Count;
  // Turn the bp into a more usable array.
  setlength(goodPoints, Len);
  for i := 0 to Len - 1 do
    goodPoints[i] := not DTM.Points[i].bp;

  // Init data structure b and ch.
  W := x2 - x1;
  H := y2 - y1;

  setlength(b, (W + 1));
  setlength(ch, (W + 1));
  for i := 0 to W do
  begin
    setlength(ch[i], (H + 1));
    FillChar(ch[i][0], SizeOf(Integer) * (H+1), 0);
    setlength(b[i], (H + 1));
    FillChar(b[i][0], SizeOf(Integer) * (H+1), 0);
  end;

  SetLength(col_arr, Len);
  SetLength(tol_arr, Len);

  for i := 0 to Len - 1 do
  begin
    col_arr[i] := DTM.Points[i].color;
    tol_arr[i] := DTM.Points[i].tolerance;
  end;

  ctsinfoarray := Create_CTSInfoArray(col_arr, tol_arr);
  compare := Get_CTSCompare(Self.CTS);

 // cd := CalculateRowPtrs(Target);

  BMP:=Target.CopyBitmap(x1,y1,x2,y2);
  UpdateCachedValues(BMP.Width,BMP.Height);
  //CD starts at 0,0.. We must adjust the MA, since this is still based on the xs,ys,xe,ye box.
  MA.x1 :=  x1;
  MA.y1 :=  y1;
  MA.x2 :=  x2;
  MA.y2 :=  y2;

  MaxX := x2-x1;
  MaxY := y2-y1;
  //MA is now fixed to the new (0,0) box...

  for yy := MA.y1  to MA.y2 - 1  do //Coord of the mainpoint in the search area
    for xx := MA.x1  to MA.x2 - 1 do
    begin
      //Mainpoint can have area size as well, so we must check that just like any subpoint.
      for i := 0 to Len - 1 do
      begin //change to use other areashapes too.
        Found := false;
        //With area it can go out of bounds, therefore this max/min check
        StartX := max(0,xx - Dtm.Points[i].AreaSize + Dtm.Points[i].x);
        StartY := max(0,yy - Dtm.Points[i].AreaSize + Dtm.Points[i].y);
        EndX := Min(MaxX,xx + Dtm.Points[i].AreaSize + Dtm.Points[i].x);
        EndY := Min(MaxY,yy + Dtm.Points[i].AreaSize + Dtm.Points[i].y);
        for xxx := StartX to EndX do //The search area for the subpoint
        begin
          for yyy := StartY to EndY do
          begin
            // If we have not checked this point, check it now.
            if ch[xxx][yyy] and (1 shl i) = 0 then
            begin
              // Checking point i now. (Store that we matched it)
              ch[xxx][yyy]:= ch[xxx][yyy] or (1 shl i);
              if compare(ctsinfoarray[i], BMP.ScanLine[yyy]^[xxx]) then
                b[xxx][yyy] := b[xxx][yyy] or (1 shl i);
            end;

            //Check if the point matches the subpoint
            if (b[xxx][yyy] and (1 shl i) <> 0) then
            begin
              //Check if it was supposed to be a goodpoint..
              if GoodPoints[i] then
              begin
                Found := true;
                break;
              end else //It was not supposed to match!!
                goto AnotherLoopEnd;
            end;
          end;
          if Found then Break; //Optimalisation, we must break out of this second for loop, since we already found the subpoint
        end;
        if (not found) and (GoodPoints[i]) then      //This sub-point wasn't found, while it should.. Exit this mainpoint search
          goto AnotherLoopEnd;
      end;
      //We survived the sub-point search, add this mainpoint to the results.
      ClientTPA[pc] := Point(xx + 3, yy + 2);
      Inc(pc);
      if(pc = maxToFind) then
        goto theEnd;
      AnotherLoopEnd:
    end;
  TheEnd:
  BMP.Free;
  Free_CTSInfoArray(ctsinfoarray);
  //TClient(Client).IOManager.FreeReturnData;

  SetLength(Points, pc);
  if pc > 0 then
    Move(ClientTPA[0], Points[0], pc * SizeOf(TPoint));
  Result := (pc > 0);
//  FreeMem(cd);
end;

function TFinder.FindDTMRotated(DTM: TDTMs; out x, y: Integer; x1, y1, x2, y2: Integer; sAngle, eAngle, aStep: Extended; out aFound: Extended; Alternating : boolean): Boolean;

var
   P: TPointArray;
   F: T2DExtendedArray;
begin
  Result := FindDTMsRotated(dtm, P, x1, y1, x2, y2, sAngle, eAngle, aStep, F,Alternating,1);
  if not result then
      exit;

  aFound := F[0][0];
  x := P[0].x;
  y := P[0].y;
  Exit(True);
end;

procedure RotPoints_DTM(const P: TPointArray;var RotTPA : TPointArray; const A:
    Extended); inline;
var
   I, L: Integer;
begin
  L := High(P);
  for I := 0 to L do
  begin
    RotTPA[I].X := Round(cos(A) * p[i].x  - sin(A) * p[i].y);
    RotTPA[I].Y := Round(sin(A) * p[i].x  + cos(A) * p[i].y);
  end;
end;

function TFinder.FindDTMsRotated(DTM: TDTMs; out Points: TPointArray; x1, y1, x2, y2: Integer; sAngle, eAngle, aStep: Extended; out aFound: T2DExtendedArray;Alternating : boolean; maxToFind: Integer): Boolean;
var
   //Cached variables
   Len : integer;

   DTPA : TPointArray;
   RotTPA: TPointArray;

   // Bitwise
   b: Array of Array of Integer;
   ch: Array of Array of Integer;

   // bounds
   W, H: integer;
   MA: TBox;
   MaxX,MaxY : integer;//The maximum value a (subpoint) can have!

   // for loops, etc
   xx, yy: integer;
   i, xxx,yyy: Integer;
   StartX,StartY,EndX,EndY : integer;

   Found : boolean;

   //If we search alternating, we start in the middle and then +,-,+,- the angle step outwars
   MiddleAngle : extended;
   //Count the amount of anglesteps, mod 2 determines whether it's a + or a - search, and div 2 determines the amount of steps
   //you have to take.
   AngleSteps : integer;

   // point count
   pc: Integer ;

   goodPoints: Array of Boolean;
   s: extended;

   col_arr, tol_arr: Array of Integer;
   ctsinfoarray: TCTSInfoArray;
   compare: TCTSCompareFunction;

   label theEnd;
   label AnotherLoopEnd;


begin
  pc:=0;

  dtm.Normalize;;

  Len := DTM.Points.Count;

  setlength(goodPoints, Len);
  for i := 0 to Len - 1 do
    goodPoints[i] := not DTM.Points[i].bp;

  MaxX := x2 - x1;
  MaxY := y2 - y1;

  // Init data structure B.
  W := x2 - x1;
  H := y2 - y1;
  setlength(b, (W + 1));
  setlength(ch, (W + 1));
  for i := 0 to W do
  begin
    setlength(b[i], (H + 1));
    FillChar(b[i][0], SizeOf(Integer) * (H+1), 0);
    setlength(ch[i], (H + 1));
    FillChar(ch[i][0], SizeOf(Integer) * (H+1), 0);
  end;

  {
  When we search for a rotated DTM, everything is the same, except the coordinates..
  Therefore we create a TPA of the 'original' DTM, containing all the Points.
  This then will be used to rotate the points}
  SetLength(DTPA,len);
  SetLength(RotTPA,len);
  for i := 0 to len-1 do
    DTPA[i] := Point(DTM.Points[i].x,DTM.Points[i].y);

  SetLength(col_arr, Len);
  SetLength(tol_arr, Len);
  // C = DTM.C
  for i := 0 to Len - 1 do
  begin
    col_arr[i] := DTM.Points[i].color;
    tol_arr[i] := DTM.Points[i].Tolerance;
  end;

  ctsinfoarray := Create_CTSInfoArray(col_arr, tol_arr);
  compare := Get_CTSCompare(Self.CTS);

  SetLength(aFound, 0);
  SetLength(Points, 0);
  if Alternating then
  begin
    MiddleAngle := (sAngle + eAngle) / 2.0;
    s := MiddleAngle;  //Start in the middle!
    AngleSteps := 0;
  end else
    s := sAngle;
  while s < eAngle do
  begin
    RotPoints_DTM(DTPA,RotTPA,s);
    //DTMRot now has the same points as the original DTM, just rotated!
    //The other stuff in the structure doesn't matter, as it's the same as the original DTM..
    //So from now on if we want to see what 'point' we're at, use RotTPA, for the rest just use the original DTM
    MA := ValidMainPointBox(RotTPA, x1, y1, x2, y2);
    //CD(ClientData) starts at 0,0.. We must adjust the MA, since this is still based on the xs,ys,xe,ye box.
    MA.x1 := MA.x1 - x1;
    MA.y1 := MA.y1 - y1;
    MA.x2 := MA.x2 - x1;
    MA.y2 := MA.y2 - y1;
    //MA is now fixed to the new (0,0) box...
    for yy := MA.y1  to MA.y2  do //(xx,yy) is now the coord of the mainpoint in the search area
      for xx := MA.x1  to MA.x2 do
      begin
        //Mainpoint can have area size as well, so we must check that just like any subpoint.
        for i := 0 to Len - 1 do
        begin //change to use other areashapes too.
          Found := false;
          //With area it can go out of bounds, therefore this max/min check
          StartX := max(0,xx - DTM.Points[i].AreaSize + RotTPA[i].x);
          StartY := max(0,yy - DTM.Points[i].AreaSize + RotTPA[i].y);
          EndX := Min(MaxX,xx + DTM.Points[i].AreaSize + RotTPA[i].x);
          EndY := Min(MaxY,yy + DTM.Points[i].AreaSize + RotTPA[i].y);
          for xxx := StartX to EndX do //The search area for the subpoint
          begin
            for yyy := StartY to EndY do
            begin
              // If we have not checked this point, check it now.
              if ch[xxx][yyy] and (1 shl i) = 0 then
              begin
                // Checking point i now. (Store that we matched it)
                ch[xxx][yyy]:= ch[xxx][yyy] or (1 shl i);

                if compare(ctsinfoarray[i], Target.ScanLine[yyy]^[xxx]) then
                  b[xxx][yyy] := b[xxx][yyy] or (1 shl i);
              end;

              //Check if the point matches the subpoint
              if (b[xxx][yyy] and (1 shl i) <> 0) then
              begin
                //Check if it was supposed to be a goodpoint..
                if GoodPoints[i] then
                begin
                  Found := true;
                  break;
                end else //It was not supposed to match!!
                  goto AnotherLoopEnd;
              end;
            end;
            if Found then Break; //Optimalisation, we must break out of this second for loop, since we already found the subpoint
          end;
          if (not found) and (GoodPoints[i]) then      //This sub-point wasn't found, while it should.. Exit this mainpoint search
            goto AnotherLoopEnd;
        end;
        //We survived the sub-point search, add this mainpoint to the results.
        Inc(pc);
        setlength(Points,pc);
        Points[pc-1] := Point(xx + x1, yy + y1);
        Setlength(aFound, pc);
        setlength(aFound[pc-1],1);
        aFound[pc-1][0] := s;
        if(pc = maxToFind) then
          goto theEnd;
        AnotherLoopEnd:
      end;
    if Alternating then
    begin
      if AngleSteps mod 2 = 0 then   //This means it's an even number, thus we must add a positive step
        s := MiddleAngle + (aStep * (anglesteps div 2 + 1))  //Angle steps starts at 0, so we must add 1.
      else
        s := MiddleAngle - (aStep * (anglesteps div 2 + 1)); //We must search in the negative direction
      inc(AngleSteps);
    end else
      s := s + aStep;
  end;
  TheEnd:

  Free_CTSInfoArray(ctsinfoarray);

  Result := (pc > 0);
  { Don't forget to pre calculate the rotated points at the start.
   Saves a lot of rotatepoint() calls. }
//  raise Exception.CreateFmt('Not done yet!', []);
end;

end.
