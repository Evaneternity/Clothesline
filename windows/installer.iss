#define AppVersion "0.1.0"
[Setup]
AppId={{89B942D0-A74F-4143-80EC-284A030847C4}
AppName=Clothesline
AppVersion={#AppVersion}
AppVerName=Clothesline Windows 0.1.0-rc.1
DefaultDirName={localappdata}\Programs\Clothesline
DefaultGroupName=Clothesline
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir=..\build\windows\dist
OutputBaseFilename=Clothesline-0.1.0-windows-rc.1-x64-Setup
SetupIconFile=..\assets\clothesline.ico
UninstallDisplayIcon={app}\Clothesline.exe
LicenseFile=..\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
[Files]
Source: "..\build\windows\publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\Clothesline"; Filename: "{app}\Clothesline.exe"
Name: "{group}\Uninstall Clothesline"; Filename: "{uninstallexe}"
[Run]
Filename: "{app}\Clothesline.exe"; Description: "Launch Clothesline"; Flags: nowait postinstall skipifsilent
[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var Command: String;
begin
  if CurUninstallStep = usUninstall then
    if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Clothesline', Command) then
      if CompareText(Command, '"' + ExpandConstant('{app}\Clothesline.exe') + '"') = 0 then
        RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Clothesline');
end;
