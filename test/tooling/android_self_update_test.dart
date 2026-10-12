import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _app = 'android/app';
const String _mainManifest = '$_app/src/main/AndroidManifest.xml';
const String _selfUpdateManifest = '$_app/src/selfUpdate/AndroidManifest.xml';
const String _kotlinPackage = 'kotlin/dev/satanshumishra/field_notes';
const String _mainKotlin = '$_app/src/main/$_kotlinPackage';
const String _selfUpdateKotlin = '$_app/src/selfUpdate/$_kotlinPackage';
const String _storeKotlin = '$_app/src/store/$_kotlinPackage';
const String _gradle = '$_app/build.gradle.kts';
const String _permission = 'android.permission.REQUEST_INSTALL_PACKAGES';
const String _channelName = '"field_notes/app_update"';
const List<String> _installerMarks = <String>[
  'PackageInstaller',
  'REQUEST_INSTALL_PACKAGES',
  'UpdateReplacedReceiver',
];
const String _mainUploads = '$_mainKotlin/uploads';
const String _selfUpdateUploads = '$_selfUpdateKotlin/uploads';
const String _storeUploads = '$_storeKotlin/uploads';
const String _uploadTests = '$_app/src/testSelfUpdate/$_kotlinPackage/uploads';
const String _uploadsPackage = 'package dev.satanshumishra.field_notes.uploads';
const String _uploadsChannelName = 'field_notes/background_uploads';
const String _availableMethod = 'available';
const String _dartUploads = 'lib/data/sync/background/background_uploads.dart';
const String _dartAvailability =
    'lib/data/sync/background/sync_availability.dart';
const List<String> _uploadPermissions = <String>[
  'android.permission.FOREGROUND_SERVICE',
  'android.permission.FOREGROUND_SERVICE_DATA_SYNC',
  'android.permission.RUN_USER_INITIATED_JOBS',
];
const List<String> _uploadFiles = <String>[
  'LegacyUploads.kt',
  'UploadChannel.kt',
  'UploadItem.kt',
  'UploadJobService.kt',
  'UploadNotifications.kt',
  'UploadRunner.kt',
  'UploadScheduler.kt',
  'UploadStore.kt',
  'UploadTransport.kt',
  'UploadWorker.kt',
];
const List<String> _uploadUnitTests = <String>[
  'UploadItemAddressTest.kt',
  'UploadRunnerTest.kt',
];

String _read(String path) {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  return file.readAsStringSync();
}

List<File> _sources(String path) {
  final Directory directory = Directory(path);
  expect(directory.existsSync(), isTrue, reason: '$path is missing');
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .toList(growable: false);
}

String _block(String text, int open) {
  expect(text[open], '{', reason: 'a block must start at an opening brace');
  int depth = 0;
  for (int index = open; index < text.length; index++) {
    if (text[index] == '{') {
      depth++;
    } else if (text[index] == '}') {
      depth--;
      if (depth == 0) {
        return text.substring(open + 1, index);
      }
    }
  }
  fail('the block at $open never closes');
}

String _constructor(String source) {
  final RegExpMatch? match = RegExp(r'class AppUpdateChannel\(([^)]*)\)')
      .firstMatch(source);
  expect(match, isNotNull, reason: 'AppUpdateChannel must be a class');
  final String parameter = match!.group(1)!;
  return parameter.substring(parameter.lastIndexOf(':') + 1).trim();
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

String _constant(String source, String name) {
  final RegExpMatch? match = RegExp('const val $name = "([^"]*)"')
      .firstMatch(source);
  expect(match, isNotNull, reason: 'the constant $name must be declared');
  return match!.group(1)!;
}

({String selfUpdate, String otherwise}) _variantBranches(
  String gradle,
  String flag,
) {
  final int variants = gradle.indexOf('onVariants { variant ->');
  expect(variants, isNot(-1), reason: 'the build must configure variants');
  final String onVariants = _block(gradle, gradle.indexOf('{', variants));
  final int branch = onVariants.indexOf('if ($flag) {');
  expect(branch, isNot(-1), reason: 'the source sets depend on $flag');
  final int thenOpen = onVariants.indexOf('{', branch);
  final String selfUpdate = _block(onVariants, thenOpen);
  final int elseAt = thenOpen + selfUpdate.length + 2;
  expect(onVariants.substring(elseAt).trimLeft(), startsWith('else {'));
  final String otherwise = _block(onVariants, onVariants.indexOf('{', elseAt));
  return (selfUpdate: selfUpdate, otherwise: otherwise);
}

void main() {
  test('only the GitHub APK can install its own updates', () {
    final String mainManifest = _read(_mainManifest);
    expect(mainManifest, isNot(contains(_permission)));
    expect(mainManifest, isNot(contains('UpdateReplacedReceiver')));
    for (final File source in _sources(
      '$_app/src/main',
    ).where((File file) => RegExp(r'\.(kt|java|xml)$').hasMatch(file.path))) {
      final String text = source.readAsStringSync();
      for (final String mark in _installerMarks) {
        expect(text, isNot(contains(mark)), reason: '${source.path}: $mark');
      }
    }
    expect(File('$_mainKotlin/AppUpdateChannel.kt').existsSync(), isFalse);
    expect(
      _read('$_mainKotlin/MainActivity.kt'),
      contains(
        'AppUpdateChannel(this).register(flutterEngine.dartExecutor.binaryMessenger)',
      ),
    );

    final String selfUpdateManifest = _read(_selfUpdateManifest);
    expect(
      RegExp(
        r'<uses-permission\s+android:name="android\.permission\.REQUEST_INSTALL_PACKAGES"\s*/>',
      ).hasMatch(selfUpdateManifest),
      isTrue,
    );
    final RegExpMatch? receiver = RegExp(
      r'<receiver\b([^>]*)>(.*?)</receiver>',
      dotAll: true,
    ).firstMatch(selfUpdateManifest);
    expect(receiver, isNotNull, reason: 'the receiver must be declared');
    expect(
      receiver!.group(1),
      contains('android:name=".UpdateReplacedReceiver"'),
    );
    expect(receiver.group(1), contains('android:exported="false"'));
    expect(
      receiver.group(2),
      contains(
        '<action android:name="android.intent.action.MY_PACKAGE_REPLACED" />',
      ),
    );

    final String installer = _read('$_selfUpdateKotlin/AppUpdateChannel.kt');
    for (final String part in <String>[
      _channelName,
      '"canSelfUpdate"',
      '"canRequestInstalls"',
      '"openInstallPermission"',
      '"install"',
      'Manifest.permission.REQUEST_INSTALL_PACKAGES',
      'canRequestPackageInstalls()',
      'Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES',
      'PackageInstaller.SessionParams.MODE_FULL_INSTALL',
      'setAppPackageName(context.packageName)',
      'PackageInstaller.STATUS_PENDING_USER_ACTION',
      'ContextCompat.RECEIVER_NOT_EXPORTED',
    ]) {
      expect(installer, contains(part));
    }
    final String replaced = _read(
      '$_selfUpdateKotlin/UpdateReplacedReceiver.kt',
    );
    for (final String part in <String>[
      'class UpdateReplacedReceiver : BroadcastReceiver()',
      'Intent.ACTION_MY_PACKAGE_REPLACED',
      'areNotificationsEnabled()',
      '"app_updates"',
      '"App updates"',
      'NotificationManager.IMPORTANCE_DEFAULT',
      '"Field Notes is updated"',
      r'"Tap to open version ${versionName(context)}."',
      'MainActivity::class.java',
    ]) {
      expect(replaced, contains(part));
    }

    final List<File> store = _sources('$_app/src/store');
    expect(store.map((File file) => file.path).toList()..sort(), <String>[
      '$_storeKotlin/AppUpdateChannel.kt',
      '$_storeKotlin/uploads/UploadChannel.kt',
    ]);
    final String stub = _read('$_storeKotlin/AppUpdateChannel.kt');
    for (final String mark in _installerMarks) {
      expect(stub, isNot(contains(mark)));
    }
    expect(stub, contains(_channelName));
    expect(
      stub,
      contains(
        'CAN_SELF_UPDATE, CAN_REQUEST_INSTALLS -> result.success(false)',
      ),
    );
    expect(stub, contains('const val CAN_SELF_UPDATE = "canSelfUpdate"'));
    expect(
      stub,
      contains('const val CAN_REQUEST_INSTALLS = "canRequestInstalls"'),
    );
    expect(stub, contains('else -> result.error("unavailable"'));
    expect(_constructor(stub), _constructor(installer));
    expect(_constructor(stub), 'Activity');
    expect(stub, contains('fun register(messenger: BinaryMessenger)'));
    expect(installer, contains('fun register(messenger: BinaryMessenger)'));

    final String gradle = _read(_gradle);
    final RegExpMatch? property = RegExp(
      r'val (\w+) = providers\.gradleProperty\("fieldNotesSelfUpdate"\)\.orNull == "true"',
    ).firstMatch(gradle);
    expect(property, isNotNull, reason: 'the build must read the property');
    final String flag = property!.group(1)!;
    final int variants = gradle.indexOf('onVariants { variant ->');
    expect(variants, isNot(-1), reason: 'the build must configure variants');
    final String onVariants = _block(gradle, gradle.indexOf('{', variants));
    expect(
      onVariants,
      contains('variant.sources.kotlin ?: variant.sources.java'),
    );
    final int branch = onVariants.indexOf('if ($flag) {');
    expect(branch, isNot(-1), reason: 'the source sets depend on $flag');
    final int thenOpen = onVariants.indexOf('{', branch);
    final String selfUpdate = _block(onVariants, thenOpen);
    final int elseAt = thenOpen + selfUpdate.length + 2;
    expect(onVariants.substring(elseAt).trimLeft(), startsWith('else {'));
    final String otherwise = _block(
      onVariants,
      onVariants.indexOf('{', elseAt),
    );
    expect(
      selfUpdate,
      contains(
        'variant.sources.manifests.addStaticManifestFile("src/selfUpdate/AndroidManifest.xml")',
      ),
    );
    expect(
      selfUpdate,
      contains('addStaticSourceDirectory("src/selfUpdate/kotlin")'),
    );
    expect(selfUpdate, isNot(contains('src/store')));
    expect(otherwise, contains('addStaticSourceDirectory("src/store/kotlin")'));
    expect(otherwise, isNot(contains('src/selfUpdate')));
    expect(otherwise, isNot(contains('addStaticManifestFile')));
    expect('src/selfUpdate'.allMatches(gradle).length, 2);
    expect('src/store'.allMatches(gradle).length, 1);
    expect(gradle, isNot(contains('sourceSets')));
  });

  test('only the GitHub APK carries background uploads', () {
    expect(Directory(_mainUploads).existsSync(), isFalse);
    for (final File source in _sources(
      '$_app/src/main',
    ).where((File file) => RegExp(r'\.(kt|java)$').hasMatch(file.path))) {
      expect(
        source.readAsStringSync(),
        isNot(contains(_uploadsPackage)),
        reason: '${source.path} must not carry upload code',
      );
    }

    final String mainManifest = _read(_mainManifest);
    final Set<String> mainPermissions = _permissions(mainManifest);
    for (final String permission in _uploadPermissions) {
      expect(mainPermissions, isNot(contains(permission)));
    }
    expect(mainManifest, isNot(contains('UploadJobService')));
    expect(mainManifest, isNot(contains('SystemForegroundService')));

    final String selfUpdateManifest = _read(_selfUpdateManifest);
    expect(_permissions(selfUpdateManifest), containsAll(_uploadPermissions));
    final String jobService = _element(
      selfUpdateManifest,
      'service',
      '.uploads.UploadJobService',
    );
    expect(
      jobService,
      contains('android:permission="android.permission.BIND_JOB_SERVICE"'),
    );
    expect(jobService, contains('android:exported="true"'));
    expect(
      _element(
        selfUpdateManifest,
        'service',
        'androidx.work.impl.foreground.SystemForegroundService',
      ),
      contains('android:foregroundServiceType="dataSync"'),
    );

    for (final String name in _uploadFiles) {
      expect(
        _read('$_selfUpdateUploads/$name'),
        startsWith(_uploadsPackage),
        reason: '$name must stay in the uploads package',
      );
    }

    final String standIn = _read('$_storeUploads/UploadChannel.kt');
    final String channel = _read('$_selfUpdateUploads/UploadChannel.kt');
    for (final String source in <String>[standIn, channel]) {
      expect(source, startsWith(_uploadsPackage));
      expect(
        source,
        contains('class UploadChannel(private val context: Context)'),
      );
      expect(source, contains('fun register(messenger: BinaryMessenger)'));
      expect(source, contains('MethodChannel(messenger, CHANNEL)'));
      expect(_constant(source, 'CHANNEL'), _uploadsChannelName);
      expect(_constant(source, 'AVAILABLE'), _availableMethod);
    }
    expect(standIn, contains('AVAILABLE -> result.success(false)'));
    expect(standIn, contains('else -> result.error("unavailable"'));
    for (final String mark in <String>[
      'androidx.work',
      'WorkManager',
      'JobScheduler',
      'ForegroundService',
    ]) {
      expect(standIn, isNot(contains(mark)));
    }
    final RegExpMatch? available = RegExp(
      r'if \(call\.method == AVAILABLE\) \{\s*result\.success\(true\)',
    ).firstMatch(channel);
    expect(available, isNotNull, reason: 'the real channel answers true');
    expect(available!.start, lessThan(channel.indexOf('worker.execute')));

    final String gradle = _read(_gradle);
    final RegExpMatch? property = RegExp(
      r'val (\w+) = providers\.gradleProperty\("fieldNotesSelfUpdate"\)\.orNull == "true"',
    ).firstMatch(gradle);
    expect(property, isNotNull, reason: 'the build must read the property');
    final String flag = property!.group(1)!;
    expect('work-runtime'.allMatches(gradle).length, 1);
    final int dependencies = gradle.indexOf('\ndependencies {');
    expect(dependencies, isNot(-1), reason: 'the build must have dependencies');
    final String dependencyBlock = _block(
      gradle,
      gradle.indexOf('{', dependencies),
    );
    final int guard = dependencyBlock.indexOf('if ($flag) {');
    expect(guard, isNot(-1), reason: 'WorkManager must depend on $flag');
    expect(
      _block(dependencyBlock, dependencyBlock.indexOf('{', guard)),
      contains('implementation("androidx.work:work-runtime:2.11.0")'),
    );
    final ({String selfUpdate, String otherwise}) branches = _variantBranches(
      gradle,
      flag,
    );
    expect(
      branches.selfUpdate,
      contains(
        '(variant as? com.android.build.api.variant.HasUnitTest)?.unitTest',
      ),
    );
    expect(
      branches.selfUpdate,
      contains('addStaticSourceDirectory("src/testSelfUpdate/kotlin")'),
    );
    expect(branches.otherwise, isNot(contains('testSelfUpdate')));
    expect('src/testSelfUpdate/kotlin'.allMatches(gradle).length, 1);
    expect(gradle, isNot(contains('sourceSets')));

    final List<String> unitTests =
        Directory('$_app/src')
            .listSync(recursive: true)
            .whereType<File>()
            .map((File file) => file.path)
            .where(
              (String path) => _uploadUnitTests.any(
                (String name) => path.endsWith('/$name'),
              ),
            )
            .toList()
          ..sort();
    expect(unitTests, <String>[
      for (final String name in _uploadUnitTests) '$_uploadTests/$name',
    ]);

    final String activity = _read('$_mainKotlin/MainActivity.kt');
    expect(
      activity,
      contains('import dev.satanshumishra.field_notes.uploads.UploadChannel'),
    );
    expect(
      activity,
      contains(
        'UploadChannel(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)',
      ),
    );

    expect(_read(_dartUploads), contains("'$_uploadsChannelName'"));
    expect(_read(_dartAvailability), contains("'$_availableMethod'"));
  });
}
