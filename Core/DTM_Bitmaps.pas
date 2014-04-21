unit DTM_Bitmaps;

interface
  uses
   System.Classes,System.SysUtils,Winapi.Windows,Vcl.Graphics,PngImage,Jpeg,GifImg;
  const
    MaxPixelCount = 65536;

  type

   PRGBTriple = ^TRGBTriple;

   pPixelArray = ^TPixelArray;
   TPixelArray = array [0..MaxPixelCount-1] of TRGBTriple;


   TDTMBitmap = class
     private
      FData: pPixelArray;
      FWidth,FHeight: Integer;
      FSize: integer;
      procedure DetectImage(const InputFileName: string;var BM: TBitmap);
      function GetAsString: AnsiString;
      procedure SetAsString(const Value: AnsiString);

      function ColorToRGBTriple(const aColor: TColor):TRGBTriple;
      function RGBTripleToColor(const RGBTriple:  TRGBTriple):  TColor;
      function PointInBitmap(x, y: integer): boolean;
      function GetScanLine(Y: integer): pPixelArray;
      procedure ValidatePoint(x, y: integer);
     public
      constructor Create;
      procedure Reset;
      destructor Destroy;override;
      procedure ToBMP(var BMP: Tbitmap);
      procedure SetSize(Awidth,AHeight: integer);
      procedure RestoreBitmap;
      procedure LoadFromBitmap(Bitmap: TBitmap);overload;
      procedure LoadFromBitmap(Bitmap: HBitmap);overload;
      procedure LoadFromFile(const Filename: string);
      procedure SaveToFile(const FileName: string);
      function FastGetPixel(const X,Y: integer):TColor;
      procedure FastSetColor(const X,Y: Integer; const aColor: TColor);
      procedure FastDrawToCanvas(const X,Y: integer;Canvas: TCanvas);
      function CopyBitmap(const xs, ys, xe, ye: integer):TDTMBitmap;overload;
      function CopyBitmap: TDTMBitmap;overload;
      property Data: pPixelArray read FData write FData;
      property Width: Integer read FWidth write FWidth;
      property Height: integer read FHeight write FHeight;
      property Size: integer read FSize write FSize;
      property AsString: AnsiString read GetAsString write SetAsString;
      property ScanLine[Y: Integer]: PPixelArray read GetScanLine;

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
  System.ZLib,DCPBase64,Math;
 const
 ErrItemNotFound = 'Item not found!';
{ TDTMBitmap }


function TDTMBitmap.ColorToRGBTriple(const aColor: TColor): TRGBTriple;
begin
 with Result do
  begin
     rgbtRed   := GetRValue(aColor);
     rgbtGreen := GetGValue(aColor);
     rgbtBlue  := GetBValue(aColor)
  end;
end;

function TDTMBitmap.CopyBitmap(const xs, ys, xe, ye: integer): TDTMBitmap;
var
  i : integer;
begin
  ValidatePoint(xs,ys);
  ValidatePoint(xe,ye);
  Result := TDTMBitmap.Create;
  Result.SetSize(xe-xs+1,ye-ys+1);
  for i := ys to ye do
    Move(self.FData^[i * self.Width + xs], Result.FData^[(i-ys) * result.Width],result.Width * SizeOf(TRGBTriple));
end;

function TDTMBitmap.CopyBitmap: TDTMBitmap;
begin
  Result := TDTMBitmap.Create;
  Result.SetSize(self.Width, self.Height);
  Move(self.FData^[0], Result.FData^[0],self.width * self.Height * SizeOf(TRGBTriple));
end;

constructor TDTMBitmap.Create;
begin
 FData:=nil;
 Reset;
end;

destructor TDTMBitmap.Destroy;
begin
  SetSize(0,0);

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
    end else
    if FirstBytes = #137'PNG'#13#10#26#10 then
    begin
      Graphic := TPngImage.Create;
    end else
    if Copy(FirstBytes, 1, 3) =  'GIF' then
    begin
      Graphic := TGIFImage.Create;
    end else
    if Copy(FirstBytes, 1, 2) = #$FF#$D8 then
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

procedure TDTMBitmap.FastDrawToCanvas(const X, Y: integer; Canvas: TCanvas);
var
  Bitmap: TBitmap;
  bi : PBITMAPINFO;
begin
  if not Assigned(FData) then exit;
 // Canvas.FillRect(Canvas.ClipRect);
  Bitmap:=TBitmap.Create;
  GetMem(bi, SizeOf(TBitmapInfo));
    try
      ToBMP(Bitmap);
      FillChar(bi^, SizeOf(TBITMAPINFO), 0);
      with bi^.bmiHeader do
      begin
        biSize          := SizeOf(TBITMAPINFOHEADER);
        biWidth         := Bitmap.Width;
        biHeight        := Bitmap.Height;
        biPlanes        := 1;
        biBitCount      := 24;
        biCompression   := BI_RGB;
      end;
      Canvas.FillRect(Bitmap.Canvas.ClipRect);
      SetDIBitsToDevice(Canvas.Handle, X, Y, Bitmap.Width, Bitmap.Height, 0, 0, 0, Bitmap.Height,
                    Bitmap.ScanLine[Bitmap.height - 1], bi^, DIB_PAL_COLORS);
    finally
      FreeMem(bi,SizeOf(TBitmapInfo));
      bitmap.Free
    end;

end;

function TDTMBitmap.FastGetPixel(const X, Y: integer): TColor;
begin
 if not PointInBitmap(X,Y) then
  Result:=clWhite else
 result:=RGBTripleToColor(Data^[y*width+x]);
end;

procedure TDTMBitmap.FastSetColor(const X, Y: Integer; const aColor: TColor);
begin
 Data^[y*width-1+x]:=ColorToRGBTriple(aColor);
end;

function TDTMBitmap.GetAsString: AnsiString;
var
  i : integer;
  DestLen : longword;
  DataStr : ansistring;
  BufferString: Pchar;
begin
  BufferString := StrAlloc(524288);
  SetLength(DataStr,Width*height*SizeOf(TRGBTriple));
  Move(Data^, DataStr[1], (Width * Height - 1) * sizeof(TRGBTriple)+1);
  if compress(pbyte(BufferString),destlen,Pbyte(@DataStr[1]),width*height*SizeOf(TRGBTriple)) = Z_OK then
  begin;
    SetLength(DataStr,DestLen);
    move(bufferstring[0],dataStr[1],DestLen);
    result := 'm' + Base64EncodeStr(datastr);
  end;
  StrDispose(BufferString);
end;


function TDTMBitmap.GetScanLine(Y: integer): pPixelArray;
begin
 Result := @FData^[Y * Width-1];
end;

procedure TDTMBitmap.LoadFromBitmap(Bitmap: TBitmap);
var
  i,j,l: integer;
  Pixels: PPixelArray;
begin
   Reset;
   SetSize(Bitmap.Width,Bitmap.Height);
   l:=width*height-1;
   Bitmap.PixelFormat := pf24bit;
  for i := bitmap.Height - 1 downto 0 do
  begin
   Pixels:=bitmap.ScanLine[i];
   for j :=bitmap.Width - 1  downto 0  do
    begin
     //move(FData,Pixels^,Bitmap.Width);
       FData^[l]:=Pixels[j];
       dec(l);
    end;
  end;
end;

procedure TDTMBitmap.LoadFromBitmap(Bitmap: HBitmap);
var
 Bmp: TBitmap;
begin
 BMP:=TBitmap.Create;
 try
  bmp.Handle:=Bitmap;
  LoadFromBitmap(BMP);
 finally
  bmp.Free;
 end;
end;

procedure TDTMBitmap.LoadFromFile(const Filename: string);
var
 Bmp: TBitmap;
begin
 try
   BMP:=TBitmap.Create;
   DetectImage(Filename,BMP);
   LoadFromBitmap(BMP);
 finally
   Bmp.Free;
 end;

end;

function TDTMBitmap.PointInBitmap(x, y: integer): boolean;
begin
 result := ((x >= 0) and (x < width) and (y >= 0) and (y < height));
end;

procedure TDTMBitmap.Reset;
begin

  SetSize(0,0);

end;

procedure TDTMBitmap.RestoreBitmap;
begin

end;

function TDTMBitmap.RGBTripleToColor(const RGBTriple: TRGBTriple): TColor;
begin
Result:= RGBTriple.rgbtBlue shl 16 + RGBTriple.rgbtGreen shl 8 +
 RGBTriple.rgbtRed;
end;

procedure TDTMBitmap.SaveToFile(const FileName: string);
var
 BMP: TBitmap;
begin
 try
   BMP:=TBitmap.Create;
   ToBMP(BMP);
   //SetDIBitsToBitmap32(BMP,Width,Height,FData);
   BMP.SaveToFile(Filename);
 finally
  BMP.Free;
 end;

end;

procedure TDTMBitmap.SetAsString(const Value: AnsiString);

function HexToInt(HexStr : string) : Int64;
var RetVar : Int64;
    i : byte;
begin
  HexStr := UpperCase(HexStr);
  if HexStr[length(HexStr)] = 'H' then
     Delete(HexStr,length(HexStr),1);
  RetVar := 0;

  for i := 1 to length(HexStr) do begin
      RetVar := RetVar shl 4;
      if HexStr[i] in ['0'..'9'] then
         RetVar := RetVar + (byte(HexStr[i]) - 48)
      else
         if HexStr[i] in ['A'..'F'] then
            RetVar := RetVar + (byte(HexStr[i]) - 55)
         else begin
            Retvar := 0;
            break;
         end;
  end;

  Result := RetVar;
end;

var
  I,II: LongWord;
  DestLen : LongWord;
  Dest,Source : AnsiString;
  DestPoint,Point : PByteArray;
  Raw: pByte;
  Len: integer;
begin
//  Result := CreateBMP(width,height);
  if (Value <> '') and (Length(Value) <> 6) then
  begin
   SetSize(Width,Height);
   pPixelArray(Point):=FData;
    if (Value[1] = 'b') or (Value[1] = 'm') then
    begin;
      Source := Base64DecodeStr(Copy(Value,2,Length(Value) - 1));
      Destlen := Width * Height * SizeOf(TRGBTriple);
      Setlength(Dest,DestLen);
      if uncompress(Pbyte(Dest),Destlen,Pbyte(Source), Length(Source)) = Z_OK then
      begin;
        if Value[1] = 'm' then //Our encrypted bitmap! Winnor.
        begin
         Raw:= @Dest[1];
         Len:=width * height;
          for i := Len  - 1 downto 0 do
          begin
            Data^[I]:=PRGBTriple(@Raw[i*sizeof(TRGBTriple)])^;
          end;
        end else
        if Value[1] = 'b'then
        begin
          DestPoint := @Dest[1];
          i := 0;
          ii := 2;
          Dec(DestLen);
          if DestLen > 2 then
          begin;
            while (ii < DestLen) do
            Begin;
              Point[i]:= DestPoint[ii+2];
              Point[i+1]:= DestPoint[ii+1];
              Point[i+2]:= DestPoint[ii];
              ii := ii + 3;
              i := i + 4;
            end;
            Point[i] := DestPoint[1];
            Point[i+1] := DestPoint[0];
            Point[i+2] := DestPoint[ii];
          end else if (Width = 1) and (Height =1 ) then
          begin;
            Point[0] := DestPoint[1];
            Point[1] := DestPoint[0];
            Point[2] := DestPoint[2];
          end;
        end;
      end;
    end else if Value[1] = 'z' then
    begin;
      Destlen := Width * Height * 3 *2;
      Setlength(Dest,DestLen);
      ii := (Length(Value) - 1) div 2;
      SetLength(Source,ii);
      for i := 1 to ii do
        Source[i] := AnsiChar(HexToInt(Value[i * 2] + Value[i * 2+1]));
      if uncompress(Pbyte(Dest),Destlen,Pbyte(Source), ii) = Z_OK then
      begin;
        ii := 1;
        i := 0;
        while (II < DestLen) do
        begin;
          Point[i+2]:= HexToInt(Dest[ii] + Dest[ii + 1]);
          Point[i+1]:= HexToInt(Dest[ii+2] + Dest[ii + 3]);
          Point[i]:= HexToInt(Dest[ii+4] + Dest[ii + 5]);
          ii := ii + 6;
          i := i + 4;
        end;
      end;
    end else if LongWord(Length(Value)) = LongWord((Width * Height * 3 * 2)) then
    begin;
      ii := 1;
      i := 0;
      Destlen := Width * Height * 3 * 2;
      while (II < DestLen) do
      begin;
        Point[i+2]:= HexToInt(Value[ii] + Value[ii + 1]);
        Point[i+1]:= HexToInt(Value[ii+2] + Value[ii + 3]);
        Point[i]:= HexToInt(Value[ii+4] + Value[ii + 5]);
        ii := ii + 6;
        i := i + 4;
      end;
    end;
  end;
end;

procedure TDTMBitmap.SetSize(Awidth, AHeight: integer);
var
  NewData : pPixelArray;
begin

  if (AWidth <> Width) or (AHeight <> Height) then
  begin
    if AWidth*AHeight <> 0 then
      begin
        GetMem(NewData,AWidth * AHeight * SizeOf(TRGBTriple));
       // FillChar(NewData,AWidth * AHeight * SizeOf(TRGBTriple),0);
      end
    else
      NewData := nil;
    if Assigned(FData) and (Size > 0) then
      FreeMem(FData,Size);
    FData := NewData;
    Width := AWidth;
    Height := AHeight;
    Size:= Width * Height * SizeOf(TRGBTriple);
  end;
end;

procedure TDTMBitmap.ToBMP(var BMP: Tbitmap);
var
 i,j,dd: integer;
 Pixels: pPixelArray;
begin
   dd:=width*height-1;
   bmp.PixelFormat := pf24bit;
   bmp.Width  := width;
   bmp.Height := height;
  for i := Bmp.Height - 1 downto 0 do
  begin
   Pixels:=Bmp.ScanLine[i];
  // move(Pixels,FData^[I*Width],Width);
   for j :=Bmp.Width - 1  downto 0  do
    begin
    Pixels[j]:=FData^[dd];
    dec(DD);
    end;
  end;
end;

procedure TDTMBitmap.ValidatePoint(x, y: integer);
begin
  if not(PointInBitmap(x,y)) then
    raise Exception.CreateFmt('You are accessing an invalid point, (%d,%d) at bitmap',[x,y]);
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
  I: Integer;
begin
  Clear;
  for I := 0 to Src.Count - 1 do
    Add(Src[I]);
end;

procedure TDTMBitmapList.Clear;
var
  I: Integer;
begin
  for I := 0 to FBitmaps.Count - 1 do
    Bitmap[I].Free;
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
