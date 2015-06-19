unit DTM_Bitmaps;

interface

uses
  System.Classes, System.SysUtils, Winapi.Windows, Vcl.Graphics, PngImage, Jpeg,
  GifImg;

const
  MaxPixelCount = 65536;

type

  PRGBTriple = ^TRGBTriple;

  pPixelArray = ^TPixelArray;
  TPixelArray = array [0 .. MaxPixelCount - 1] of TRGBTriple;

  TDTMBitmap = class
  private
    FData: pPixelArray;
    FWidth, FHeight: Integer;
    FSize: Integer;
    procedure DetectImage(const InputFileName: string; var BM: TBitmap);
    function GetAsString: AnsiString;
    procedure SetAsString(const Value: AnsiString);

    function ColorToRGBTriple(const aColor: TColor): TRGBTriple;
    function RGBTripleToColor(const RGBTriple: TRGBTriple): TColor;
    function PointInBitmap(x, y: Integer): boolean;
    function GetScanLine(y: Integer): pPixelArray;
    procedure ValidatePoint(x, y: Integer);
  public
    constructor Create;
    procedure Reset;
    destructor Destroy; override;
    procedure ToBMP(var BMP: TBitmap);
    procedure SetSize(Awidth, AHeight: Integer);
    procedure RestoreBitmap;
    procedure LoadFromBitmap(Bitmap: TBitmap); overload;
    procedure LoadFromBitmap(Bitmap: HBitmap); overload;
    procedure LoadFromFile(const Filename: string);
    procedure SaveToFile(const Filename: string);
    function FastGetPixel(const x, y: Integer): TColor;
    procedure FastSetColor(const x, y: Integer; const aColor: TColor);
    procedure FastDrawToCanvas(const x, y: Integer; Canvas: TCanvas);
    function CopyBitmap(const xs, ys, xe, ye: Integer): TDTMBitmap; overload;
    function CopyBitmap: TDTMBitmap; overload;
    property Data: pPixelArray read FData write FData;
    property Width: Integer read FWidth write FWidth;
    property Height: Integer read FHeight write FHeight;
    property Size: Integer read FSize write FSize;
    property AsString: AnsiString read GetAsString write SetAsString;
    property ScanLine[y: Integer]: pPixelArray read GetScanLine;

  end;

  TDTMBitmapList = class
  private
    FBitmaps: TList;
    function GetCount: Integer;
    function GeTDTMBitmap(Index: Integer): TDTMBitmap;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Add(aGhost: TDTMBitmap);
    procedure Assign(Src: TDTMBitmapList);
    function IndexOf(aItem: TDTMBitmap): Integer;
    procedure Delete(Index: Integer); overload;
    procedure Delete(aItem: TDTMBitmap); overload;

    property Count: Integer read GetCount;
    property Bitmap[Index: Integer]: TDTMBitmap read GeTDTMBitmap; default;
  end;

implementation

uses
  System.ZLib, DCPBase64, Math;

const
  ErrItemNotFound = 'Item not found!';
  { TDTMBitmap }

function TDTMBitmap.ColorToRGBTriple(const aColor: TColor): TRGBTriple;
begin
  with Result do
  begin
    rgbtRed := GetRValue(aColor);
    rgbtGreen := GetGValue(aColor);
    rgbtBlue := GetBValue(aColor)
  end;
end;

function TDTMBitmap.CopyBitmap(const xs, ys, xe, ye: Integer): TDTMBitmap;
var
  i: Integer;
begin
  ValidatePoint(xs, ys);
  ValidatePoint(xe, ye);
  Result := TDTMBitmap.Create;
  Result.SetSize(xe - xs + 1, ye - ys + 1);
  for i := ys to ye do
    Move(self.FData^[i * self.Width + xs],
      Result.FData^[(i - ys) * Result.Width],
      Result.Width * SizeOf(TRGBTriple));
end;

function TDTMBitmap.CopyBitmap: TDTMBitmap;
begin
  Result := TDTMBitmap.Create;
  Result.SetSize(self.Width, self.Height);
  Move(self.FData^[0], Result.FData^[0], self.Width * self.Height *
    SizeOf(TRGBTriple));
end;

constructor TDTMBitmap.Create;
begin
  FData := nil;
  Reset;
end;

destructor TDTMBitmap.Destroy;
begin
  SetSize(0, 0);

  inherited;
end;

procedure TDTMBitmap.DetectImage(const InputFileName: string; var BM: TBitmap);
var
  FS: TFileStream;
  FirstBytes: AnsiString;
  Graphic: TGraphic;
begin
  Graphic := nil;
  FS := TFileStream.Create(InputFileName, fmOpenRead);
  try
    SetLength(FirstBytes, 8);
    FS.Read(FirstBytes[1], 8);
    if Copy(FirstBytes, 1, 2) = 'BM' then
    begin
      Graphic := TBitmap.Create;
    end
    else if FirstBytes = #137'PNG'#13#10#26#10 then
    begin
      Graphic := TPngImage.Create;
    end
    else if Copy(FirstBytes, 1, 3) = 'GIF' then
    begin
      Graphic := TGIFImage.Create;
    end
    else if Copy(FirstBytes, 1, 2) = #$FF#$D8 then
    begin
      Graphic := TJPEGImage.Create;
    end;
    if Assigned(Graphic) then
    begin
      try
        FS.Seek(0, soFromBeginning);
        Graphic.LoadFromStream(FS);
        BM.Assign(Graphic);
      except
      end;
      Graphic.Free;
    end;
  finally
    FS.Free;
  end;
end;

procedure TDTMBitmap.FastDrawToCanvas(const x, y: Integer; Canvas: TCanvas);
var
  Bitmap: TBitmap;
  bi: PBITMAPINFO;
begin
  if not Assigned(FData) then
    exit;
  // Canvas.FillRect(Canvas.ClipRect);
  Bitmap := TBitmap.Create;
  GetMem(bi, SizeOf(TBitmapInfo));
  try
    ToBMP(Bitmap);
    FillChar(bi^, SizeOf(TBitmapInfo), 0);
    with bi^.bmiHeader do
    begin
      biSize := SizeOf(TBITMAPINFOHEADER);
      biWidth := Bitmap.Width;
      biHeight := Bitmap.Height;
      biPlanes := 1;
      biBitCount := 24;
      biCompression := BI_RGB;
    end;
    Canvas.FillRect(Bitmap.Canvas.ClipRect);
    SetDIBitsToDevice(Canvas.Handle, x, y, Bitmap.Width, Bitmap.Height, 0, 0, 0,
      Bitmap.Height, Bitmap.ScanLine[Bitmap.Height - 1], bi^, DIB_PAL_COLORS);
  finally
    FreeMem(bi, SizeOf(TBitmapInfo));
    Bitmap.Free
  end;

end;

function TDTMBitmap.FastGetPixel(const x, y: Integer): TColor;
begin
  if not PointInBitmap(x, y) then
    Result := clWhite
  else
    Result := RGBTripleToColor(Data^[y * Width + x]);
end;

procedure TDTMBitmap.FastSetColor(const x, y: Integer; const aColor: TColor);
begin
  Data^[y * Width + x] := ColorToRGBTriple(aColor);
end;

function TDTMBitmap.GetAsString: AnsiString;
var
  i: Integer;
  DestLen: longword;
  DataStr: AnsiString;
  BufferString: Pchar;
begin
  BufferString := StrAlloc(524288);
  SetLength(DataStr, Width * Height * SizeOf(TRGBTriple));
  Move(Data^, DataStr[1], (Width * Height - 1) * SizeOf(TRGBTriple) + 1);
  if compress(pbyte(BufferString), DestLen, pbyte(@DataStr[1]),
    Width * Height * SizeOf(TRGBTriple)) = Z_OK then
  begin;
    SetLength(DataStr, DestLen);
    Move(BufferString[0], DataStr[1], DestLen);
    Result := 'm' + Base64EncodeStr(DataStr);
  end;
  StrDispose(BufferString);
end;

function TDTMBitmap.GetScanLine(y: Integer): pPixelArray;
begin
  Result := @FData^[y * Width - 1];
end;

procedure TDTMBitmap.LoadFromBitmap(Bitmap: TBitmap);
var
  i, j, l: Integer;
  Pixels: pPixelArray;
begin
  Reset;
  SetSize(Bitmap.Width, Bitmap.Height);
  l := Width * Height - 1;
  Bitmap.PixelFormat := pf24bit;
  for i := Bitmap.Height - 1 downto 0 do
  begin
    Pixels := Bitmap.ScanLine[i];
    for j := Bitmap.Width - 1 downto 0 do
    begin
      // move(FData,Pixels^,Bitmap.Width);
      FData^[l] := Pixels[j];
      dec(l);
    end;
  end;
end;

procedure TDTMBitmap.LoadFromBitmap(Bitmap: HBitmap);
var
  BMP: TBitmap;
begin
  BMP := TBitmap.Create;
  try
    BMP.Handle := Bitmap;
    LoadFromBitmap(BMP);
  finally
    BMP.Free;
  end;
end;

procedure TDTMBitmap.LoadFromFile(const Filename: string);
var
  BMP: TBitmap;
begin
  try
    BMP := TBitmap.Create;
    DetectImage(Filename, BMP);
    LoadFromBitmap(BMP);
  finally
    BMP.Free;
  end;

end;

function TDTMBitmap.PointInBitmap(x, y: Integer): boolean;
begin
  Result := ((x >= 0) and (x < Width) and (y >= 0) and (y < Height));
end;

procedure TDTMBitmap.Reset;
begin

  SetSize(0, 0);

end;

procedure TDTMBitmap.RestoreBitmap;
begin

end;

function TDTMBitmap.RGBTripleToColor(const RGBTriple: TRGBTriple): TColor;
begin
  Result := RGBTriple.rgbtBlue shl 16 + RGBTriple.rgbtGreen shl 8 +
    RGBTriple.rgbtRed;
end;

procedure TDTMBitmap.SaveToFile(const Filename: string);
var
  BMP: TBitmap;
begin
  try
    BMP := TBitmap.Create;
    ToBMP(BMP);
    // SetDIBitsToBitmap32(BMP,Width,Height,FData);
    BMP.SaveToFile(Filename);
  finally
    BMP.Free;
  end;

end;

procedure TDTMBitmap.SetAsString(const Value: AnsiString);

  function HexToInt(HexStr: string): Int64;
  var
    RetVar: Int64;
    i: byte;
  begin
    HexStr := UpperCase(HexStr);
    if HexStr[length(HexStr)] = 'H' then
      Delete(HexStr, length(HexStr), 1);
    RetVar := 0;

    for i := 1 to length(HexStr) do
    begin
      RetVar := RetVar shl 4;
      if HexStr[i] in ['0' .. '9'] then
        RetVar := RetVar + (byte(HexStr[i]) - 48)
      else if HexStr[i] in ['A' .. 'F'] then
        RetVar := RetVar + (byte(HexStr[i]) - 55)
      else
      begin
        RetVar := 0;
        break;
      end;
    end;

    Result := RetVar;
  end;

var
  i, II: longword;
  DestLen: longword;
  Dest, Source: AnsiString;
  DestPoint, Point: PByteArray;
  Raw: pbyte;
  Len: Integer;
begin
  // Result := CreateBMP(width,height);
  if (Value <> '') and (length(Value) <> 6) then
  begin
    SetSize(Width, Height);
    pPixelArray(Point) := FData;
    if (Value[1] = 'b') or (Value[1] = 'm') then
    begin;
      Source := Base64DecodeStr(Copy(Value, 2, length(Value) - 1));
      DestLen := Width * Height * SizeOf(TRGBTriple);
      SetLength(Dest, DestLen);
      if uncompress(pbyte(Dest), DestLen, pbyte(Source), length(Source)) = Z_OK
      then
      begin;
        if Value[1] = 'm' then // Our encrypted bitmap! Winnor.
        begin
          Raw := @Dest[1];
          Len := Width * Height;
          for i := Len - 1 downto 0 do
          begin
            Data^[i] := PRGBTriple(@Raw[i * SizeOf(TRGBTriple)])^;
          end;
        end
        else if Value[1] = 'b' then
        begin
          DestPoint := @Dest[1];
          i := 0;
          II := 2;
          dec(DestLen);
          if DestLen > 2 then
          begin;
            while (II < DestLen) do
            Begin;
              Point[i] := DestPoint[II + 2];
              Point[i + 1] := DestPoint[II + 1];
              Point[i + 2] := DestPoint[II];
              II := II + 3;
              i := i + 4;
            end;
            Point[i] := DestPoint[1];
            Point[i + 1] := DestPoint[0];
            Point[i + 2] := DestPoint[II];
          end
          else if (Width = 1) and (Height = 1) then
          begin;
            Point[0] := DestPoint[1];
            Point[1] := DestPoint[0];
            Point[2] := DestPoint[2];
          end;
        end;
      end;
    end
    else if Value[1] = 'z' then
    begin;
      DestLen := Width * Height * 3 * 2;
      SetLength(Dest, DestLen);
      II := (length(Value) - 1) div 2;
      SetLength(Source, II);
      for i := 1 to II do
        Source[i] := AnsiChar(HexToInt(Value[i * 2] + Value[i * 2 + 1]));
      if uncompress(pbyte(Dest), DestLen, pbyte(Source), II) = Z_OK then
      begin;
        II := 1;
        i := 0;
        while (II < DestLen) do
        begin;
          Point[i + 2] := HexToInt(Dest[II] + Dest[II + 1]);
          Point[i + 1] := HexToInt(Dest[II + 2] + Dest[II + 3]);
          Point[i] := HexToInt(Dest[II + 4] + Dest[II + 5]);
          II := II + 6;
          i := i + 4;
        end;
      end;
    end
    else if longword(length(Value)) = longword((Width * Height * 3 * 2)) then
    begin;
      II := 1;
      i := 0;
      DestLen := Width * Height * 3 * 2;
      while (II < DestLen) do
      begin;
        Point[i + 2] := HexToInt(Value[II] + Value[II + 1]);
        Point[i + 1] := HexToInt(Value[II + 2] + Value[II + 3]);
        Point[i] := HexToInt(Value[II + 4] + Value[II + 5]);
        II := II + 6;
        i := i + 4;
      end;
    end;
  end;
end;

procedure TDTMBitmap.SetSize(Awidth, AHeight: Integer);
var
  NewData: pPixelArray;
begin

  if (Awidth <> Width) or (AHeight <> Height) then
  begin
    if Awidth * AHeight <> 0 then
    begin
      GetMem(NewData, Awidth * AHeight * SizeOf(TRGBTriple));
      // FillChar(NewData,AWidth * AHeight * SizeOf(TRGBTriple),0);
    end
    else
      NewData := nil;
    if Assigned(FData) and (Size > 0) then
      FreeMem(FData, Size);
    FData := NewData;
    Width := Awidth;
    Height := AHeight;
    Size := Width * Height * SizeOf(TRGBTriple);
  end;
end;

procedure TDTMBitmap.ToBMP(var BMP: TBitmap);
var
  i, j, dd: Integer;
  Pixels: pPixelArray;
begin
  dd := Width * Height - 1;
  BMP.PixelFormat := pf24bit;
  BMP.Width := Width;
  BMP.Height := Height;
  for i := BMP.Height - 1 downto 0 do
  begin
    Pixels := BMP.ScanLine[i];
    // move(Pixels,FData^[I*Width],Width);
    for j := BMP.Width - 1 downto 0 do
    begin
      Pixels[j] := FData^[dd];
      dec(dd);
    end;
  end;
end;

procedure TDTMBitmap.ValidatePoint(x, y: Integer);
begin
  if not(PointInBitmap(x, y)) then
    raise Exception.CreateFmt
      ('You are accessing an invalid point, (%d,%d) at bitmap', [x, y]);
end;

{ TDTMBitmapList }

constructor TDTMBitmapList.Create;
begin
  FBitmaps := TList.Create;
end;

procedure TDTMBitmapList.Delete(Index: Integer);
begin
  if (Index < 0) or (Index >= Count) then
    raise Exception.Create(ErrItemNotFound);

  TDTMBitmap(FBitmaps[Index]).Free;
  FBitmaps.Delete(Index);
end;

procedure TDTMBitmapList.Delete(aItem: TDTMBitmap);
begin
  Delete(IndexOf(aItem));
end;

destructor TDTMBitmapList.Destroy;
begin
  Clear;
  FBitmaps.Free;
  inherited;
end;

procedure TDTMBitmapList.Add(aGhost: TDTMBitmap);
begin
  FBitmaps.Add(aGhost)
end;

procedure TDTMBitmapList.Assign(Src: TDTMBitmapList);
var
  i: Integer;
begin
  Clear;
  for i := 0 to Src.Count - 1 do
    Add(Src[i]);
end;

procedure TDTMBitmapList.Clear;
var
  i: Integer;
begin
  for i := 0 to FBitmaps.Count - 1 do
    Bitmap[i].Free;
  FBitmaps.Clear;
end;

function TDTMBitmapList.GetCount: Integer;
begin
  Result := FBitmaps.Count;
end;

function TDTMBitmapList.GeTDTMBitmap(Index: Integer): TDTMBitmap;
begin
  if (Index >= 0) and (Index < Count) then
    Result := TDTMBitmap(FBitmaps[Index])
  else
    Result := nil;
end;

function TDTMBitmapList.IndexOf(aItem: TDTMBitmap): Integer;
begin
  Result := FBitmaps.IndexOf(aItem);
end;

end.
