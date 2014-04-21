unit DTM_ImageCatcher;

interface
  uses
   System.Classes,System.SysUtils,Vcl.Controls,Vcl.Graphics,
    Vcl.Forms,Winapi.Windows,Winapi.D3DX9,Direct3D9,DirectDraw;

  type
    TCatchType = (ctWinapi = 0,ctDirectX = 1,ctDDraw = 2);
    TImageCatcher = class
      private
        FBitmap: Vcl.Graphics.TBITMAP;
        FCatchType: TCatchType;
        FTargetHandle: HWND;
        procedure GetTargetRect(out Rect: TRect);
        procedure GetDDrawData();
        procedure GetDirectXData();
        procedure GetWinapiData();
        procedure GetTargetDimensions(out w, h: integer);
        procedure GetTargetPosition(out left, top: integer);
      public
        constructor Create;
        procedure Reset;
        destructor Destroy;override;

        procedure GetScreenShot();
        procedure ActivateTarget;
        property Bitmap: Vcl.Graphics.TBITMAP read FBitmap write FBitmap;
        property CatchType: TCatchType read FCatchType write FCatchType;
        property TargetHandle: HWND read FTargetHandle write FTargetHandle;
    end;
implementation

{ TImageCather }

procedure TImageCatcher.ActivateTarget;
begin
  SetForegroundWindow(TargetHandle);
end;

constructor TImageCatcher.Create;
begin
  Reset;
  FBitmap := Vcl.Graphics.TBitmap.Create;
  FBitmap.PixelFormat := pf24bit;
end;

destructor TImageCatcher.Destroy;
begin
  FreeAndNil(FBitmap);
  inherited;
end;

procedure TImageCatcher.GetDDrawData();
var
  DDSCaps: TDDSCaps;
  DesktopDC: HDC;
  DirectDraw: IDirectDraw;
  Surface: IDirectDrawSurface;
  SurfaceDesc: TDDSurfaceDesc;
  x, y, w, h: integer;
begin
  GetTargetDimensions(w, h);
  GetTargetPosition(x, y);
  if DirectDrawCreate(nil, DirectDraw, nil) = DD_OK then
    if DirectDraw.SetCooperativeLevel(GetDesktopWindow, DDSCL_EXCLUSIVE or DDSCL_FULLSCREEN or DDSCL_ALLOWREBOOT) = DD_OK then
    begin
      FillChar(SurfaceDesc, SizeOf(SurfaceDesc), 0);
      SurfaceDesc.dwSize := Sizeof(SurfaceDesc);
      SurfaceDesc.dwFlags := DDSD_CAPS;
      SurfaceDesc.ddsCaps.dwCaps := DDSCAPS_PRIMARYSURFACE;
      SurfaceDesc.dwBackBufferCount := 0;
      if DirectDraw.CreateSurface(SurfaceDesc, Surface, nil) = DD_OK then
      begin
        if Surface.GetDC(DesktopDC) = DD_OK then
          try
            Bitmap.Width := Screen.Width;
            Bitmap.Height := Screen.Height;
            BitBlt(Bitmap.Canvas.Handle, 0, 0, W, H, DesktopDC, x, y, SRCCOPY);
          finally
            Surface.ReleaseDC(DesktopDC);
          end;
      end;
    end;
end;

procedure TImageCatcher.GetDirectXData();
var
  BitsPerPixel: Byte;
  pD3D: IDirect3D9;
  pSurface: IDirect3DSurface9;
  g_pD3DDevice: IDirect3DDevice9;
  D3DPP: TD3DPresentParameters;
  ARect: TRect;
  LockedRect: TD3DLockedRect;
  BMP: VCL.Graphics.TBitmap;
  i, p: Integer;
  x, y: integer;
  w, h: integer;
begin
  GetTargetDimensions(w, h);
  GetTargetPosition(x, y);
  BitsPerPixel := 32;
  FillChar(d3dpp, SizeOf(d3dpp), 0);
  with D3DPP do
  begin
    Windowed := True;
    Flags := D3DPRESENTFLAG_LOCKABLE_BACKBUFFER;
    SwapEffect := D3DSWAPEFFECT_DISCARD;
    BackBufferWidth := Screen.Width;
    BackBufferHeight := Screen.Height;
    BackBufferFormat := D3DFMT_X8R8G8B8;
  end;
  pD3D := Direct3DCreate9(D3D_SDK_VERSION);
  pD3D.CreateDevice(D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, GetDesktopWindow, D3DCREATE_SOFTWARE_VERTEXPROCESSING, @ D3DPP, g_pD3DDevice);
  g_pD3DDevice.CreateOffscreenPlainSurface(Screen.Width, Screen.Height, D3DFMT_A8R8G8B8, D3DPOOL_SCRATCH, pSurface, nil);
  g_pD3DDevice.GetFrontBufferData(0, pSurface);
  ARect := Screen.DesktopRect;
  pSurface.LockRect(LockedRect, @ ARect, D3DLOCK_NO_DIRTY_UPDATE or D3DLOCK_NOSYSLOCK or D3DLOCK_READONLY);
  BMP := VCL.Graphics.TBitmap.Create;
  try
  BMP.Width := Screen.Width;
  BMP.Height := Screen.Height;
  case BitsPerPixel of
    8: BMP.PixelFormat := pf8bit;
    16: BMP.PixelFormat := pf16bit;
    24: BMP.PixelFormat := pf24bit;
    32: BMP.PixelFormat := pf32bit;
  end;
  p := Cardinal(LockedRect.pBits);
  for i := 0 to Screen.Height - 1 do
  begin
    CopyMemory(BMP.ScanLine[i], Ptr(p), Screen.Width * BitsPerPixel div 8);
    p := p + LockedRect.Pitch;
  end;
  Bitmap.SetSize(w, h);
  BitBlt(Bitmap.Canvas.Handle, 0, 0, w, h, BMP.Canvas.Handle, x, y, SRCCOPY);
  finally
    BMP.Free;
    pSurface.UnlockRect;
  end;
end;

procedure TImageCatcher.GetScreenShot();
begin
  case CatchType of
    ctWinapi: GetWinapiData();
    ctDirectX: GetDirectXData();
    ctDDraw: GetDDrawData();
  end;
  SetForegroundWindow(Application.Handle);
end;

procedure TImageCatcher.GetTargetDimensions(out w, h: integer);
var
  Rect: TRect;
begin
  GetTargetRect(rect);
  w := Rect.Right - Rect.Left;
  h := Rect.Bottom - Rect.Top;
end;

procedure TImageCatcher.GetTargetPosition(out left, top: integer);
var
  Rect: TRect;
begin
  GetTargetRect(rect);
  left := Rect.Left;
  top := Rect.Top;
end;

procedure TImageCatcher.GetTargetRect(out Rect: TRect);
begin
  GetWindowRect(TargetHandle, Rect);
end;

procedure TImageCatcher.Reset;
begin
  CatchType := ctDirectX;
  TargetHandle := 0;
end;

procedure TImageCatcher.GetWinapiData();
var
  hWinDC: THandle;
  w, h: integer;
begin
  GetTargetDimensions(w, h);
  hWinDC := GetWindowDC(TargetHandle);
  Bitmap.Width := w;
  Bitmap.Height := h;
  hWinDC := GetWindowDC(TargetHandle);
  BitBlt(Bitmap.Canvas.Handle, 0, 0, Bitmap.Width, Bitmap.Height, hWinDC, 0, 0, SRCCOPY);
  ReleaseDC(TargetHandle, hWinDC);
end;

end.
