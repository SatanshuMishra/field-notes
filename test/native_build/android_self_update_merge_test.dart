import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const String _androidProject = 'android';
const String _intermediates = 'build/app/intermediates';
const String _testResults = 'build/app/test-results/testDebugUnitTest';
const String _permission = 'android.permission.REQUEST_INSTALL_PACKAGES';
const String _receiver =
    'dev.satanshumishra.field_notes.UpdateReplacedReceiver';
const String _uploadJobService =
    'dev.satanshumishra.field_notes.uploads.UploadJobService';
const String _foregroundService =
    'androidx.work.impl.foreground.SystemForegroundService';
const List<String> _uploadPermissions = <String>[
  'android.permission.FOREGROUND_SERVICE',
  'android.permission.FOREGROUND_SERVICE_DATA_SYNC',
  'android.permission.RUN_USER_INITIATED_JOBS',
];
const List<String> _uploadUnitTests = <String>[
  'dev.satanshumishra.field_notes.uploads.UploadRunnerTest',
  'dev.satanshumishra.field_notes.uploads.UploadItemAddressTest',
];
const Duration _limit = Duration(minutes: 6);
const Duration _unitTestLimit = Duration(minutes: 15);

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
  Duration limit = _limit,
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
    limit,
    onTimeout: () {
      process.kill();
      return -1;
    },
  );
  return (code: code, stdout: await stdout, stderr: await stderr);
}

Future<void> _configureAndroid() async {
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

Set<String> _permissions(String manifest) {
  return RegExp(r'<uses-permission\b[^>]*\bandroid:name="([^"]+)"')
      .allMatches(manifest)
      .map((RegExpMatch match) => match.group(1)!)
      .toSet();
}

String _element(String manifest, String tag, String name) {
  final Iterable<String> elements = RegExp('<$tag\\b[^>]*>')
      .allMatches(manifest)
      .map((RegExpMatch match) => match.group(0)!)
      .where((String element) => element.contains('android:name="$name"'));
  expect(elements, hasLength(1), reason: 'one $tag must be named $name');
  return elements.single;
}

Future<List<String>> _unitTestReports(
  Map<String, String> environment, {
  required bool selfUpdate,
}) async {
  final Directory results = Directory(_testResults);
  if (results.existsSync()) {
    results.deleteSync(recursive: true);
  }
  final _Finished run = await _run(
    p.join('.', 'gradlew'),
    <String>[
      '-q',
      ':app:compileReleaseKotlin',
      ':app:testDebugUnitTest',
      '--rerun',
      if (selfUpdate) '-PfieldNotesSelfUpdate=true',
    ],
    workingDirectory: _androidProject,
    environment: environment,
    limit: _unitTestLimit,
  );
  expect(
    run.code,
    0,
    reason:
        'the compile and unit tests failed with selfUpdate $selfUpdate:\n'
        '${run.stdout}${run.stderr}',
  );
  if (!results.existsSync()) {
    return <String>[];
  }
  return results
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => p.extension(file.path) == '.xml')
      .map((File file) => file.readAsStringSync())
      .toList(growable: false);
}

Set<String> _suites(List<String> reports) {
  return reports
      .expand(
        (String report) =>
            RegExp(r'<testsuite\b[^>]*\bname="([^"]+)"')
                .allMatches(report)
                .map((RegExpMatch match) => match.group(1)!),
      )
      .toSet();
}

void main() {
  test('only the self-updating build merges the install permission', () async {
    await _configureAndroid();
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

  test('only the GitHub APK merges background uploads', () async {
    await _configureAndroid();
    final Map<String, String> environment = await _gradleEnvironment();

    final String store = await _mergedReleaseManifest(
      environment,
      selfUpdate: false,
    );
    expect(store, contains('package="dev.satanshumishra.field_notes"'));
    final Set<String> storePermissions = _permissions(store);
    for (final String permission in _uploadPermissions) {
      expect(storePermissions, isNot(contains(permission)));
    }
    expect(store, isNot(contains('android:foregroundServiceType')));
    expect(store, isNot(contains('UploadJobService')));
    expect(store, isNot(contains('androidx.work')));

    final String selfUpdating = await _mergedReleaseManifest(
      environment,
      selfUpdate: true,
    );
    expect(selfUpdating, contains('package="dev.satanshumishra.field_notes"'));
    expect(_permissions(selfUpdating), containsAll(_uploadPermissions));
    final String jobService = _element(
      selfUpdating,
      'service',
      _uploadJobService,
    );
    expect(
      jobService,
      contains('android:permission="android.permission.BIND_JOB_SERVICE"'),
    );
    expect(jobService, contains('android:exported="true"'));
    expect(
      _element(selfUpdating, 'service', _foregroundService),
      contains('android:foregroundServiceType="dataSync"'),
    );
  }, timeout: Timeout(_limit * 2));

  test(
    'only the GitHub build compiles and runs the upload unit tests',
    () async {
      await _configureAndroid();
      final Map<String, String> environment = await _gradleEnvironment();

      final List<String> selfUpdating = await _unitTestReports(
        environment,
        selfUpdate: true,
      );
      expect(_suites(selfUpdating), containsAll(_uploadUnitTests));

      final List<String> store = await _unitTestReports(
        environment,
        selfUpdate: false,
      );
      for (final String report in store) {
        expect(report, isNot(contains('UploadRunnerTest')));
        expect(report, isNot(contains('UploadItemAddressTest')));
      }
    },
    timeout: const Timeout(Duration(minutes: 32)),
  );
}
