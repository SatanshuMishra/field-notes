import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/data/device/stay_awake.dart';

const String _mainActivity =
    'android/app/src/main/kotlin/dev/satanshumishra/field_notes/MainActivity.kt';
const String _androidManifest = 'android/app/src/main/AndroidManifest.xml';
const String _mainWindow = 'macos/Runner/MainFlutterWindow.swift';
const String _systemChannels = 'windows/runner/system_channels.cpp';
const String _systemChannelsHeader = 'windows/runner/system_channels.h';

String _source(String path) {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  return file.readAsStringSync();
}

String _block(String source, String opening) {
  final int start = source.indexOf(opening);
  expect(start, isNot(-1), reason: '$opening must exist');
  final int open = source.indexOf('{', start);
  expect(open, isNot(-1), reason: '$opening must open a block');
  int depth = 0;
  for (int index = open; index < source.length; index += 1) {
    if (source[index] == '{') {
      depth += 1;
    } else if (source[index] == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(start, index + 1);
      }
    }
  }
  fail('$opening never closes');
}

String _between(String source, String from, [String? to]) {
  final int start = source.indexOf(from);
  expect(start, isNot(-1), reason: '$from must exist');
  if (to == null) {
    return source.substring(start);
  }
  final int end = source.indexOf(to, start + from.length);
  expect(end, isNot(-1), reason: '$to must follow $from');
  return source.substring(start, end);
}

List<String> _captured(RegExp pattern, String source) => pattern
    .allMatches(source)
    .map((RegExpMatch match) => match.group(1)!)
    .toList();

Future<List<String>> _methodsSent() async {
  const MethodChannel channel = MethodChannel(stayAwakeChannelName);
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final List<MethodCall> calls = <MethodCall>[];
  messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
    calls.add(call);
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  const StayAwake stayAwake = PlatformStayAwake();
  await stayAwake.hold();
  await stayAwake.release();
  expect(calls.map((MethodCall call) => call.arguments).toList(), <Object?>[
    null,
    null,
  ]);
  return calls.map((MethodCall call) => call.method).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every runner keeps the device awake only while asked', () async {
    final List<String> methods = await _methodsSent();
    expect(methods, <String>['hold', 'release']);
    final String hold = methods.first;
    final String release = methods.last;

    final String kotlin = _source(_mainActivity);
    expect(
      kotlin,
      contains('const val STAY_AWAKE_CHANNEL = "$stayAwakeChannelName"'),
    );
    expect(kotlin, contains('import android.view.WindowManager\n'));
    final String configure = _block(
      kotlin,
      'override fun configureFlutterEngine(',
    );
    final String androidHandler = _block(
      configure,
      'MethodChannel(flutterEngine.dartExecutor.binaryMessenger, '
      'STAY_AWAKE_CHANNEL)',
    );
    expect(
      _captured(RegExp(r'^\s*"([^"]+)" ->', multiLine: true), androidHandler),
      methods,
    );
    expect(
      _block(androidHandler, '"$hold" -> {'),
      allOf(
        contains(
          'window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)',
        ),
        contains('result.success(null)'),
        isNot(contains('clearFlags')),
      ),
    );
    expect(
      _block(androidHandler, '"$release" -> {'),
      allOf(
        contains(
          'window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)',
        ),
        contains('result.success(null)'),
        isNot(contains('addFlags')),
      ),
    );
    expect(androidHandler, contains('else -> result.notImplemented()'));
    expect(androidHandler, isNot(contains('call.argument')));
    expect('FLAG_KEEP_SCREEN_ON'.allMatches(kotlin), hasLength(2));
    expect(
      _source(_androidManifest),
      isNot(contains('android.permission.WAKE_LOCK')),
    );

    final String swift = _source(_mainWindow);
    expect(
      swift,
      contains('private let stayAwakeChannelName = "$stayAwakeChannelName"'),
    );
    expect(swift, contains('private var stayAwakeActivity: NSObjectProtocol?'));
    expect(
      _block(swift, 'override func awakeFromNib()'),
      contains(
        'self.registerStayAwakeChannel('
        'flutterViewController.engine.binaryMessenger)',
      ),
    );
    final String macHandler = _block(
      swift,
      'private func registerStayAwakeChannel(_ messenger: FlutterBinaryMessenger)',
    );
    expect(macHandler, contains('name: stayAwakeChannelName,'));
    expect(_captured(RegExp(r'case "([^"]+)":'), macHandler), methods);
    expect(
      _between(macHandler, 'case "$hold":', 'case "$release":'),
      allOf(contains('self?.holdStayAwakeActivity()'), contains('result(nil)')),
    );
    expect(
      _between(macHandler, 'case "$release":', 'default:'),
      allOf(
        contains('self?.releaseStayAwakeActivity()'),
        contains('result(nil)'),
      ),
    );
    expect(
      _between(macHandler, 'default:'),
      matches(RegExp(r'^default:\s*result\(FlutterMethodNotImplemented\)')),
    );
    expect(macHandler, isNot(contains('call.arguments')));
    final String macHold = _block(
      swift,
      'private func holdStayAwakeActivity()',
    );
    expect(
      macHold,
      matches(
        RegExp(r'guard self\.stayAwakeActivity == nil else \{\s*return\s*\}'),
      ),
    );
    expect(
      macHold,
      matches(
        RegExp(
          r'self\.stayAwakeActivity = ProcessInfo\.processInfo\.beginActivity\(\s*'
          r'options: \[\.userInitiated, \.idleDisplaySleepDisabled, '
          r'\.idleSystemSleepDisabled\],\s*'
          r'reason: "Recording in Field Notes"\s*\)',
        ),
      ),
    );
    expect(
      macHold.indexOf('guard'),
      lessThan(macHold.indexOf('beginActivity(')),
    );
    final String macRelease = _block(
      swift,
      'private func releaseStayAwakeActivity()',
    );
    expect(
      macRelease,
      matches(
        RegExp(
          r'guard let activity = self\.stayAwakeActivity else \{\s*return\s*\}',
        ),
      ),
    );
    expect(
      macRelease,
      contains('ProcessInfo.processInfo.endActivity(activity)'),
    );
    expect(
      macRelease.indexOf('endActivity('),
      lessThan(macRelease.indexOf('self.stayAwakeActivity = nil')),
    );
    expect('beginActivity('.allMatches(swift), hasLength(1));
    expect('endActivity('.allMatches(swift), hasLength(1));

    final String cpp = _source(_systemChannels);
    expect(
      cpp,
      contains(
        'constexpr char kStayAwakeChannelName[] = "$stayAwakeChannelName";',
      ),
    );
    expect(cpp, contains('constexpr char kHoldMethod[] = "$hold";'));
    expect(cpp, contains('constexpr char kReleaseMethod[] = "$release";'));
    final String windowsHandler = _block(
      cpp,
      'void HandleStayAwake(const Call& call, Result result)',
    );
    expect(
      _captured(RegExp(r'call\.method_name\(\) == (\w+)'), windowsHandler),
      <String>['kHoldMethod', 'kReleaseMethod'],
    );
    expect(
      _between(windowsHandler, '== kHoldMethod', '== kReleaseMethod'),
      allOf(
        matches(
          RegExp(
            r'::SetThreadExecutionState\(ES_CONTINUOUS \| ES_SYSTEM_REQUIRED \|'
            r'\s*ES_DISPLAY_REQUIRED\);',
          ),
        ),
        contains('result->Success();'),
      ),
    );
    expect(
      _between(windowsHandler, '== kReleaseMethod', '} else {'),
      allOf(
        contains('::SetThreadExecutionState(ES_CONTINUOUS);'),
        contains('result->Success();'),
      ),
    );
    expect(
      _between(windowsHandler, '} else {'),
      contains('result->NotImplemented();'),
    );
    expect(windowsHandler, isNot(contains('arguments')));
    expect('SetThreadExecutionState('.allMatches(cpp), hasLength(2));
    final String constructor = _block(
      cpp,
      'SystemChannels::SystemChannels(flutter::BinaryMessenger* messenger)',
    );
    expect(
      constructor,
      contains('stay_awake_(ChannelNamed(messenger, kStayAwakeChannelName))'),
    );
    expect(
      constructor,
      contains('stay_awake_->SetMethodCallHandler(HandleStayAwake);'),
    );
    expect(
      _source(_systemChannelsHeader),
      matches(
        RegExp(
          r'std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>'
          r'\s*stay_awake_;',
        ),
      ),
    );
  });
}
