#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir AddBackslash(SourcePath) + "..\..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputBaseName
  #define OutputBaseName "field-notes-" + AppVersion + "-windows-x64-setup"
#endif

[Setup]
AppId={{221D3C8A-133F-4449-A299-0C4F9690F2A2}
AppName=Field Notes
AppVersion={#AppVersion}
AppPublisher=dev.satanshumishra
DefaultDirName={localappdata}\Programs\Field Notes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputBaseFilename={#OutputBaseName}
SetupIconFile={#AddBackslash(SourcePath)}..\..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\field_notes.exe
CloseApplications=yes
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Field Notes"; Filename: "{app}\field_notes.exe"; AppUserModelID: "dev.satanshumishra.FieldNotes"; AppUserModelToastActivatorCLSID: "D6A0FDC5-EAD0-45F8-9024-F50F093EE5B2"

[Run]
Filename: "{app}\field_notes.exe"; Description: "Launch Field Notes"; Flags: nowait postinstall skipifsilent
