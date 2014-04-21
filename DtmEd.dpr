program DtmEd;

uses
  {$IFDEF DEBUG}
  FastMM4,
  {$ENDIF}
  Vcl.Forms,
  editor_main in 'editor_main.pas' {DtmForm},
  DTM_Bitmaps in 'Core\DTM_Bitmaps.pas',
  DCPBase64 in 'Delphi_MML\misc\DCPBase64.pas',
  DTM_Structure in 'Core\DTM_Structure.pas',
  DTM_HandlePicker in 'Core\DTM_HandlePicker.pas',
  DTM_ImageCatcher in 'Core\DTM_ImageCatcher.pas',
  DTM_Finder in 'Core\DTM_Finder.pas',
  DTM_TPA in 'Core\DTM_TPA.pas',
  DTM_Editor in 'Core\DTM_Editor.pas',
  editor_snipper_form in 'editor_snipper_form.pas' {SnippetForm},
  editor_showresult in 'editor_showresult.pas' {DTMResultForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TDtmForm, DtmForm);
  Application.CreateForm(TDTMResultForm, DTMResultForm);
  // Application.CreateForm(TSnippetForm, SnippetForm);
  Application.Run;
end.
