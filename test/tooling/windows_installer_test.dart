import 'dart:io';

import 'package:field_notes/features/reminders/local_notifications_reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const String _scriptPath = 'tool/release/windows/field_notes.iss';
const String _scriptFolder = 'tool/release/windows';
const String _sourcePath = '{#AddBackslash(SourcePath)}';

Map<String, List<String>> _sections(String script) {
  final List<RegExpMatch> headers = RegExp(
    r'^\[(\w+)\]$',
    multiLine: true,
  ).allMatches(script).toList();
  return <String, List<String>>{
    for (int index = 0; index < headers.length; index++)
      headers[index].group(1)!: script
          .substring(
            headers[index].end,
            index + 1 < headers.length
                ? headers[index + 1].start
                : script.length,
          )
          .split('\n')
          .map((String line) => line.trim())
          .where((String line) => line.isNotEmpty)
          .toList(),
  };
}

Map<String, String> _directives(List<String> lines) => <String, String>{
  for (final String line in lines)
    line.substring(0, line.indexOf('=')): line.substring(line.indexOf('=') + 1),
};

Map<String, String> _entry(String line) => <String, String>{
  for (final String part in line.split(RegExp(r';\s*')))
    part.substring(0, part.indexOf(':')).trim(): part
        .substring(part.indexOf(':') + 1)
        .trim()
        .replaceAll('"', ''),
};

String _repositoryPath(String scriptRelative) =>
    p.normalize(p.join(_scriptFolder, scriptRelative.replaceAll(r'\', '/')));

void main() {
  test("the Windows installer installs per user with the app's identity", () {
    final Map<String, List<String>> sections = _sections(
      File(_scriptPath).readAsStringSync(),
    );
    final Map<String, String> setup = _directives(sections['Setup']!);

    expect(setup['PrivilegesRequired'], 'lowest');
    expect(setup['DefaultDirName'], r'{localappdata}\Programs\Field Notes');
    expect(
      setup['AppId'],
      matches(
        RegExp(
          r'^\{\{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\}$',
        ),
      ),
    );
    expect(setup['AppId'], '{{221D3C8A-133F-4449-A299-0C4F9690F2A2}');
    expect(setup['AppName'], 'Field Notes');
    expect(setup['AppVersion'], '{#AppVersion}');
    expect(setup['AppPublisher'], 'dev.satanshumishra');
    expect(setup['DisableProgramGroupPage'], 'yes');
    expect(setup['ArchitecturesAllowed'], 'x64compatible');
    expect(setup['ArchitecturesInstallIn64BitMode'], 'x64compatible');
    expect(setup['OutputBaseFilename'], '{#OutputBaseName}');
    expect(setup['UninstallDisplayIcon'], r'{app}\field_notes.exe');
    expect(setup['CloseApplications'], 'yes');
    expect(setup['Compression'], 'lzma2');
    expect(setup['SolidCompression'], 'yes');
    expect(setup['WizardStyle'], 'modern');

    expect(sections['Files'], <String>[
      r'Source: "{#SourceDir}\*"; DestDir: "{app}"; '
          'Flags: recursesubdirs createallsubdirs ignoreversion',
    ]);

    expect(sections['Icons'], hasLength(1));
    expect(_entry(sections['Icons']!.single), <String, String>{
      'Name': r'{autoprograms}\Field Notes',
      'Filename': r'{app}\field_notes.exe',
      'AppUserModelID': windowsAppUserModelId,
      'AppUserModelToastActivatorCLSID': windowsNotificationGuid,
    });

    expect(sections['Run'], hasLength(1));
    final Map<String, String> launch = _entry(sections['Run']!.single);
    expect(launch['Filename'], r'{app}\field_notes.exe');
    expect(launch['Description'], 'Launch Field Notes');
    expect(launch['Flags']!.split(' ').toSet(), <String>{
      'nowait',
      'postinstall',
      'skipifsilent',
    });

    expect(
      File('windows/CMakeLists.txt').readAsStringSync(),
      contains('set(BINARY_NAME "field_notes")'),
    );
  });

  test(
    'the installer takes its version, source and name from the command line',
    () {
      final String script = File(_scriptPath).readAsStringSync();

      for (final String name in <String>[
        'AppVersion',
        'SourceDir',
        'OutputBaseName',
      ]) {
        expect(
          RegExp(
            '^#ifndef $name\\n  #define $name .+\\n#endif\$',
            multiLine: true,
          ).hasMatch(script),
          isTrue,
          reason: '$name must have a default that /D$name overrides',
        );
      }
      expect(script, contains('#define AppVersion "0.0.0"\n'));
      expect(
        script,
        contains(
          '#define OutputBaseName "field-notes-" + AppVersion + '
          '"-windows-x64-setup"\n',
        ),
      );

      final RegExpMatch source = RegExp(
        r'^  #define SourceDir AddBackslash\(SourcePath\) \+ "(.+)"$',
        multiLine: true,
      ).firstMatch(script)!;
      expect(
        _repositoryPath(source.group(1)!),
        p.normalize('build/windows/x64/runner/Release'),
      );

      final Map<String, String> setup = _directives(
        _sections(script)['Setup']!,
      );
      final String icon = setup['SetupIconFile']!;
      expect(icon, startsWith(_sourcePath));
      final String iconPath = _repositoryPath(
        icon.substring(_sourcePath.length),
      );
      expect(iconPath, p.normalize('windows/runner/resources/app_icon.ico'));
      expect(File(iconPath).existsSync(), isTrue);
    },
  );
}
