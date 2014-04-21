unit DTM_HandlePicker;

interface
   uses
    System.Classes,System.SysUtils,Vcl.Controls,Vcl.Graphics,
    Vcl.Forms,Winapi.Windows;
type
 THandlePicker = class
   private
    FHandle: HWND;
    FHasPicked: Boolean;
   public
    property Handle: HWND read FHandle write FHandle;
    property HasPicked: Boolean read FHasPicked write FHasPicked;
    constructor Create;
    destructor Destroy;override;
    procedure Reset;
    procedure Drag;
 end;

implementation

{ THandlePicker }

constructor THandlePicker.Create;
begin
 Reset;
end;

destructor THandlePicker.Destroy;
begin

  inherited;
end;

procedure THandlePicker.Drag;
var
  TargetRect: TRect;
  Region : HRGN;
  Cursor : TCursor;
  TempHandle : Hwnd;
  DragForm : TForm;
  EdgeForm : TForm;
  Style : DWord;
  W,H: integer;
const
  EdgeSize =4;
  WindowCol = clred;
begin;
  Cursor:= Screen.Cursor;
  Screen.Cursor:= crCross;
  TempHandle := GetDesktopWindow;
  EdgeForm := TForm.Create(nil);
  EdgeForm.Color:= clBlack;
  EdgeForm.BorderStyle:= bsNone;


  DragForm := TForm.Create(nil);
  DragForm.Color:= clGreen;
  DragForm.BorderStyle:= bsNone;
  Style := GetWindowLong(DragForm.Handle, GWL_EXSTYLE);
  SetWindowLong(DragForm.Handle, GWL_EXSTYLE, Style or WS_EX_LAYERED or WS_EX_TRANSPARENT);
  SetLayeredWindowAttributes(DragForm.Handle, 0, 100, LWA_ALPHA);

  try
  while GetAsyncKeyState(VK_LBUTTON) <> 0 do
  begin;

    Handle:= WindowFromPoint(Mouse.CursorPos);
    if (Handle <> TempHandle) and (Handle <> EdgeForm.Handle) then
    begin;
      EdgeForm.Show;
      DragForm.Show;
      GetWindowRect(Handle, TargetRect);
      W :=TargetRect.Right - TargetRect.Left+1;
      H :=TargetRect.Bottom - TargetRect.Top+1;
      DragForm.SetBounds(TargetRect.Left,TargetRect.top,W,H);

      SetWindowRgn(EdgeForm.Handle,0,false);
      Region := CreateRectRgn(0,0,w-1,h-1);
      CombineRgn(Region,Region,CreateRectRgn(EdgeSize,EdgeSize,w-1-(edgesize),h-1-(edgesize)),RGN_XOR);
      SetWindowRgn(edgeform.Handle,Region,true);
      EdgeForm.SetBounds(TargetRect.Left,TargetRect.top,W,H);
      TempHandle  := Handle;
    end;
    Application.ProcessMessages;
    Sleep(30);
  end;
  Handle := TempHandle;
  haspicked:= true;
  Screen.Cursor:= cursor;
  finally
  DragForm.Hide;
  DragForm.Free;
  EdgeForm.Hide;
  EdgeForm.Free;
  end;
end;

procedure THandlePicker.Reset;
begin
  HasPicked:=false;
  Handle:=GetDesktopWindow();
end;

end.
