unit editor_snipper_form;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TSnippetForm = class(TForm)
    ResultMemo: TMemo;
  private
    { Private declarations }
  public
   Procedure LoadText(Text: TStringList);

    { Public declarations }
  end;

var
  SnippetForm: TSnippetForm;

implementation

{$R *.dfm}

{ TForm1 }


{ TSnippetForm }

procedure TSnippetForm.LoadText(Text: TStringList);
begin
 ResultMemo.Lines.Clear;
 ResultMemo.Text:=Text.Text;
 ShowModal;
end;

end.
