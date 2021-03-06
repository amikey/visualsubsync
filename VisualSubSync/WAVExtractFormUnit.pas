// -----------------------------------------------------------------------------
//  VisualSubSync
// -----------------------------------------------------------------------------
//  Copyright (C) 2003 Christophe Paris
// -----------------------------------------------------------------------------
//  This Program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2, or (at your option)
//  any later version.
//
//  This Program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with GNU Make; see the file COPYING.  If not, write to
//  the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
//  http://www.gnu.org/copyleft/gpl.html
// -----------------------------------------------------------------------------

unit WAVExtractFormUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, TntStdCtrls, ComCtrls, Renderer, ExtCtrls;

type
  TExtractWAVForm = class(TForm)
    TntGroupBox1: TTntGroupBox;
    MemoVideoInfo: TTntMemo;
    bttExtract: TTntButton;
    bttClose: TTntButton;
    ProgressBar1: TProgressBar;
    gbSettings: TTntGroupBox;
    TntLabel1: TTntLabel;
    cbStreamIndex: TComboBox;
    TntLabel3: TTntLabel;
    Timer1: TTimer;
    bttStop: TTntButton;
    rbFastConversion: TRadioButton;
    rbNoConversion: TRadioButton;
    rbOnlyPeak: TRadioButton;
    bttDebug: TTntButton;
    procedure bttExtractClick(Sender: TObject);
    procedure bttCloseClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure bttStopClick(Sender: TObject);
    procedure rbOnlyPeakClick(Sender: TObject);
    procedure bttDebugClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    { Private declarations }
    DSWavExtractor : TDSWavExtractor;
    AudioPinIsSelected : Boolean;
    CurrentExtractionType : TWAVExtractionType;
    SuccessfullExtraction : Boolean;

    procedure CancelAndClose;
  public
    { Public declarations }
    VideoFilename : WideString;
    DestinationFilename : WideString;
    procedure SetExtractionType(extType : TWAVExtractionType);
  end;

implementation

{$R *.dfm}

uses CursorManager, GlobalUnit;

// -----------------------------------------------------------------------------

procedure TExtractWAVForm.bttExtractClick(Sender: TObject);
begin
  MemoVideoInfo.Lines.Add('Extracting stream '+ IntToStr(cbStreamIndex.ItemIndex+1) + ', please wait...');
  bttExtract.Enabled := False;

  if AudioPinIsSelected then
  begin
    DSWavExtractor.Close;
    DSWavExtractor.Open(VideoFilename);
    g_WavExtractorGraphDebugInfo := DSWavExtractor.GetFiltersAsString;    
  end;

  bttStop.Enabled := True;
  DSWavExtractor.DestinationFilename := DestinationFilename;
  DSWavExtractor.WAVExtractionType := CurrentExtractionType;
  DSWavExtractor.SelectAudioPin(cbStreamIndex.ItemIndex);
  AudioPinIsSelected := True;
  SuccessfullExtraction := False;

  g_WavExtractorGraphDebugInfo := DSWavExtractor.GetFiltersAsString;

  DSWavExtractor.Go;
  Timer1.Enabled := True;
end;

// -----------------------------------------------------------------------------

procedure TExtractWAVForm.CancelAndClose;
begin
  Timer1.Enabled := False;
  if Assigned(DSWavExtractor) then
  begin
    FreeAndNil(DSWavExtractor);
  end;
  ModalResult := mrCancel;
end;

// -----------------------------------------------------------------------------

procedure TExtractWAVForm.bttCloseClick(Sender: TObject);
begin
  Close;
end;

// -----------------------------------------------------------------------------

procedure TExtractWAVForm.SetExtractionType(extType : TWAVExtractionType);
begin
  CurrentExtractionType := extType;
  case extType of
    wetOnlyPeakFile : rbOnlyPeak.Checked := True;
    wetFastConversion : rbFastConversion.Checked := True;
    wetNoConversion : rbNoConversion.Checked := True;
  end;
end;

// -----------------------------------------------------------------------------

procedure TExtractWAVForm.FormActivate(Sender: TObject);
var i : integer;
    CM : ICursorManager;
begin
  CM := TCursorManager.Create(crHourGlass);

  SuccessfullExtraction := False;
  bttExtract.Enabled := False;
  bttStop.Enabled := False;
  bttClose.Enabled := False;
  gbSettings.Enabled := False;
  AudioPinIsSelected := False;

  // Get video info
  MemoVideoInfo.Clear;
  DSWavExtractor := TDSWavExtractor.Create;
  MemoVideoInfo.Lines.Add('Opening and analyzing file :');
  MemoVideoInfo.Lines.Add(VideoFilename);
  MemoVideoInfo.Lines.Add('In case of problems first check : http://www.visualsubsync.org/tutorials/codecs');
  MemoVideoInfo.Lines.Add('Please wait...');
  Application.ProcessMessages;
  DSWavExtractor.Open(VideoFilename);
  g_WavExtractorGraphDebugInfo := DSWavExtractor.GetFiltersAsString;
  MemoVideoInfo.Lines.Add(IntToStr(DSWavExtractor.AudioStreamCount) +
    ' audio stream found.');
  cbStreamIndex.Clear;
  for i := 1 to DSWavExtractor.AudioStreamCount do
  begin
    cbStreamIndex.AddItem(IntToStr(i),nil);
  end;
  if (DSWavExtractor.AudioStreamCount > 0) then
    cbStreamIndex.ItemIndex := 0;

  bttExtract.Enabled := (DSWavExtractor.AudioStreamCount > 0);
  bttClose.Enabled := True;
  gbSettings.Enabled := True;
  MemoVideoInfo.Lines.Add('Select a stream and press the ''Extract'' button.');
end;

// -----------------------------------------------------------------------------

procedure TExtractWAVForm.Timer1Timer(Sender: TObject);
begin
  ProgressBar1.Position := DSWavExtractor.GetProgress;
  if DSWavExtractor.IsFinished then
  begin
    Timer1.Enabled := False;
    DSWavExtractor.Close;
    bttExtract.Enabled := True;
    bttStop.Enabled := False;
    MemoVideoInfo.Lines.Add('Extraction finished successfully.');
    ProgressBar1.Position := 0;

    if Assigned(DSWavExtractor) then
    begin
      FreeAndNil(DSWavExtractor);
    end;
    SuccessfullExtraction := True;
    ModalResult := mrOk;
  end;
end;

// -----------------------------------------------------------------------------

procedure TExtractWAVForm.bttStopClick(Sender: TObject);
begin
  Timer1.Enabled := False;
  DSWavExtractor.Close;  
  bttExtract.Enabled := True;
  bttStop.Enabled := False;
  MemoVideoInfo.Lines.Add('Extraction aborted by user.');
  ProgressBar1.Position := 0;
  SuccessfullExtraction := False;
end;

// -----------------------------------------------------------------------------

procedure TExtractWAVForm.rbOnlyPeakClick(Sender: TObject);
begin
  CurrentExtractionType := TWAVExtractionType(TComponent(Sender).Tag);
end;

// -----------------------------------------------------------------------------

procedure TExtractWAVForm.bttDebugClick(Sender: TObject);
var slist : TStringList;
    i : Integer;
begin
  MemoVideoInfo.Lines.Add('--- Filters list ---');

  if AudioPinIsSelected then
  begin
    DSWavExtractor.Close;
    DSWavExtractor.Open(VideoFilename);
  end;

  DSWavExtractor.DestinationFilename := DestinationFilename;
  DSWavExtractor.WAVExtractionType := CurrentExtractionType;

  AudioPinIsSelected := DSWavExtractor.SelectAudioPin(cbStreamIndex.ItemIndex);

  slist := TStringList.Create;
  DSWavExtractor.GetFilters(slist);
  for i:=0 to slist.Count-1 do
  begin
    MemoVideoInfo.Lines.Add(slist[i]);
  end;
  slist.Free;
end;

// -----------------------------------------------------------------------------

procedure TExtractWAVForm.FormCreate(Sender: TObject);
begin
  SuccessfullExtraction := False;
  SetExtractionType(wetOnlyPeakFile);
end;

// -----------------------------------------------------------------------------

procedure TExtractWAVForm.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  if not SuccessfullExtraction then
    CancelAndClose;
end;

// -----------------------------------------------------------------------------

procedure TExtractWAVForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) then
  begin
    Close;
  end;
end;

// -----------------------------------------------------------------------------
end.
// -----------------------------------------------------------------------------
