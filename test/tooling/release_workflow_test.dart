import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _tagGuard = "if: startsWith(github.ref, 'refs/tags/v')";
const String _pullRequestGuard =
    r"if: ${{ !startsWith(github.ref, 'refs/tags/v') }}";
const String _version = r'${{ steps.version.outputs.version }}';
const Map<String, String> _buildTargets = <String, String>{
  'macos': 'macos',
  'windows': 'windows',
  'android': 'apk',
};
const List<String> _signingSecrets = <String>[
  'ANDROID_KEYSTORE_BASE64',
  'ANDROID_KEYSTORE_PASSWORD',
  'ANDROID_KEY_ALIAS',
  'ANDROID_KEY_PASSWORD',
];
const String _signingError =
    '::error::Set the ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, '
    'ANDROID_KEY_ALIAS and ANDROID_KEY_PASSWORD repository secrets to sign '
    'the release APK.';

String _workflow() => File('.github/workflows/release.yml').readAsStringSync();

String _job(String workflow, String name) {
  final List<String> lines = workflow.split('\n');
  final int jobs = lines.indexOf('jobs:');
  expect(jobs, isNot(-1), reason: 'release.yml must declare jobs:');
  final int start = lines.indexOf('  $name:', jobs);
  expect(start, isNot(-1), reason: 'release.yml must declare a $name job');
  final int end = lines.indexWhere(
    (String line) => RegExp(r'^ {0,2}\S').hasMatch(line),
    start + 1,
  );
  return lines.sublist(start, end == -1 ? lines.length : end).join('\n');
}

List<String> _steps(String job) {
  final int start = job.indexOf('\n    steps:\n');
  expect(start, isNot(-1), reason: 'every job must declare steps:');
  return job
      .substring(start)
      .split(RegExp(r'^(?=      - )', multiLine: true))
      .skip(1)
      .map((String candidate) => candidate.trimRight())
      .toList();
}

int _stepIndex(List<String> steps, String needle) {
  final int index = steps.indexWhere(
    (String candidate) => candidate.contains(needle),
  );
  expect(index, isNot(-1), reason: 'no step contains $needle');
  return index;
}

String _script(String step) {
  final List<String> lines = step.split('\n');
  final int start = lines.indexWhere((String line) => line.trim() == 'run: |');
  expect(start, isNot(-1), reason: 'the step must run a block script');
  return lines
      .sublist(start + 1)
      .takeWhile((String line) => line.isEmpty || line.startsWith('          '))
      .map((String line) => line.isEmpty ? line : line.substring(10))
      .join('\n');
}

ProcessResult _bash(
  String script,
  Directory directory,
  Map<String, String> environment,
) {
  return Process.runSync(
    '/bin/bash',
    <String>['--noprofile', '--norc', '-eo', 'pipefail', '-c', script],
    workingDirectory: directory.path,
    environment: <String, String>{'PATH': '/usr/bin:/bin', ...environment},
    includeParentEnvironment: false,
  );
}

Directory _scratch() {
  final Directory directory = Directory.systemTemp.createTempSync(
    'release_workflow_test',
  );
  addTearDown(() => directory.deleteSync(recursive: true));
  return directory;
}

void main() {
  test(
    'a version tag builds all three platforms and publishes one release',
    () {
      final String workflow = _workflow();

      expect(workflow, startsWith('name: release\n'));
      expect(workflow, contains("on:\n  push:\n    tags:\n      - 'v*'\n"));
      expect(workflow, contains('\npermissions:\n  contents: read\n'));

      const Map<String, String> runners = <String, String>{
        'macos': 'macos-latest',
        'windows': 'windows-latest',
        'android': 'ubuntu-latest',
      };
      for (final MapEntry<String, String> runner in runners.entries) {
        final String job = _job(workflow, runner.key);
        expect(job, contains('\n    runs-on: ${runner.value}\n'));
        expect(job, contains('- uses: actions/checkout@v7\n'));
        expect(
          job,
          contains(
            '- uses: subosito/flutter-action@v2\n'
            '        with:\n'
            "          flutter-version: '3.47.5'\n"
            '          channel: stable\n'
            '          cache: true\n',
          ),
        );
        expect(job, contains('run: flutter pub get\n'));
        expect(
          job,
          contains(
            'run: dart run build_runner build --delete-conflicting-outputs\n',
          ),
        );
        expect(job, isNot(contains('contents: write')));
        expect(job, isNot(contains('gh release')));
      }

      final String release = _job(workflow, 'release');
      expect(release, contains('\n    needs: [macos, windows, android]\n'));
      expect(release, contains('\n    $_tagGuard\n'));
      expect(release, contains('\n    runs-on: ubuntu-latest\n'));
      expect(release, contains('\n    permissions:\n      contents: write\n'));
      expect(release, isNot(contains('always()')));
      expect(release, isNot(contains('cancelled()')));
      expect(release, isNot(contains('failure()')));

      final List<String> steps = _steps(release);
      final int checkout = _stepIndex(steps, 'uses: actions/checkout@v7');
      final int version = _stepIndex(
        steps,
        r'echo "VERSION=${GITHUB_REF_NAME#v}" >> "$GITHUB_ENV"',
      );
      final int download = _stepIndex(
        steps,
        'uses: actions/download-artifact@v8',
      );
      final int checksums = _stepIndex(steps, 'sha256sum');
      final int publish = _stepIndex(steps, 'gh release create');
      expect(checkout, 0);
      expect(version, greaterThan(checkout));
      expect(download, greaterThan(version));
      expect(checksums, greaterThan(download));
      expect(publish, greaterThan(checksums));

      expect(steps[version], contains('shell: bash'));
      expect(steps[download], contains('path: dist\n'));
      expect(steps[download], contains('merge-multiple: true'));
      expect(steps[download], isNot(contains('name:')));
      expect(steps[checksums], contains('working-directory: dist\n'));
      expect(
        steps[checksums],
        contains(
          r'sha256sum "field-notes-$VERSION-macos.dmg" '
          r'"field-notes-$VERSION-windows-x64-setup.exe" '
          r'"field-notes-$VERSION-android.apk" > SHA256SUMS.txt',
        ),
      );

      final String publishStep = steps[publish];
      expect(publishStep, contains(r'GH_TOKEN: ${{ github.token }}'));
      expect(
        publishStep,
        contains(
          r'gh release create "$GITHUB_REF_NAME" --repo "$GITHUB_REPOSITORY" '
          r'--title "Field Notes $VERSION" '
          '--notes-file tool/release/release_notes.md',
        ),
      );
      for (final String asset in <String>[
        r'"dist/field-notes-$VERSION-macos.dmg"',
        r'"dist/field-notes-$VERSION-windows-x64-setup.exe"',
        r'"dist/field-notes-$VERSION-android.apk"',
        'dist/SHA256SUMS.txt',
      ]) {
        expect(publishStep, contains(asset));
      }
      expect(publishStep, contains(r'if [[ "$VERSION" == *-* ]]; then'));
      expect(publishStep, contains('prerelease=(--prerelease)'));
      expect(publishStep, contains(r'"${prerelease[@]}"'));

      expect('gh release create'.allMatches(workflow), hasLength(1));
      expect(File('tool/release/release_notes.md').existsSync(), isTrue);
    },
  );

  test('every build job reads one version value', () {
    final String workflow = _workflow();
    final Set<String> versionSteps = <String>{};

    for (final MapEntry<String, String> target in _buildTargets.entries) {
      final String job = _job(workflow, target.key);
      final List<String> steps = _steps(job);
      final int version = _stepIndex(steps, '\n        id: version\n');
      final String step = steps[version];
      versionSteps.add(step);

      expect(step, contains('\n        shell: bash\n'));
      expect(step, contains(r'version="${GITHUB_REF_NAME#v}"'));
      expect(step, contains(r'version="${name}-pr${GITHUB_RUN_NUMBER}"'));
      expect(step, contains(r'echo "version=$version" >> "$GITHUB_OUTPUT"'));

      for (int index = 0; index < steps.length; index++) {
        if (steps[index].contains('steps.version.outputs.version')) {
          expect(index, greaterThan(version));
        }
      }

      expect(
        RegExp(r'\$\{?VERSION\b').hasMatch(job),
        isFalse,
        reason: 'the ${target.key} job must not read \$VERSION',
      );
      expect(
        RegExp(r'\$env:VERSION\b', caseSensitive: false).hasMatch(job),
        isFalse,
        reason: 'the ${target.key} job must not read \$env:VERSION',
      );

      final List<String> builds = steps
          .where((String candidate) => candidate.contains('flutter build'))
          .toList();
      expect(builds, hasLength(2));
      final String tagged = builds.singleWhere(
        (String candidate) => candidate.contains(_tagGuard),
      );
      expect(
        tagged,
        endsWith(
          'run: flutter build ${target.value} --release '
          '--build-name $_version --build-number \${{ github.run_number }}',
        ),
      );
      final String untagged = builds.singleWhere(
        (String candidate) => candidate.contains(_pullRequestGuard),
      );
      expect(
        untagged,
        endsWith('run: flutter build ${target.value} --release'),
      );
    }

    expect(versionSteps, hasLength(1));

    final String macos = _job(workflow, 'macos');
    expect(macos, contains('"field-notes-$_version-macos.dmg"'));
    expect(macos, contains('path: field-notes-$_version-macos.dmg\n'));

    final String windows = _job(workflow, 'windows');
    expect(windows, contains('"/DAppVersion=$_version"'));
    expect(
      windows,
      contains('"/DOutputBaseName=field-notes-$_version-windows-x64-setup"'),
    );

    final String android = _job(workflow, 'android');
    expect(android, contains('"field-notes-$_version-android.apk"'));
    expect(android, contains('path: field-notes-$_version-android.apk\n'));
  });

  test('the version step names tag and pull-request builds', () {
    final String step = _steps(_job(_workflow(), 'macos')).singleWhere(
      (String candidate) => candidate.contains('\n        id: version\n'),
    );
    final String script = _script(step);
    final Directory directory = _scratch();
    File('pubspec.yaml').copySync('${directory.path}/pubspec.yaml');
    final String name = RegExp(
      r'^version:\s*([^+\s]+)',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;

    (int, String, String) run(String ref, String refName) {
      final File output = File('${directory.path}/output')
        ..writeAsStringSync('');
      final ProcessResult result = _bash(script, directory, <String, String>{
        'GITHUB_REF': ref,
        'GITHUB_REF_NAME': refName,
        'GITHUB_RUN_NUMBER': '42',
        'GITHUB_OUTPUT': output.path,
      });
      return (
        result.exitCode,
        result.stdout as String,
        output.readAsStringSync(),
      );
    }

    expect(run('refs/tags/v1.2.0', 'v1.2.0'), (0, '', 'version=1.2.0\n'));
    expect(run('refs/tags/v1.2.0-beta.1', 'v1.2.0-beta.1'), (
      0,
      '',
      'version=1.2.0-beta.1\n',
    ));
    expect(run('refs/pull/7/merge', '7/merge'), (
      0,
      '',
      'version=$name-pr42\n',
    ));
    expect(run('refs/heads/main', 'main'), (0, '', 'version=$name-pr42\n'));

    final (int code, String stdout, String written) = run(
      r'refs/tags/v1.2.0$(id)',
      r'v1.2.0$(id)',
    );
    expect(code, isNot(0));
    expect(stdout, startsWith('::error::'));
    expect(written, isEmpty);
  });

  test('pull requests build every platform without publishing', () {
    final String workflow = _workflow();
    final List<String> lines = workflow.split('\n');
    final int trigger = lines.indexOf('  pull_request:');
    expect(trigger, isNot(-1));
    expect(lines[trigger + 1], '    paths:');
    final List<String> paths = lines
        .sublist(trigger + 2)
        .takeWhile((String line) => line.startsWith('      - '))
        .map((String line) => line.trim())
        .toList();
    expect(paths, hasLength(8));
    expect(paths.toSet(), <String>{
      "- 'windows/**'",
      "- 'macos/**'",
      "- 'android/**'",
      "- 'lib/**'",
      "- 'pubspec.yaml'",
      "- 'pubspec.lock'",
      "- '.github/workflows/release.yml'",
      "- 'tool/release/**'",
    });
    expect(workflow, contains('\n  workflow_dispatch:\n'));
    expect(
      workflow,
      contains(
        '\nconcurrency:\n'
        r'  group: release-${{ github.ref }}'
        '\n'
        r"  cancel-in-progress: ${{ github.event_name == 'pull_request' }}"
        '\n',
      ),
    );

    for (final String name in _buildTargets.keys) {
      final String job = _job(workflow, name);
      final List<String> steps = _steps(job);
      final int upload = _stepIndex(steps, 'uses: actions/upload-artifact@v7');
      expect(upload, steps.length - 1);
      expect(steps[upload], contains('\n          name: $name\n'));
      expect(steps[upload], endsWith('if-no-files-found: error'));
      expect(steps[upload], isNot(contains('if:')));
      expect(job, isNot(contains('\n    if:')));
      expect(job, isNot(contains('permissions:')));
      expect(job, isNot(contains('gh release')));
      for (final String step in steps) {
        if (step.contains('secrets.')) {
          expect(step, contains('\n        $_tagGuard\n'));
        }
      }
    }
    expect(_job(workflow, 'windows'), contains('          path: dist/*.exe\n'));

    final String release = _job(workflow, 'release');
    expect(release, contains('\n    $_tagGuard\n'));
  });

  test('the Windows build carries the Visual C++ runtime', () {
    final String job = _job(_workflow(), 'windows');
    expect(job, contains('\n    defaults:\n      run:\n        shell: pwsh\n'));

    final List<String> steps = _steps(job);
    final int build = steps.lastIndexWhere(
      (String candidate) =>
          candidate.contains('flutter build windows --release'),
    );
    final int runtime = _stepIndex(steps, 'vcruntime140_1.dll');
    final int installer = _stepIndex(steps, 'run: iscc ');
    expect(build, isNot(-1));
    expect(runtime, greaterThan(build));
    expect(installer, greaterThan(runtime));

    final String step = steps[runtime];
    expect(
      step,
      contains(
        r'$release = Join-Path $env:GITHUB_WORKSPACE '
        r"'build\windows\x64\runner\Release'",
      ),
    );
    expect(
      step,
      contains(
        r"if (-not (Test-Path -LiteralPath (Join-Path $release 'field_notes.exe'))) {",
      ),
    );
    expect(
      step,
      contains(
        r"foreach ($dll in @('msvcp140.dll', 'vcruntime140.dll', "
        r"'vcruntime140_1.dll')) {",
      ),
    );
    expect(step, contains(r"$source = Join-Path 'C:\Windows\System32' $dll"));
    expect(step, contains(r'if (-not (Test-Path -LiteralPath $source)) {'));
    expect(
      step,
      contains(r'Copy-Item -LiteralPath $source -Destination $release -Force'),
    );
    expect('exit 1'.allMatches(step), hasLength(2));
    expect(step.indexOf('field_notes.exe'), lessThan(step.indexOf('foreach')));

    final String iscc = steps[installer];
    expect(
      iscc,
      contains(
        r'"/DSourceDir=$env:GITHUB_WORKSPACE\build\windows\x64\runner\Release"',
      ),
    );
    expect(iscc, contains(r'"/O$env:GITHUB_WORKSPACE\dist"'));
    expect(iscc, endsWith(r'tool\release\windows\field_notes.iss'));
  });

  test('a tag build refuses to ship without the signing secrets', () {
    final String workflow = _workflow();
    final List<String> steps = _steps(_job(workflow, 'android'));

    final String java = steps[_stepIndex(steps, 'uses: actions/setup-java@v6')];
    expect(java, contains('distribution: temurin\n'));
    expect(java, endsWith("java-version: '17'"));

    final int signing = _stepIndex(steps, 'android/key.properties');
    final int build = _stepIndex(steps, '--build-name');
    expect(signing, lessThan(build));

    final String step = steps[signing];
    expect(step, contains('\n        $_tagGuard\n'));
    expect(step, contains('\n        shell: bash\n'));
    for (final String secret in _signingSecrets) {
      expect(step, contains('$secret: \${{ secrets.$secret }}\n'));
      expect(step, contains('-z "\$$secret"'));
    }
    expect(step, contains('echo "$_signingError"\n'));
    expect(step, contains('exit 1'));
    expect(
      step,
      contains(
        r'''printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > android/app/release.jks''',
      ),
    );
    expect(
      step,
      contains(r'''printf 'storePassword=%s\n' "$ANDROID_KEYSTORE_PASSWORD"'''),
    );
    expect(
      step,
      contains(r'''printf 'keyPassword=%s\n' "$ANDROID_KEY_PASSWORD"'''),
    );
    expect(step, contains(r'''printf 'keyAlias=%s\n' "$ANDROID_KEY_ALIAS"'''));
    expect(step, contains(r"printf 'storeFile=release.jks\n'"));
    expect(step, endsWith('} > android/key.properties'));

    expect('secrets.'.allMatches(workflow), hasLength(4));
  });

  test(
    'the signing step writes key.properties only when every secret is set',
    () {
      final String gradle = File('android/app/build.gradle.kts')
          .readAsStringSync();
      expect(gradle, contains('rootProject.file("key.properties")'));
      expect(
        gradle,
        contains(
          'storeFile = file(keystoreProperties.getProperty("storeFile"))',
        ),
      );

      final String step = _steps(_job(_workflow(), 'android')).singleWhere(
        (String candidate) => candidate.contains('android/key.properties'),
      );
      final String script = _script(step);
      final Directory directory = _scratch();
      Directory('${directory.path}/android/app').createSync(recursive: true);
      final File properties = File('${directory.path}/android/key.properties');
      final File keystore = File('${directory.path}/android/app/release.jks');
      final Map<String, String> secrets = <String, String>{
        'ANDROID_KEYSTORE_BASE64': base64Encode(<int>[1, 2, 3, 250]),
        'ANDROID_KEYSTORE_PASSWORD': 'store-secret',
        'ANDROID_KEY_ALIAS': 'upload',
        'ANDROID_KEY_PASSWORD': 'key-secret',
      };

      for (final String missing in _signingSecrets) {
        final ProcessResult refused = _bash(script, directory, <String, String>{
          ...secrets,
          missing: '',
        });
        expect(refused.exitCode, 1, reason: 'an empty $missing must fail');
        expect(refused.stdout, '$_signingError\n');
        expect(properties.existsSync(), isFalse);
        expect(keystore.existsSync(), isFalse);
      }

      final ProcessResult signed = _bash(script, directory, secrets);
      expect(signed.exitCode, 0, reason: '${signed.stderr}');
      expect(keystore.readAsBytesSync(), <int>[1, 2, 3, 250]);
      expect(properties.readAsLinesSync(), <String>[
        'storePassword=store-secret',
        'keyPassword=key-secret',
        'keyAlias=upload',
        'storeFile=release.jks',
      ]);
    },
  );

  test('the macOS job packs Field Notes.app into a disk image', () {
    final List<String> steps = _steps(_job(_workflow(), 'macos'));
    final int build = steps.lastIndexWhere(
      (String candidate) => candidate.contains('flutter build macos --release'),
    );
    final int pack = _stepIndex(steps, 'tool/release/macos/make_dmg.sh');
    final int upload = _stepIndex(steps, 'uses: actions/upload-artifact@v7');
    expect(build, isNot(-1));
    expect(pack, greaterThan(build));
    expect(upload, greaterThan(pack));
    expect(
      steps[pack],
      endsWith(
        'run: bash tool/release/macos/make_dmg.sh '
        '"build/macos/Build/Products/Release/Field Notes.app" '
        '"field-notes-$_version-macos.dmg"',
      ),
    );
    expect(
      File('macos/Runner/Configs/AppInfo.xcconfig').readAsStringSync(),
      contains('PRODUCT_NAME = Field Notes\n'),
    );

    final String script = File('tool/release/macos/make_dmg.sh')
        .readAsStringSync();
    expect(script, startsWith('#!/usr/bin/env bash\nset -euo pipefail\n'));
    expect(script, contains('app="\$1"\noutput="\$2"\n'));
    expect(script, contains(r'stage="$(mktemp -d)"'));
    expect(script, contains(r'''trap 'rm -rf "$stage"' EXIT'''));
    expect(script, contains(r'ditto "$app" "$stage/$(basename "$app")"'));
    expect(script, contains(r'ln -s /Applications "$stage/Applications"'));
    expect(
      script,
      contains(
        r'''hdiutil create -volname 'Field Notes' -srcfolder "$stage" -ov -format UDZO "$output"''',
      ),
    );
    expect(script, isNot(contains('codesign')));
  });
}
