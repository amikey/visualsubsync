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

unit MiscToolsUnit;

interface

uses Classes;

type
  TFileVersion = class
  private
    FFileParsed : Boolean;
    FFilename : string;
    FShortVersionString : string;
    FVersionString : string;
    function ParseFile : Boolean;
    function GetVersionString : string;
    function GetShortVersionString : string;
  public
    constructor Create(filename : string);
  published
    property VersionString : string read GetVersionString;
    property ShortVersionString : string read GetShortVersionString;
  end;

  procedure Constrain(var Value : Integer; MinValue, MaxValue : Integer);
  function TimeMsToString(TimeMS: Cardinal; DecimalSeparator : string = '.') : string;
  function TimeStringToMs(Time : string) : Integer;
  function StringConvertPipeToCRLF(s : WideString) : WideString;
  function StringConvertPipeToBR(s : WideString) : WideString;
  function StringConvertCRLFToPipe(s : WideString) : WideString;
  function GetFileVersionString(filename : string) : string;

  function PosStream(SubString : string; Stream : TStream; StartPos : Integer = -1) : Integer;
  function PosStreamEx(SubString : string; Stream : TStream; StartPos, StopPos : Integer) : Integer;

  function URLDecode(ASrc: string): string;

  procedure ShellRegisterExtension(Extension, Name, Executable : string);
  function ShellIsExtensionRegistered(Extension, Name, Executable : string) : Boolean;
  procedure ShellUnRegisterExtension(Extension, Name, Executable : string);

  function ReadLineStream(Stream : TStream; var s : string) : Boolean;
    
implementation

uses SysUtils, Windows, Registry, ShlObj;

// -----------------------------------------------------------------------------

procedure Constrain(var Value : Integer; MinValue, MaxValue : Integer);
begin
  if Value < MinValue then
    Value := MinValue
  else if Value > MaxValue then
    Value := MaxValue;
end;

// -----------------------------------------------------------------------------

function TimeMsToString(TimeMS: Cardinal; DecimalSeparator : string) : string;
var
  hh, min, sec, ms: Cardinal;
begin
  ms := TimeMs div 1000;
  hh := ms div 3600;
  min := ms mod 3600 div 60;
  sec := ms mod 3600 mod 60;
  ms := TimeMs - (hh * 3600 * 1000) - (min * 60 * 1000) - (sec * 1000);
  Result := Format('%2.2d:%2.2d:%2.2d%s%3.3d', [hh, min, sec, DecimalSeparator, ms])
end;

//------------------------------------------------------------------------------

function TimeStringToMs(Time : string) : Integer;
  var h, m, s, ms: Integer;
begin
  Result := -1;
  // 00:50:06,969 or
  // 00:50:06.969
  // 123456789012
  if Length(Time) < 8 then
    Exit;
  if (Time[3] <> ':') or (Time[6] <> ':') then
    Exit;
  h := StrToIntDef(Copy(Time, 1,2),-1);
  if (h = -1) then
    Exit;
  m := StrToIntDef(Copy(Time, 4,2),-1);
  if (m = -1) then
    Exit;
  s := StrToIntDef(Copy(Time, 7,2),-1);
  if (s = -1) then
    Exit;
  ms := StrToIntDef(Copy(Time, 10,3),-1);
  if (ms = -1) then
    Exit;
  Result := h * 3600000 + m * 60000 + s * 1000 + ms;
end;

//------------------------------------------------------------------------------

function StringConvertPipeToCRLF(s : WideString) : WideString;
var i : integer;
begin
  Result := '';
  for i:=1 to Length(s) do
  begin
    if (s[i] = '|') then
      Result := Result + #13#10
    else
      Result := Result + s[i]
  end;
end;

//------------------------------------------------------------------------------

function StringConvertCRLFToPipe(s : WideString) : WideString;
var i : integer;
begin
  Result := '';
  i := 1;
  while (i <= Length(s)) do
  begin
    if (s[i] = #13) then
    begin
      Result := Result + '|';
      Inc(i);
    end
    else
      Result := Result + s[i];
    Inc(i);
  end;
end;

//------------------------------------------------------------------------------

function StringConvertPipeToBR(s : WideString) : WideString;
var i : integer;
begin
  Result := '';
  for i:=1 to Length(s) do
  begin
    if (s[i] = '|') then
      Result := Result + '<br>'
    else
      Result := Result + s[i]
  end;
end;

//------------------------------------------------------------------------------

function GetFileVersionComponents(Filename : string; var c1, c2, c3, c4 : Integer) : Boolean;
var VersionInfoSize : Cardinal;
    dwHandle : Cardinal;
    VersionInfo : Pointer;
    VersionValue : PVSFixedFileInfo;
    VersionValueSize : Cardinal;
begin
  Result := False;
  c1 := 0; c2 := 0; c3 := 0; c4 := 0;
  VersionInfoSize := GetFileVersionInfoSize(PAnsiChar(Filename), dwHandle);
  if (VersionInfoSize > 0) then
  begin
    GetMem(VersionInfo, VersionInfoSize);
    if GetFileVersionInfo(PAnsiChar(Filename), dwHandle, VersionInfoSize, VersionInfo) then
    begin
      if VerQueryValue(VersionInfo, '\', Pointer(VersionValue), VersionValueSize) then
      begin
        Result := True;      
        c1 := VersionValue.dwFileVersionMS shr 16;
        c2 := VersionValue.dwFileVersionMS and $FFFF;
        c3 := VersionValue.dwFileVersionLS shr 16;
        c4 := VersionValue.dwFileVersionLS and $FFFF;
      end;
    end;
    FreeMem(VersionInfo, VersionInfoSize);
  end;
end;

//------------------------------------------------------------------------------

function GetFileVersionString(Filename : string) : string;
var c1, c2, c3, c4 : Integer;
begin
  if GetFileVersionComponents(Filename, c1, c2, c3, c4) then
    Result := Format('%d.%d.%d.%d', [c1, c2, c3, c4])
  else
    Result := '';
end;

//==============================================================================
// Class that keep the file version
//==============================================================================

constructor TFileVersion.Create(Filename : string);
begin
  FFileParsed := False;
  FFilename := Filename;
end;

//------------------------------------------------------------------------------

function TFileVersion.ParseFile : Boolean;
var c1, c2, c3, c4 : Integer;
begin
  Result := GetFileVersionComponents(FFilename, c1, c2, c3, c4);
  FFileParsed := True;
  FVersionString := Format('%d.%d.%d.%d', [c1, c2, c3, c4]);
  if c3 <> 0 then
    FShortVersionString := Format('%d.%d.%d', [c1, c2, c3])
  else
    FShortVersionString := Format('%d.%d', [c1, c2]);
end;

//------------------------------------------------------------------------------

function TFileVersion.GetVersionString : string;
begin
  if not FFileParsed then
    ParseFile;
  Result := FVersionString;
end;

//------------------------------------------------------------------------------

function TFileVersion.GetShortVersionString : string;
begin
  if not FFileParsed then
    ParseFile;
  Result := FShortVersionString;
end;

//==============================================================================
// Equivalent of Pos but on TStream
//==============================================================================

function PosStream(SubString : string; Stream : TStream; StartPos : Integer = -1) : Integer;
var i : Integer;
    c : Char;
    OriginalPos : Int64;
begin
  Result := -1;
  OriginalPos := Stream.Position;
  if StartPos <> -1 then
    Stream.Seek(StartPos, soFromBeginning);
  i := 1;
  while (Stream.Read(c,1) = 1) do
  begin
    if SubString[i] = c then
    begin
      if (i = Length(SubString)) then
      begin
        Result := Stream.Position - i;
        Break;
      end;
      Inc(i);
    end
    else
      i := 1
  end;
  // Restore position
  Stream.Position := OriginalPos;
end;

// -----------------------------------------------------------------------------

function PosStreamEx(SubString : string; Stream : TStream; StartPos, StopPos : Integer) : Integer;
var i : Integer;
    c : Char;
    OriginalPos : Int64;
    WalkLen : Integer;
begin
  Result := -1;
  OriginalPos := Stream.Position;
  Stream.Seek(StartPos, soFromBeginning);
  WalkLen := StopPos - StartPos;
  i := 1;
  while (Stream.Read(c,1) = 1) and (WalkLen > 0) do
  begin
    if SubString[i] = c then
    begin
      if (i = Length(SubString)) then
      begin
        Result := Stream.Position - i;
        Break;
      end;
      Inc(i);
    end
    else
      i := 1;
    Dec(WalkLen);
  end;
  // Restore position
  Stream.Position := OriginalPos;
end;

//==============================================================================

// From Indy components a bit modified
function URLDecode(ASrc: string): string;
var
  i: integer;
  ESC: string[2];
  CharCode: integer;
begin
  Result := '';
  ASrc := StringReplace(ASrc, '+', ' ', [rfReplaceAll]);
  i := 1;
  while i <= Length(ASrc) do
  begin
    if ASrc[i] <> '%' then
    begin
      Result := Result + ASrc[i]
    end
    else
    begin
      Inc(i); // skip the % char
      ESC := Copy(ASrc, i, 2); // Copy the escape code
      Inc(i, 1); // Then skip it.
      CharCode := StrToIntDef('$' + ESC, -1);
      if (CharCode > 0) and (CharCode < 256) then begin
        Result := Result + Char(CharCode);
      end;
    end;
    Inc(i);
  end;
end;

// =============================================================================
// Shell extension registration
// =============================================================================

procedure ShellRegisterExtension(Extension, Name, Executable : string);
var
  Reg: TRegistry;
  s : string;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CLASSES_ROOT;
    // Add extension
    Reg.OpenKey('.' + Extension, True);
    try
      s := Reg.ReadString('');
      if (s <> '') and (s <> Name + '.Document') then
      begin
        // Save key
        Reg.WriteString(Name + '.sav', s);
      end;
      Reg.WriteString('', Name + '.Document');
    finally
      Reg.CloseKey;
    end;
    Reg.CreateKey(Name + '.Document');
    // Add command
    Reg.OpenKey(Name + '.Document\shell\open\command', True);
    try
      Reg.WriteString('', Executable + ' "%1"');
    finally
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nil, nil);
end;

//------------------------------------------------------------------------------

function ShellIsExtensionRegistered(Extension, Name, Executable : string) : Boolean;
var
  Reg: TRegistry;
  s : string;
begin
  Result := False;
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CLASSES_ROOT;
    if Reg.OpenKey('.' + Extension, False) = True then
    begin
      s := Reg.ReadString('');
      Reg.CloseKey;
      if (Name + '.Document') = s then
      begin
        if Reg.OpenKey(Name + '.Document\shell\open\command', False) = True then
        begin
          s := Reg.ReadString('');
          Reg.CloseKey;
          if (Executable + ' "%1"') = s then
            Result := True;
        end;
      end;
    end
  finally
    Reg.Free;
  end;
end;

//------------------------------------------------------------------------------

procedure ShellUnRegisterExtension(Extension, Name, Executable : string);
var
  Reg: TRegistry;
  s : string;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CLASSES_ROOT;
    if Reg.OpenKey('.' + Extension, False) = True then
    begin
      s := Reg.ReadString(Name + '.sav');
      if (s <> '') then
      begin
        // restore
        Reg.WriteString('', s);
        // delete '.sav'
        Reg.DeleteValue(Name + '.sav');
        Reg.CloseKey;
      end
      else
      begin
        // nothing to restore delete whole key
        Reg.CloseKey;
        Reg.DeleteKey('.' + Extension);
      end;
    end;
    // Delete our command key
    Reg.DeleteKey(Name + '.Document');
  finally
    Reg.Free;
  end;
end;

// -----------------------------------------------------------------------------

function ReadLineStream(Stream : TStream; var s : string) : Boolean;
var c : Char;
begin
  s := '';
  while Stream.Read(c,1) = 1 do
  begin
    if (c = #10) then
      Break
    else if (c = #13) then
      Continue;
    s := s + c;
  end;
  Result := (Stream.Position = Stream.Size) and (s = '');
end;

// -----------------------------------------------------------------------------
end.
// -----------------------------------------------------------------------------
