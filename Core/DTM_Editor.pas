unit DTM_Editor;

interface

uses
  System.Classes, System.SysUtils, Types, Windows, DTM_Bitmaps, DTM_Structure,
  DTM_TPA, DTM_Finder, DTM_ImageCatcher, DTM_HandlePicker, Vcl.Controls,
  Vcl.Graphics,
  Vcl.Forms, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.stdCtrls, editor_snipper_form,
  editor_showresult;

type
  TDTMEditor = class
  private
    FBitmaps: TDTMBitmapList;
    FDTMSList: TDTMSList;
    FPicker: THandlePicker;
    FFinder: TFinder;
    FCatcher: TImageCatcher;
    FCurrentDTM: TDTMS;
    FCurrentBitmap: TDTMBitmap;
    FCurrentPoint: TDTMPoint;
    FShowResultForm: TDTMResultForm;
    FSnippetForm: TSnippetForm;
    FRender: TImage;
    FImgBox: TListBox;
    FDTMViewer: TListview;
    FDTMBox: TComboBox;
    procedure DrawBitmap();
    procedure DrawDTM();
    procedure ProcessDTM(DTM: TDTMS);
  public
    constructor Create();
    destructor Destroy; override;
    procedure Reset;
    // bitmaps
    procedure AddBitmap(const Bitmap: TDTMBitmap); overload;
    // procedure AddBitmap(const Bitmap: TDTMBitmap);overload;
    procedure AddBitmap(const FileName: string); overload;
    procedure SelectBitmap(const i: integer);
    procedure DeleteBitmap(const i: integer);
    // DTMs
    procedure AddDTM(const DTMs: TDTMS); overload;
    procedure AddDTM(const DTMs: AnsiString; Name: string;
      aColor: integer); overload;
    procedure SelectDTM(const i: integer);
    procedure DeleteDTM(const i: integer);
    procedure UpdatePoints(); overload;
    procedure UpdatePoints(const SelectedIndex: integer); overload;
    procedure DrawScene();
    // TDTMPoints
    procedure AddDTM(const pt: TDTMPoint); overload;
    procedure DeleteDTMPoint(const i: integer);
    procedure MakeScript;
    // Find current dtm:)
    procedure FindDTM;
    procedure FindAllDTMs;
    property Bitmaps: TDTMBitmapList read FBitmaps write FBitmaps;
    property DTMList: TDTMSList read FDTMSList write FDTMSList;
    property Picker: THandlePicker read FPicker write FPicker;
    property Finder: TFinder read FFinder write FFinder;
    property Catcher: TImageCatcher read FCatcher write FCatcher;
    property CurrentDTM: TDTMS read FCurrentDTM write FCurrentDTM;
    property CurrentBitmap: TDTMBitmap read FCurrentBitmap write FCurrentBitmap;
    property ResultForm: TDTMResultForm read FShowResultForm
      write FShowResultForm;
    property ImgBox: TListBox read FImgBox write FImgBox;
    property DTMViewer: TListview read FDTMViewer write FDTMViewer;
    property Render: TImage read FRender write FRender;
    property DTMBox: TComboBox read FDTMBox write FDTMBox;
    property CurrentPoint: TDTMPoint read FCurrentPoint write FCurrentPoint;

  end;

implementation

uses math;
{ TDTMEditor }

procedure TDTMEditor.AddBitmap(const Bitmap: TDTMBitmap);
var
  txt: array [0 .. 255] of Char;
  w, h: integer;
begin
  Bitmaps.Add(Bitmap);
  FCurrentBitmap := Bitmaps[Bitmaps.Count - 1];
  GetWindowText(Picker.Handle, txt, sizeof(txt));
  if String(txt) = '' then
    txt := 'Unknown';
  ImgBox.Items.Add(String(txt) + inttostr(ImgBox.Count));
  ImgBox.ItemIndex := ImgBox.Items.Count - 1;
  ImgBox.SetFocus;
  // Result:=Bitmaps.Count - 1;
end;

procedure TDTMEditor.AddBitmap(const FileName: string);
var
  bmp: TDTMBitmap;
  Name: AnsiString;
begin
  bmp := TDTMBitmap.Create;
  bmp.LoadFromFile(FileName);
  name := ExtractfileName(FileName);
  Bitmaps.Add(bmp);
  FCurrentBitmap := Bitmaps[Bitmaps.Count - 1];
  ImgBox.Items.Add(String(Name));
  ImgBox.ItemIndex := ImgBox.Items.Count - 1;
  ImgBox.SetFocus;
end;

procedure TDTMEditor.AddDTM(const DTMs: TDTMS);
begin
  DTMList.Add(DTMs);
  DTMBox.Items.Add(DTMs.Name);
  DTMBox.ItemIndex := DTMBox.Items.Count - 1;
  CurrentDTM := DTMList[DTMList.Count - 1];
  UpdatePoints;
end;

procedure TDTMEditor.AddDTM(const DTMs: AnsiString; Name: string;
  aColor: integer);
var
  DTM: TDTMS;
begin
  DTM := TDTMS.Create;
  try
    DTM.AsString := DTMs
  except
    on E: Exception do
    begin
      DTM.Free;
      Exit;
    end;
  end;
  DTM.Name := Name;
  DTM.DrawColor := aColor;
  DTMList.Add(DTM);
  DTMBox.Items.Add(Name);
  DTMBox.ItemIndex := DTMBox.Items.Count - 1;
  CurrentDTM := DTMList[DTMList.Count - 1];
  ProcessDTM(CurrentDTM);

end;

constructor TDTMEditor.Create;
begin
  inherited;
  FBitmaps := TDTMBitmapList.Create;
  FDTMSList := TDTMSList.Create;
  FPicker := THandlePicker.Create;
  FFinder := TFinder.Create;
  FCatcher := TImageCatcher.Create;
  FShowResultForm := TDTMResultForm.Create(nil);
  FSnippetForm := TSnippetForm.Create(nil);
end;

procedure TDTMEditor.DeleteBitmap(const i: integer);
begin
  if (i >= ImgBox.Count) or (i >= Bitmaps.Count) then
    Exit;
  ImgBox.ItemIndex := i;
  ImgBox.DeleteSelected;
  Bitmaps.Delete(i);
  FCurrentBitmap := nil;
  ImgBox.ItemIndex := Bitmaps.Count - 1;
  FCurrentBitmap := Bitmaps[Bitmaps.Count - 1];
end;

procedure TDTMEditor.DeleteDTM(const i: integer);
begin
  if (DTMList.Count <= i) then
    Exit;

  DTMList.Delete(i);
  DTMBox.Items.Delete(i);
  CurrentDTM := nil;
  if DTMList.Count > 0 then
  begin
    CurrentDTM := DTMList[DTMList.Count - 1];
    ProcessDTM(CurrentDTM);
    DTMBox.ItemIndex := DTMList.Count - 1;
  end
  else
  begin
    DTMViewer.Clear;
    CurrentPoint := nil;
    CurrentDTM := nil;
    DTMBox.ItemIndex := 0;
  end;

end;

procedure TDTMEditor.DeleteDTMPoint(const i: integer);
begin
  if Assigned(CurrentDTM) then
  begin
    if (CurrentDTM.Points.Count <= i) then
      Exit;
    CurrentDTM.Points.Delete(i);
    // ProcessDTM(CurrentDTM);
    CurrentPoint := nil;
    UpdatePoints;
    if CurrentDTM.Points.Count > 0 then
    begin
      CurrentPoint := CurrentDTM.Points[CurrentDTM.Points.Count - 1];
      DTMViewer.ItemIndex := CurrentDTM.Points.Count - 1;
    end;

  end;

end;

destructor TDTMEditor.Destroy;
begin
  FBitmaps.Free;
  FDTMSList.Free;
  FPicker.Free;
  FFinder.Free;
  FCatcher.Free;
  FShowResultForm.Free;
  FSnippetForm.Free;
  FRender := nil;
  FImgBox := nil;
  FDTMViewer := nil;
  inherited;
end;

procedure TDTMEditor.DrawBitmap();
begin
  if not Assigned(FCurrentBitmap) then
    Exit;
  with FRender do
  begin
    Width := FCurrentBitmap.Width;
    Height := FCurrentBitmap.Height;
    Picture.Bitmap.SetSize(FCurrentBitmap.Width, FCurrentBitmap.Height);
    FCurrentBitmap.FastDrawToCanvas(0, 0, Canvas);
  end;
end;

procedure TDTMEditor.DrawDTM;
begin
  if Assigned(CurrentDTM) and (CurrentDTM.Points.Count > 0) and
    Assigned(FCurrentBitmap) then
    CurrentDTM.DrawToCanvas(Render.Canvas, Render.Width, Render.Height);
end;

procedure TDTMEditor.DrawScene;
begin
  DrawBitmap;
  DrawDTM;
end;

procedure TDTMEditor.FindAllDTMs;
var
  p1, p2: TPointArray;
  Res: array of TPointArray;
  DTM: TDTMS;
  B: TDTMBitmap;
  i, j: integer;
  Col: integer;
begin
  if not Assigned(CurrentBitmap) or not Assigned(CurrentDTM) or
    (CurrentDTM.Points.Count <= 1) then
    Exit;
  Finder.Target := FCurrentBitmap;
  SetLength(Res, DTMList.Count);
  for j := 0 to DTMList.Count - 1 do
  begin
    DTM := TDTMS.Create;
    DTM.AsString := DTMList[j].AsString;
    try
      if Finder.FindDTMs(DTM, p1, 0, 0, CurrentBitmap.Width - 1,
        CurrentBitmap.Height - 1) then
      begin
        p2 := TPAFromCircle(p1[i].x, p1[i].y, 4);
        FillEllipse(p2);
      end;
      Res[j] := p2;
    finally
      DTM.Free;
    end;
  end;
  B := CurrentBitmap.CopyBitmap;
  for i := 0 to Length(Res) - 1 do
  begin
    Col := DTMList[i].DrawColor;
    for j := 0 to Length(Res[i]) - 1 do
      B.FastSetColor(Res[i][j].x, Res[i][j].y, Col);
  end;
  FShowResultForm.ShowFindResult(B);
  B.Free;
end;

procedure TDTMEditor.FindDTM;
var
  p,p1, p2: TPointArray;
  i,j: integer;
  B: TDTMBitmap;
  DTM: TDTMS;
begin
  if not Assigned(CurrentBitmap) or not Assigned(CurrentDTM) or
    (CurrentDTM.Points.Count <= 1) then
    Exit;
  Finder.Target := FCurrentBitmap;
  DTM := TDTMS.Create;
  try
    DTM.AsString := CurrentDTM.AsString;
    if Finder.FindDTMs(DTM, p1, 0, 0, CurrentBitmap.Width - 1,
      CurrentBitmap.Height - 1) then
    begin
      B := CurrentBitmap.CopyBitmap;
      for i := 0 to High(p1) do
      begin
        p := TPAFromCircle(p1[i].x, p1[i].y, 4);
        FillEllipse(p);
        for j:= 0 to Length(p)-1 do
            B.FastSetColor(p[j].x, p[j].y, CurrentDTM.DrawColor);
      end;
      FShowResultForm.ShowFindResult(B);
    end;
  finally
    B.Free;
    DTM.Free;
  end;
end;

procedure TDTMEditor.MakeScript; { Temporary }
var
  i: integer;
  List: TStringList;
  str, names: string;
begin
  List := TStringList.Create;
  List.Add('program DTMSnippet;');
  List.Add('');
  for i := 0 to DTMList.Count - 1 do
  begin
    List.Add('var');
    if (i < DTMList.Count - 1) then
      str := str + DTMList[i].Name + ','
    else
      str := str + DTMList[i].Name + ': integer;'
  end;
  List.Add('');
  List.Add(str);
  str := '';
  List.Add('Procedure InitDTM;');
  List.Add('begin');
  for i := 0 to DTMList.Count - 1 do
  begin
    str := '';
    str := DTMList[i].Name + ' :=  DTMFromString(' + #39 + DTMList[i].AsString +
      #39 + ');';

    List.Add(str);
  end;
  List.Add('end;');
  List.Add('');
  List.Add('procedure FreeDTM;');
  List.Add('begin');
  for i := 0 to DTMList.Count - 1 do
  begin
    List.Add('FreeDTM(' + DTMList[i].Name + ');');
  end;
  List.Add('end;');
  FSnippetForm.LoadText(List);
  List.Free;
  // FSnippetForm.ShowModal;
end;

procedure TDTMEditor.ProcessDTM(DTM: TDTMS);
var
  Item: TListItem;
  i: integer;
begin
  DTMViewer.Clear;
  DTMViewer.Items.BeginUpdate;
  for i := 0 to DTM.Points.Count - 1 do
  begin
    Item := DTMViewer.Items.Add;
    with Item do
    begin
      Caption := inttostr(DTM.Points[i].x);
      Subitems.Add(inttostr(DTM.Points[i].y));
      Subitems.Add(inttostr(DTM.Points[i].color));
      Subitems.Add(inttostr(DTM.Points[i].Tolerance));
      Subitems.Add(inttostr(DTM.Points[i].AreaSize));
    end;
  end;
  if (DTM.Points.Count > 0) then
  begin
    FCurrentPoint := DTM.Points[0];
    DTMViewer.Items.EndUpdate;
    DTMViewer.ItemIndex := 0;
  end;
end;

procedure TDTMEditor.Reset;
begin
  FBitmaps.Clear;
  FPicker.Reset;
  FDTMSList.Clear;
  FFinder.Reset;
  FCatcher.Reset;
  FShowResultForm.SetBounds(0, 0, 0, 0);
end;

procedure TDTMEditor.SelectBitmap(const i: integer);
begin
  FCurrentBitmap := Bitmaps[i];
end;

procedure TDTMEditor.SelectDTM(const i: integer);
begin
  if (i >= DTMList.Count) then
    Exit;
  CurrentPoint := nil;
  CurrentDTM := DTMList[i];
  ProcessDTM(CurrentDTM);

end;

procedure TDTMEditor.UpdatePoints(const SelectedIndex: integer);
var
  Item: TListItem;
  i: integer;
begin
  DTMViewer.Clear;
  DTMViewer.Items.BeginUpdate;
  for i := 0 to CurrentDTM.Points.Count - 1 do
  begin
    Item := DTMViewer.Items.Add;
    with Item do
    begin
      Caption := inttostr(CurrentDTM.Points[i].x);
      Subitems.Add(inttostr(CurrentDTM.Points[i].y));
      Subitems.Add(inttostr(CurrentDTM.Points[i].color));
      Subitems.Add(inttostr(CurrentDTM.Points[i].Tolerance));
      Subitems.Add(inttostr(CurrentDTM.Points[i].AreaSize));
    end;
  end;
  CurrentPoint := CurrentDTM.Points[SelectedIndex];
  DTMViewer.Items.EndUpdate;
end;

procedure TDTMEditor.UpdatePoints;
var
  Item: TListItem;
  i: integer;
begin
  DTMViewer.Clear;
  DTMViewer.Items.BeginUpdate;
  for i := 0 to CurrentDTM.Points.Count - 1 do
  begin
    Item := DTMViewer.Items.Add;
    with Item do
    begin
      Caption := inttostr(CurrentDTM.Points[i].x);
      Subitems.Add(inttostr(CurrentDTM.Points[i].y));
      Subitems.Add(inttostr(CurrentDTM.Points[i].color));
      Subitems.Add(inttostr(CurrentDTM.Points[i].Tolerance));
      Subitems.Add(inttostr(CurrentDTM.Points[i].AreaSize));
    end;
  end;
  FCurrentPoint := nil;
  // FCurrentPoint:=DTM.Points[0];
  DTMViewer.Items.EndUpdate;
end;

procedure TDTMEditor.AddDTM(const pt: TDTMPoint);
begin
  if Assigned(CurrentDTM) then
  begin
    CurrentDTM.Points.Add(pt);
    // ProcessDTM(CurrentDTM);
    UpdatePoints;
    CurrentPoint := CurrentDTM.Points[CurrentDTM.Points.Count - 1];
    DTMViewer.ItemIndex := CurrentDTM.Points.Count - 1;

  end;
end;

end.
