unit DTM_Controls;

interface

uses Windows, SysUtils, Classes, Controls, StdCtrls, ExtCtrls, Graphics,
     Dialogs;

type
  TksGridOrdering = (go16x1, go8x2, go4x4, go2x8, go1x16);

  TDTMColorGrid = class(TGraphicControl)
  private
//    FPaletteEntries: array[0..NumPaletteEntries - 1] of TPaletteEntry;
//    FColorIndex: Integer;
//    FSelection: Integer;
    FCellXSize, FCellYSize: Integer;
    FNumXSquares, FNumYSquares: Integer;
    FGridOrdering: TksGridOrdering;
    FOnChange: TNotifyEvent;
    FButton: TMouseButton;
    FCaption: string;
    FButtonCaption: string;
    FButtonDown: Boolean;
    FCaptionSize: Integer;
    FButtonSize: Integer;
    FCtrlColor: TColor;
    FColor: TColor;
    FFlat: Boolean;
    FColorDialog: TColorDialog;
    procedure DrawSquare(Which: Integer);
    procedure DrawFgBg;
    procedure UpdateCellSizes;
    procedure SetCaption( Value: string);
    procedure SetButtonCaption( Value: string);
    procedure SetGridOrdering(Value: TksGridOrdering);
    procedure SetColorIndex(Value: Integer);
    function GetCtrlColor: TColor;
    procedure SetCtrlColor( Value: TColor);
//    procedure SetSelection(Value: Integer);
    procedure SetColor( Value: TColor);
    procedure SetCaptionSize( Value: Integer);
    procedure SetButtonSize( Value: Integer);
//    procedure WMSize(var Message: TWMSize); message WM_SIZE;
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure Paint; override;
    procedure Change; dynamic;
    function SquareFromPos(X, Y: Integer): Integer;
  public
    constructor Create(AOwner: TComponent); override;
//    function ColorToIndex(AColor: TColor): Integer;
//    property SelectedColor: TColor read GetForegroundColor;
//    property Color: TColor read FColor write SetColor;
  published
    property ButtonCaption: string read FButtonCaption write SetButtonCaption;
    property ButtonSize: Integer read FButtonSize write SetButtonSize;
    property Caption: string read FCaption write SetCaption;
    property CaptionSize: Integer read FCaptionSize write SetCaptionSize;
    property ColorDialog: TColorDialog read FColorDialog write FColorDialog;
    property Color: TColor read FColor write SetColor;
    property CtrlColor: TColor read GetCtrlColor write SetCtrlColor;
    property DragCursor;
    property DragMode;
    property Enabled;
    property GridOrdering: TksGridOrdering read FGridOrdering write SetGridOrdering default go16x1;
    property Font;
    property ParentFont;
    property ParentShowHint;
    property PopUpMenu;
//    property Selection: Integer read FSelection write SetSelection default 0;
    property ShowHint;
    property Visible;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnStartDrag;
  end;

type
  TDTMColorComboBox = class(TCustomComboBox)
  private
    FColor: TColor;
    function GetColor: TColor;
    procedure SetColor( AValue: TColor);
    function GetCtrlColor: TColor;
    procedure SetCtrlColor( Value: TColor);
    procedure FixItemIndex;
  protected
    procedure Loaded; override;
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Color: TColor read GetColor write SetColor default clBlack;
    property CtrlColor: TColor read GetCtrlColor write SetCtrlColor;
    property Ctl3D;
    property DragMode;
    property DragCursor;
    property Enabled;
    property Font;
    property ImeMode;
    property ImeName;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnChange;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnDropDown;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnStartDrag;
  end;

implementation

// Default colors

const
  DefaultColorsCount = 16;
  DefaultColors: array [0..DefaultColorsCount-1] of TColor = (
    clBlack, clMaroon, clGreen, clOlive, clNavy, clPurple, clTeal, clGray,
    clSilver, clRed, clLime, clYellow, clBlue, clFuchsia, clAqua, clWhite);

function ColorToIndex( Value: TColor): Integer;
var
  I: Integer;

begin
  for I:= 0 to DefaultColorsCount-1 do begin
    if DefaultColors[I]=Value then begin
      Result:= I;
      Exit;
    end;
  end;
  Result:= -1;
end;

function InvertColor( Value: TColor): TColor;
var
  PalEntry0: TPaletteEntry absolute Value;
  PalEntry1: TPaletteEntry absolute Result;

  function GetIt( Value: Byte): Byte;
  begin
    if Value>=$80 then Result:= 0 else Result:= $FF;
  end;

begin
  with PalEntry1 do begin
    peRed:= GetIt( PalEntry0.peRed);
    peGreen:= GetIt( PalEntry0.peGreen);
    peBlue:= GetIt( PalEntry0.peBlue);
    peFlags:= 0;
  end;
end;

// TksColorGrid

constructor TDTMColorGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  FGridOrdering := go16x1;
  FNumXSquares := 16;
  FNumYSquares := 1;
  inherited Color:= clBtnFace;
  Canvas.Brush.Style := bsSolid;
  Canvas.Pen.Color := clBlack;
  SetBounds(0, 0, 400, 20);
  FCaptionSize:= 50;
  FButtonSize:= 50;
  FButtonCaption:= 'More ...';
//  GetPaletteEntries(GetStockObject(DEFAULT_PALETTE), 0, NumPaletteEntries,
//    FPaletteEntries);
  UpdateCellSizes;
end;

procedure TDTMColorGrid.SetColor( Value: TColor);
begin
  if Value=FColor then Exit;
  FColor:= Value;
  Invalidate;
  Change;
end;

function TDTMColorGrid.GetCtrlColor: TColor;
begin
  Result:= inherited Color;
end;

procedure TDTMColorGrid.SetCtrlColor( Value: TColor);
begin
  inherited Color:= Value;
end;

procedure TDTMColorGrid.DrawSquare(Which: Integer);// ShowSelector: Boolean);
var
  WinTop, WinLeft: Integer;
//  PalIndex: Integer;
  CellRect: TRect;

begin
  if (Which >=0) and (Which <= 15) then begin
//    if Which < 8 then PalIndex := Which
//    else PalIndex := Which + 4;
    WinTop:= (Which div FNumXSquares) * FCellYSize;
    WinLeft:= (Which mod FNumXSquares) * FCellXSize + FCaptionSize;
    CellRect:= Bounds(WinLeft, WinTop+1, FCellXSize, FCellYSize-2);
    if {Ctl3D} not FFlat then begin
      Canvas.Pen.Color := clBtnFace;
//      InflateRect(CellRect, -1, -1);
      with CellRect do Canvas.Rectangle(Left, Top, Right, Bottom);
      InflateRect(CellRect, -1, -1);
      Frame3D(Canvas, CellRect, clBtnShadow, clBtnHighlight, 1);
    end
    else Canvas.Pen.Color:= clBlack;
    Canvas.Brush.Color:= DefaultColors[Which];
//    with FPaletteEntries[PalIndex] do
//    begin
//      Canvas.Brush.Color := TColor(RGB(peRed, peGreen, peBlue));
//      if {Ctl3D} not FFlat then Canvas.Pen.Color := TColor(RGB(peRed, peGreen, peBlue));
//    end;
//    with CellRect do Canvas.Rectangle(Left, Top, Right, Bottom);
    Canvas.FillRect( CellRect);
  end;
end;

procedure TDTMColorGrid.DrawFgBg;
var
  TextColor: TPaletteEntry;
  Index: Integer;
  TheText: string;
  OldBkMode: Integer;
  R: TRect;
  Points: array[0..3] of TPoint;
  hrgn1: HRGN;

begin
//  OldBkMode := SetBkMode(Canvas.Handle, TRANSPARENT);
  Index:= ColorToIndex( FColor);
  if Index>=0 then begin
    Canvas.Brush.Color:= InvertColor( FColor);
    with R do begin
      left:= (Index mod FNumXSquares) * FCellXSize + FCaptionSize;
      right:= left + FCellXSize;
      top:= (Index div FNumXSquares) * FCellYSize;
      bottom:= top + FCellYSize;
    end;
    InflateRect( R, -(FCellXSize div 3), -(FCellYSize div 3));
    Points[0].X:= R.Left;
    Points[0].Y:= (R.Top+R.Bottom) div 2;
    Points[1].X:= (R.Left+R.Right) div 2;
    Points[1].Y:= R.Top;
    Points[2].X:= R.Right;
    Points[2].Y:= (R.Top+R.Bottom) div 2;
    Points[3].X:= (R.Left+R.Right) div 2;
    Points[3].Y:= R.Bottom;
    hrgn1:= CreatePolygonRgn( Points, 4, WINDING);
    FillRgn( Canvas.Handle, hrgn1, Canvas.Brush.Handle);
    DeleteObject( hrgn1);
  end;
  Canvas.Brush.Color:= clBtnFace;
  Canvas.Pen.Style:= psClear;
  if FCaptionSize>0 then begin
    R:= ClientRect;
    R.Right:= FCaptionSize;
    InflateRect( R, -1, -1);
    with R do Canvas.Rectangle( Left, Top, Right, Bottom);
    DrawText(Canvas.Handle, PChar(Caption), -1, R,
       DT_NOCLIP or DT_SINGLELINE or DT_CENTER or DT_VCENTER);
  end;
  if FButtonSize>0 then begin
    R:= ClientRect;
    R.Left:= FCaptionSize+FCellXSize*FNumXSquares;
    InflateRect( R, -1, -1);
    with R do Canvas.Rectangle( Left, Top, Right, Bottom);
//    InflateRect( R, -1, -1);
//    Canvas.Pen.Style:= psSolid;
//    Frame3D(Canvas, R, clBtnHighlight, clBtnShadow, 1);
    DrawText(Canvas.Handle, PChar(ButtonCaption), -1, R,
       DT_NOCLIP or DT_SINGLELINE or DT_CENTER or DT_VCENTER);
  end;
  Canvas.Pen.Style:= psSolid;
//  SetBkMode(Canvas.Handle, OldBkMode);
end;

procedure TDTMColorGrid.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Square: Integer;
  Dlg: TColorDialog;

begin
  inherited MouseDown(Button, Shift, X, Y);
  FButton := Button;
  FButtonDown := True;
  Square := SquareFromPos(X, Y);
  if Button = mbLeft then begin
    if Square>=0 then SetColorIndex(Square)
    else if X>FCaptionSize+FCellXSize*FNumXSquares then begin
      if Assigned( FColorDialog) then Dlg:= FColorDialog
      else Dlg:= TColorDialog.Create( Self);
      Dlg.Color:= Color;
      if Dlg.Execute then Color:= Dlg.Color;
      if not Assigned( FColorDialog) then Dlg.Free;
    end;
  end;
//  SetSelection(Square);
end;

procedure TDTMColorGrid.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Square: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if FButtonDown then
  begin
    Square := SquareFromPos(X, Y);
    if (FButton = mbLeft) and (Square>=0) then SetColorIndex(Square);
//    SetSelection(Square);
  end;
end;

procedure TDTMColorGrid.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FButtonDown := False;
  if FButton = mbRight then MouseCapture := False;
end;

procedure TDTMColorGrid.Paint;
var
  Row, Col, wEntryIndex: Integer;
  R: TRect;
begin
  UpdateCellSizes;
  R:= ClientRect;
  Frame3D(Canvas, R, clBtnShadow, clBtnHighlight, 1);
  Canvas.Font := Font;
  for Row := 0 to FNumYSquares do
    for Col := 0 to FNumXSquares do
    begin
      wEntryIndex := Row * FNumXSquares + Col;
      DrawSquare(wEntryIndex);
    end;
//  DrawSquare(FSelection);
  DrawFgBg;
end;

procedure TDTMColorGrid.SetCaption( Value: String);
begin
  if FCaption<>Value then begin
    FCaption:= Value;
    Invalidate;
  end;
end;

procedure TDTMColorGrid.SetCaptionSize( Value: Integer);
begin
  if FCaptionSize<>Value then begin
    FCaptionSize:= Value;
    Invalidate;
  end;
end;

procedure TDTMColorGrid.SetButtonCaption( Value: String);
begin
  if FButtonCaption<>Value then begin
    FButtonCaption:= Value;
    Invalidate;
  end;
end;

procedure TDTMColorGrid.SetButtonSize( Value: Integer);
begin
  if FButtonSize<>Value then begin
    FButtonSize:= Value;
    Invalidate;
  end;
end;

procedure TDTMColorGrid.SetColorIndex(Value: Integer);
var
  Index: Integer;

begin
  Index:= ColorToIndex( FColor);
  if (Index <> Value) and (Value>=0) and (Value<16) then begin
    DrawSquare( Index);
    FColor:= DefaultColors[ Value];
    DrawFgBg;
    Change;
  end;
end;

procedure TDTMColorGrid.SetGridOrdering(Value: TksGridOrdering);
begin
  if FGridOrdering = Value then Exit;
  FGridOrdering := Value;
  FNumXSquares := 16 shr Ord(FGridOrdering);
  FNumYSquares := 1 shl Ord(FGridOrdering);
  Invalidate;
end;

function TDTMColorGrid.SquareFromPos(X, Y: Integer): Integer;
begin
  X:= X-FCaptionSize;
  if (X<0) or (X>FCellXSize*FNumXSquares) then begin
    Result:= -1;
    Exit;
  end;
{  if X > Width - 1 then X := Width - 1
  else if X < 0 then X := 0;
  if Y > Height - 1 then Y := Height - 1
  else if Y < 0 then Y := 0;
}
  Result := (Y div FCellYSize) * FNumXSquares + (X div FCellXSize);
  if Result>=16 then Result:= -1;
end;

procedure TDTMColorGrid.UpdateCellSizes;
//var
// NewWidth, NewHeight: Integer;

begin
//  NewWidth := (Width div FNumXSquares) * FNumXSquares;
//  NewHeight := (Height div FNumYSquares) * FNumYSquares;
//  BoundsRect := Bounds(Left, Top, NewWidth, NewHeight);
  FCellXSize := (Width - FCaptionSize - FButtonSize) div FNumXSquares;
  FCellYSize := Height div FNumYSquares;
//  if DoRepaint then Invalidate;
end;

procedure TDTMColorGrid.Change;
begin
//  Changed;
  if Assigned(FOnChange) then FOnChange(Self);
end;

{ TColorComboBox }

constructor TDTMColorComboBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Style:= csOwnerDrawFixed;
  FColor:= clBlack;
end;

function TDTMColorComboBox.GetColor: TColor;
var
  I: Integer;

begin
  I:= ItemIndex;
  if (I<0) or (I>=Items.Count) then Result:= FColor
  else Result:= TColor(Items.Objects[I]);
end;

procedure TDTMColorComboBox.SetColor( AValue: TColor);
begin
  FColor:= AValue;
  FixItemIndex;
end;

function TDTMColorComboBox.GetCtrlColor: TColor;
begin
  Result:= inherited Color;
end;

procedure TDTMColorComboBox.SetCtrlColor( Value: TColor);
begin
  inherited Color:= Value;
end;

procedure TDTMColorComboBox.FixItemIndex;
var
  I: Integer;

begin
  if Items.Count = 0 then Exit;
  for I:= 0 to Pred(Items.Count) do begin
    if TColor(Items.Objects[I]) = FColor then begin
      if ItemIndex <> I then ItemIndex := I;
      Exit;
    end;
  end;
  if Items.Count>DefaultColorsCount then Items.Delete( Items.Count-1);
  Items.AddObject( IntToStr( DefaultColorsCount), TObject( FColor));
  if ItemIndex <> DefaultColorsCount then ItemIndex:= DefaultColorsCount;
end;

procedure TDTMColorComboBox.Loaded;
var
  I: Integer;

begin
  inherited Loaded;
  Clear;
  for I:= 0 to DefaultColorsCount-1 do begin
    Items.AddObject( '', TObject( DefaultColors[I]));
  end;
  FixItemIndex;
end;

procedure TDTMColorComboBox.DrawItem(Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  ARect: TRect;
  Safer: TColor;

begin
  ARect:= Rect;
  InflateRect( ARect, -2, -2);
  Dec(ARect.Right, 1);
  with Canvas do begin
    FillRect(Rect);
    Safer:= Brush.Color;
    Pen.Color:= clBlack;
    Rectangle(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom);
    Brush.Color:= TColor(Items.Objects[Index]);
    try
      InflateRect(ARect, -1, -1);
      FillRect(ARect);
    finally
      Brush.Color := Safer;
    end;
  end;
end;

end.
