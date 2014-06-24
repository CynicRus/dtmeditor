unit editor_main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Menus, Vcl.ToolWin, Vcl.Samples.Spin,  PngImage,Jpeg,GifImg,
   Vcl.ImgList,DTM_Bitmaps,DTM_Structure,DTM_HandlePicker,DTM_Editor,DTM_TPA,DTM_ImageCatcher,DTM_Finder,
  JvExStdCtrls, JvCombobox, JvColorCombo;

type
 // TSDtmList = TList<TSDTMPointDefArray>;
  TPointActionType = (patNewPoint = 0,patMovePoint = 1,patMoveDTM = 2);
  TDtmForm = class(TForm)
    ActBar: TToolBar;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    New1: TMenuItem;
    Openproject1: TMenuItem;
    Saveproject1: TMenuItem;
    N1: TMenuItem;
    Exit1: TMenuItem;
    ScrollBox1: TScrollBox;
    StatusBar1: TStatusBar;
    GroupBox1: TGroupBox;
    PixelImage: TImage;
    GroupBox2: TGroupBox;
    ImgListBox: TListBox;
    GroupBox3: TGroupBox;
    Label1: TLabel;
    DtmBox: TComboBox;
    Button1: TButton;
    LoadBtn: TButton;
    Label2: TLabel;
    DtmPointList: TListView;
    DelPtBtn: TButton;
    Label3: TLabel;
    xEdt: TSpinEdit;
    Label4: TLabel;
    yEdt: TSpinEdit;
    Label5: TLabel;
    ArSizeEdt: TSpinEdit;
    Label7: TLabel;
    ColorEdt: TSpinEdit;
    MiniColor: TImage;
    Label8: TLabel;
    TolEdt: TSpinEdit;
    Label9: TLabel;
    ToolButton1: TToolButton;
    ToolButton2: TToolButton;
    ToolButton3: TToolButton;
    ToolButton4: TToolButton;
    ToolButton5: TToolButton;
    ToolButton6: TToolButton;
    ToolButton7: TToolButton;
    ToolButton8: TToolButton;
    ToolButton9: TToolButton;
    ToolButton10: TToolButton;
    ToolButton11: TToolButton;
    ToolButton12: TToolButton;
    ToolButton13: TToolButton;
    ToolButton14: TToolButton;
    ToolButton15: TToolButton;
    ImgList: TImageList;
    Render: TImage;
    loadbDlg: TOpenDialog;
    ToolButton16: TToolButton;
    ToolButton17: TToolButton;
    ToolButton18: TToolButton;
    Shape1: TShape;
    DDTimer: TTimer;
    Button2: TButton;
    Button3: TButton;
    ColorSelector: TJvColorComboBox;
    DeleteDTMbtn: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ToolButton7MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ImgListBoxClick(Sender: TObject);
    procedure ToolButton10Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure LoadBtnClick(Sender: TObject);
    procedure DDTimerTimer(Sender: TObject);
    procedure ToolButton1Click(Sender: TObject);
    procedure ToolButton9Click(Sender: TObject);
    procedure RenderMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DtmPointListClick(Sender: TObject);
    procedure DtmPointListSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure DtmBoxSelect(Sender: TObject);
    procedure ColorSelectorChange(Sender: TObject);
    procedure RenderMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DelPtBtnClick(Sender: TObject);
    procedure DtmBoxKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DeleteDTMbtnClick(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure ImgListBoxKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Button2Click(Sender: TObject);
    procedure NotImplementedClick(Sender: TObject);
    procedure ToolButton18Click(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    procedure LoadDTM(DTM: AnsiString);
    procedure SetEditPoint(Point: TDTMPoint);
    procedure PointChange(Sender: TObject);

   // procedure ToRender();

    { Private declarations }
  public
    { Public declarations }
  end;

var
  DtmForm: TDtmForm;
  DTMEditor: TDTMEditor;
  LastPointIndex: integer;
  Image: TImage;
  CS: TRTLCriticalSection;

implementation
 uses math;
{$R *.dfm}

function Eq(aValue1, aValue2: string): boolean;
begin
  Result := AnsiCompareText(Trim(aValue1),Trim(aValue2))=0;
end;


procedure TDtmForm.Button1Click(Sender: TObject);
var
 DTM: TDTMS;
 DtmName: AnsiString;
 pt: TDTMPoint;
begin
 DTM:=TDTMS.Create;
 DtmName:=Trim(InputBox('Enter DTM name', 'Name', ''));
 if eq(DtmName,'') then
  begin
    Dtm.Free;
    exit;
  end;
  DTM.Name:=DTMName;
  DTM.DrawColor:=ColorSelector.Colors[ColorSelector.ItemIndex];
  DTMEditor.AddDTM(DTM);
  try
    pt:=TDTMPoint.Create;
    SetEditPoint(pt);
  finally
    pt.Free;
  end;
// NewDTM;
// DtmBoxChange(sender);
end;

procedure TDtmForm.Button2Click(Sender: TObject);
begin
  DTMEditor.FindDTM;
end;

procedure TDtmForm.Button3Click(Sender: TObject);
begin
 DTMEditor.FindAllDTMs;
end;

procedure TDtmForm.ColorSelectorChange(Sender: TObject);
begin
 if (ImgListBox.Count = 0) or (DTMBox.Items.Count = 0) then
    exit;
  if Assigned(DTMEditor.CurrentDTM) then
   begin
     DTMEditor.CurrentDTM.DrawColor:=ColorSelector.Colors[ColorSelector.ItemIndex];
   end;
end;

procedure TDtmForm.DDTimerTimer(Sender: TObject);
var
 i: integer;
begin

EnterCriticalSection(cs);
  DTMEditor.DrawScene;
  if (TTimer(Sender).Tag = clYellow) then
      TTimer(Sender).Tag := clBlack
    else
      TTimer(Sender).Tag := clYellow;
  if Assigned(DTMEditor.CurrentPoint) then
   DTMEditor.CurrentPoint.DrawToCanvas(Render.Canvas,TTimer(Sender).Tag,Render.Width,Render.Height);
 {if (ImgListBox.Count = 0) or (DTMBox.Items.Count = 0) then
  exit;
 if (TTimer(Sender).Tag = clYellow) then
      TTimer(Sender).Tag := clBlack
    else
      TTimer(Sender).Tag := clYellow;
 for i := 0 to DTMList.Count - 1 do
   DrawDTM(DTMList[i]);
   if (DtmPointList.ItemIndex >= 0) or (DtmPointList.Items.Count > 0) then
     if DtmList[DTMBox.ItemIndex].Count > 0 then
       DrawDTMPoint(DtmList[DTMBox.ItemIndex].Points[DtmPointList.ItemIndex],TTimer(Sender).Tag);  }
LeaveCriticalSection(cs);
end;


procedure TDtmForm.DeleteDTMbtnClick(Sender: TObject);
begin
 if Assigned(DTMEditor.CurrentDTM) then
      begin
       DTMEditor.DeleteDTM(DtmBox.ItemIndex);
      end;
end;

procedure TDtmForm.DelPtBtnClick(Sender: TObject);
begin
 if (DtmPointList.ItemIndex < 0) then
  Exit;

  DTMEditor.DeleteDTMPoint(DtmPointList.ItemIndex);

end;

procedure TDtmForm.DtmBoxKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if KEY=VK_DELETE then
   begin
     if Assigned(DTMEditor.CurrentDTM) then
      begin
       DTMEditor.DeleteDTM(DtmBox.ItemIndex);
      end;

   end;
end;

procedure TDtmForm.DtmBoxSelect(Sender: TObject);
var
 pt: TDTMPoint;
begin
 DTMEditor.SelectDTM(DtmBox.ItemIndex);

 if (DTMEditor.CurrentDTM.Points.Count <=0) then
  begin
    pt:=TDTMPoint.Create;
    SetEditPoint(pt);
    pt.Free;
  end;

end;

procedure TDtmForm.DtmPointListClick(Sender: TObject);
begin
 if Assigned(DtmPointList.Selected) then
  begin
    DTMEditor.CurrentPoint:=DTMEditor.CurrentDTM.Points[DtmPointList.ItemIndex];
    SetEditPoint(DTMEditor.CurrentPoint);
    LastPointIndex:=DtmPointList.ItemIndex;
  end;

end;

procedure TDtmForm.DtmPointListSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
 if Assigned(DTMEditor.CurrentPoint) then
    SetEditPoint(DTMEditor.CurrentPoint);
 LastPointIndex:=DtmPointList.ItemIndex;
end;

function GenSpaces(c: integer): string;
var
  i: integer;
  s: string;
begin
 s:=#32;
 for i := 0 to c -1 do
  begin
     s:=s+#32;
    end;
  result:=s;
end;


procedure TDtmForm.FormCreate(Sender: TObject);
begin
 InitializeCriticalSection(cs);
 //DDTimer.Enabled:=false;
 DTMEditor:=TDTMEditor.Create;
 with DTMEditor do
  begin
    Render:=Self.Render;
    ImgBox:=Self.ImgListBox;
    DTMViewer:=Self.DtmPointList;
    DTMBox:=Self.DtmBox;
  end;
  ColorSelector.ItemIndex:=1;
  xEdt.OnClick:=PointChange;
  yEdt.OnClick:=PointChange;
  ColorEdt.OnClick:=PointChange;
  TolEdt.OnClick:=PointChange;
  ArSizeEdt.OnClick:=PointChange;
end;

procedure TDtmForm.FormDestroy(Sender: TObject);
begin
 DDTimer.Enabled:=false;
 DeleteCriticalSection(cs);
 DTMEditor.Destroy;
//
end;

procedure TDtmForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
Function MouseInControl(WC:TImage):boolean;
var
 x1,x2,y1,y2:INTEGER;
 ptm:tpoint;
begin
  ptm:=Mouse.CursorPos;
  x1:=Wc.ClientOrigin.x; //top-left
  y1:=Wc.ClientOrigin.y;
  x2:=x1+Wc.ClientWidth;
  y2:=y1+Wc.ClientHeight;
  result:=(ptm.x>=x1) and (ptm.x<=x2) and (ptm.y>=y1)and(ptm.y<=y2);
end;
var
 Pos: TPoint;
begin
if not Assigned(DTMEditor.CurrentBitmap) then
 Exit;
 if MouseInControl(Render) then
  begin

   case key of
    VK_UP:
     begin
       GetCursorPos(Pos);
       Pos.Y:=Pos.Y-1;
       SetCursorPos(Pos.X, Pos.Y);
     end;
    VK_DOWN:
     begin
      GetCursorPos(Pos);
      Pos.Y:=Pos.Y+1;
      SetCursorPos(Pos.X, Pos.Y);
     end;
    VK_LEFT:
     begin
      GetCursorPos(Pos);
      Pos.X:=Pos.X-1;
      SetCursorPos(Pos.X, Pos.Y);
     end;
    VK_Right:
    begin
     GetCursorPos(Pos);
     Pos.X:=Pos.X+1;
     SetCursorPos(Pos.X, Pos.Y);
    end;
   end;
end;
end;


procedure TDtmForm.ImgListBoxClick(Sender: TObject);
begin
if (ImgListBox.ItemIndex = -1) then
    exit;
DTMEditor.SelectBitmap(ImgListBox.ItemIndex);
 //BitmapToRender(ImgListBox.ItemIndex);
end;

procedure TDtmForm.ImgListBoxKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
 if (DTMEditor.Bitmaps.Count > 1) then
  begin
    if Key = VK_DELETE then
     begin
       DTMEditor.DeleteBitmap(ImgListBox.ItemIndex);
     end;
  end;
end;

procedure TDtmForm.LoadBtnClick(Sender: TObject);
var
 DTMString:AnsiString;
begin
 DTMString:=Trim(InputBox('Enter DTM string', 'DTM', ''));
 if eq(DTMString,'') then
  exit;
 LoadDTM(DTMString);
end;


procedure TDtmForm.LoadDTM(DTM: AnsiString);
var
 DTMName: string;
begin
  DTMName:=Trim(InputBox('Enter DTM name', 'Name:', ''));
 if eq(DTMName,'') then
  exit;
 if ColorSelector.ItemIndex < ColorSelector.Items.Count then
  DTMEditor.AddDTM(DTM,DTMName,ColorSelector.Colors[ColorSelector.ItemIndex]) else
  begin
   ColorSelector.ItemIndex:=ColorSelector.Items.Count-1;
   DTMEditor.AddDTM(DTM,DTMName,ColorSelector.Colors[ColorSelector.ItemIndex]);

  end;


end;

procedure TDtmForm.NotImplementedClick(Sender: TObject);
begin
 ShowMessage('Not implemented yet!');
end;

procedure TDtmForm.PointChange(Sender: TObject);
begin
 if Assigned(DTMEditor.CurrentPoint) then
  begin
  with DTMEditor.CurrentPoint do
   begin
    x:=xEdt.Value;
    y:=yEdt.Value;
    Color:=ColorEdt.Value;
    Tolerance:=TolEdt.Value;
    AreaSize:=ArSizeEdt.Value;
   end;
   DTMEditor.UpdatePoints;
   //SetEditPoint(DTMEditor.CurrentPoint);
  end;
end;

procedure TDtmForm.RenderMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
 ActionType: TPointActionType;
 NewPoint: TDTMPoint;
begin
 if not Assigned(DTMEditor.CurrentBitmap) then
  ToolButton9Click(Sender);

 if not Assigned(DTMEditor.CurrentDTM) then
  Button1Click(Sender);

 case Button of
    mbLeft: ActionType:=patNewPoint;
    mbRight: ActionType:=patMovePoint;
 end;

 case ActionType of
   patNewPoint:
    begin
     NewPoint:=TDTMPoint.Create;
     NewPoint.X:=X;
     NewPoint.Y:=Y;
     NewPoint.Color:=DTMEditor.CurrentBitmap.FastGetPixel(x,y);
     NewPoint.Tolerance:=0;
     newPoint.AreaSize:=1;
     DtmEditor.AddDTM(NewPoint);
    end;
   patMovePoint:
   begin

     with DTMEditor do
     begin
     if not Assigned(CurrentPoint) then
      Exit;
     CurrentPoint.X:=X;
     CurrentPoint.Y:=Y;
     CurrentPoint.Color:=DTMEditor.CurrentBitmap.FastGetPixel(x,y);
     UpdatePoints(LastPointIndex);
     SetEditPoint(CurrentPoint);
     DtmPointList.ItemIndex:=LastPointIndex;
     end;
   end;
   patMoveDTM: ;
 end;


end;

procedure TDtmForm.RenderMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  Color: Integer;
  i: integer;
  Bmp: TDTMBitmap;
  Bitmap: TBitmap;
begin
  if (imglistbox.ItemIndex = -1) then
   exit;
  Bitmap:=TBitmap.Create;
  //bmp:= Client.MBitmaps.GetBMP(imglistbox.ItemIndex).ToTBitmap;
  BMP:=DTMEditor.CurrentBitmap;
  Color:=Bmp.FastGetPixel(X,y);
  Bmp.ToBMP(Bitmap);

  StatusBar1.Panels.Items[0].Text := IntToStr(X)+':'+IntToStr(Y);
  StatusBar1.Panels.Items[1].Text := IntToStr(Color);
  //Color:=bmp.Canvas.Pixels[x,y];
// Color:=0;
// Client.MBitmaps.GetBMP(i).FastSetPixel(x,y,Color);
// BitmapToRender(i);
  Shape1.Brush.Color := Color;
  with PixelImage.Canvas do
      begin
        Pen.Color := clBlack;
        Brush.Style := bsSolid;
        Brush.Color := clWhite;
        Rectangle(0, 0, 100, 100);
        Brush.Style := bsDiagCross;
        Brush.Color := clNavy;
        Rectangle(0, 0, 100, 100);
        CopyRect(Rect(1, 1, 99, 99), bitmap.Canvas, Rect(X - 2, Y -2, X + 3, Y + 3));
        Brush.Style := bsClear;
        Pen.Color := clRed;
        Rectangle(38, 38, 62, 62);
      end;
  //Client.MBitmaps.GetBMP(imglistbox.ItemIndex).FastGetPixel(x,y);
 Bitmap.Free;

end;

procedure TDtmForm.SetEditPoint(Point: TDTMPoint);
begin
 xEdt.Value:=Point.x;
 yEdt.Value:=Point.y;
 ColorEdt.Value:=Point.Color;
 TolEdt.Value:=Point.Tolerance;
 ArSizeEdt.Value:=Point.AreaSize;
 with MiniColor do
  begin
    Canvas.Pen.Color:=Point.Color;
    Canvas.Brush.Color:=Point.Color;
    Canvas.Rectangle(0,0,Width,Height);
  end;
end;

procedure TDtmForm.ToolButton10Click(Sender: TObject);
begin
 if loadbdlg.Execute then
   begin
     DTMEditor.AddBitmap(loadbdlg.FileName);
   end else exit;
end;

procedure TDtmForm.ToolButton18Click(Sender: TObject);
begin
  DTMEditor.MakeScript;
end;

procedure TDtmForm.ToolButton1Click(Sender: TObject);
begin
  Application.Destroy;
end;

procedure TDtmForm.ToolButton7MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
Bitmap: TDTMBitmap;
begin
 DTMEditor.Picker.Drag;
 DTMEditor.Catcher.TargetHandle:=DTMEditor.Picker.Handle;
 DTMEditor.Catcher.GetScreenShot;
 Bitmap:=TDTMBitmap.Create;
 Bitmap.LoadFromBitmap(DTMEditor.Catcher.Bitmap);
 DTMEditor.AddBitmap(Bitmap);
 //DDTimer.Enabled:=true;
end;


procedure TDtmForm.ToolButton9Click(Sender: TObject);
var
Bitmap: TDTMBitmap;
begin

 with DTMEditor do
  begin
    if (Picker.Handle <=0) then
     exit;
    Bitmap:=TDTMBitmap.Create;
    try
    Catcher.TargetHandle:=DTMEditor.Picker.Handle;
    Catcher.GetScreenShot;
    except
     on E: Exception do
      begin
        Catcher.TargetHandle:=GetDesktopWindow;
        Catcher.GetScreenShot;
      end;
    end;
    Bitmap.LoadFromBitmap(DTMEditor.Catcher.Bitmap);
    AddBitmap(Bitmap);
  end;
end;

end.
