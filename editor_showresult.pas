unit editor_showresult;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,DTM_Bitmaps;

type
  TDTMResultForm = class(TForm)
    Render: TImage;
  private
    { Private declarations }
  public
    procedure ShowFindResult(B: TDTMBitmap);
  end;

var
  DTMResultForm: TDTMResultForm;

implementation

{$R *.dfm}

{ TDTMResultForm }



procedure TDTMResultForm.ShowFindResult(B: TDTMBitmap);
begin
 Self.SetBounds(0,0,b.Width,b.Height);
 Render.SetBounds(0,0,b.Width,b.Height);
 Render.Picture.Bitmap.SetSize(b.Width,b.Height);
 B.FastDrawToCanvas(0,0,Render.Canvas);
 ShowModal;
end;

end.
