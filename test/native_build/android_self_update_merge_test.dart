import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const String _androidProject = 'android';
const String _intermediates = 'build/app/intermediates';
const String _permission = 'android.permission.REQUEST_INSTALL_PACKAGES';
const String _receiver =
    'dev.satanshumishra.field_notes.UpdateReplacedReceiver';
const Duration _limit = Duration(minutes: 6);

typedef _Finished = ({int code, String stdout, String stderr});

String get _flutter {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  return root == null || root.isEmpty
      ? 'flutter'
      : p.join(root, 'bin', 'flutter');
}

Future<_Finished> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  final Process process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  final Future<String> stdout = process.stdout
      .transform(const Utf8Decoder(allowMalformed: true))
      .join();
  final Future<String> stderr = process.stderr
      .transform(const Utf8Decoder(allowMalformed: true))
      .join();
  final int code = await process.exitCode.timeout(
    _limit,
    onTimeout: () {
      process.kill();
      return -1;
    },
  );
  return (code: code, stdout: await stdout, stderr: await stderr);
}

Future<Map<String, String>> _gradleEnvironment() async {
  final String? configured = Platform.environment['JAVA_HOME'];
  if (configured != null && configured.isNotEmpty) {
    return <String, String>{};
  }
  final _Finished config = await _run(_flutter, <String>[
    'config',
    '--machine',
  ]);
  final int start = config.stdout.indexOf('{');
  if (config.code != 0 || start == -1) {
    return <String, String>{};
  }
  final Object? settings = jsonDecode(config.stdout.substring(start));
  final Object? jdk = settings is Map ? settings['jdk-dir'] : null;
  return jdk is String && jdk.isNotEmpty
      ? <String, String>{'JAVA_HOME': jdk}
      : <String, String>{};
}

Future<String> _mergedReleaseManifest(
  Map<String, String> environment, {
  required bool selfUpdate,
}) async {
  final DateTime started = DateTime.now().subtract(const Duration(seconds: 1));
  final _Finished merge = await _run(
    p.join('.', 'gradlew'),
    <String>[
      '-q',
      ':app:processReleaseMainManifest',
      '--rerun',
      if (selfUpdate) '-PfieldNotesSelfUpdate=true',
    ],
    workingDirectory: _androidProject,
    environment: environment,
  );
  expect(
    merge.code,
    0,
    reason:
        'the release manifest merge failed:\n${merge.stdout}${merge.stderr}',
  );
  final List<File> merged = Directory(_intermediates)
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (File file) =>
            p.basename(file.path) == 'AndroidManifest.xml' &&
            file.path.contains('merged_manifest') &&
            file.path.contains('release'),
      )
      .toList(growable: false);
  expect(merged, isNotEmpty, reason: 'the merge wrote no release manifest');
  final File newest = merged.reduce(
    (File a, File b) =>
        a.lastModifiedSync().isAfter(b.lastModifiedSync()) ? a : b,
  );
  expect(
    newest.lastModifiedSync().isBefore(started),
    isFalse,
    reason: '${newest.path} was not written by this merge',
  );
  return newest.readAsStringSync();
}

void main() {
  test('only the self-updating build merges the install permission', () async {
    if (!File('$_androidProject/local.properties').existsSync() ||
        !File('$_androidProject/gradlew').existsSync()) {
      final _Finished configured = await _run(_flutter, <String>[
        'build',
        'apk',
        '--config-only',
      ]);
      expect(
        configured.code,
        0,
        reason: '${configured.stdout}${configured.stderr}',
      );
    }
    final Map<String, String> environment = await _gradleEnvironment();

    final String selfUpdating = await _mergedReleaseManifest(
      environment,
      selfUpdate: true,
    );
    expect(selfUpdating, contains('package="dev.satanshumishra.field_notes"'));
    expect(
      RegExp('<uses-permission\\s+android:name="${RegExp.escape(_permission)}"')
          .hasMatch(selfUpdating),
      isTrue,
    );
    final RegExpMatch? receiver = RegExp(
      '<receiver\\b[^>]*android:name="${RegExp.escape(_receiver)}"[^>]*>',
    ).firstMatch(selfUpdating);
    expect(receiver, isNotNull, reason: 'UpdateReplacedReceiver is missing');
    expect(receiver!.group(0), contains('android:exported="false"'));

    final String store = await _mergedReleaseManifest(
      environment,
      selfUpdate: false,
    );
    expect(store, contains('package="dev.satanshumishra.field_notes"'));
    expect(store, isNot(contains(_permission)));
    expect(store, isNot(contains('UpdateReplacedReceiver')));
  }, timeout: const Timeout(_limit));
}
