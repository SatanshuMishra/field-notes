import 'dart:io';

import 'package:camera_macos/camera_macos_arguments.dart';
import 'package:camera_macos/camera_macos_controller.dart';
import 'package:camera_macos/camera_macos_method_channel.dart';
import 'package:camera_macos/camera_macos_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _pluginSource =
    'third_party/camera_macos/macos/camera_macos/Sources/camera_macos/CameraMacosPlugin.swift';
const String _localModifications =
    'third_party/camera_macos/LOCAL_MODIFICATIONS.md';
const MethodChannel _channel = MethodChannel('camera_macos');

String _functionBody(String source, String signature) {
  final int start = source.indexOf(signature);
  expect(start, isNot(-1), reason: '$signature is missing');
  final int open = source.indexOf('{', start + signature.length);
  int depth = 0;
  for (int index = open; index < source.length; index++) {
    final String character = source[index];
    if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(open + 1, index);
      }
    }
  }
  fail('$signature has no closing brace');
}

Iterable<String> _numberedItems(String markdown) => markdown
    .split(RegExp(r'\n(?=\d+\. )'))
    .where((String part) => RegExp(r'^\d+\. ').hasMatch(part));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the camera_macos controller sends pauseRecording and resumeRecording',
    () async {
      CameraMacOSPlatform.instance = MethodChannelCameraMacOS();
      final List<MethodCall> calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
            calls.add(call);
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_channel, null);
      });
      final CameraMacOSController controller = CameraMacOSController(
        CameraMacOSArguments(size: Size.zero),
      );

      final bool? paused = await controller.pauseRecording();
      final bool? resumed = await controller.resumeRecording();

      expect(calls.map((MethodCall call) => call.method).toList(), <String>[
        'pauseRecording',
        'resumeRecording',
      ]);
      expect(paused, isTrue);
      expect(resumed, isTrue);
    },
  );

  test(
    'the camera_macos Swift plugin pauses and resumes its movie file output',
    () {
      final String plugin = File(_pluginSource).readAsStringSync();
      final String handle = _functionBody(
        plugin,
        'public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)',
      );

      for (final String method in <String>[
        'pauseRecording',
        'resumeRecording',
      ]) {
        expect(
          handle,
          matches(RegExp('case "$method":\\s*$method\\(result\\)')),
          reason: 'the method switch must answer $method',
        );
        final String body = _functionBody(
          plugin,
          'func $method(_ result: @escaping FlutterResult)',
        );
        final RegExpMatch? guard = RegExp(
          r'guard ([\s\S]*?) else \{([\s\S]*?)\}',
        ).firstMatch(body);
        expect(guard, isNotNull, reason: '$method must guard on recording');
        final String condition = guard!.group(1)!;
        final String otherwise = guard.group(2)!;
        final RegExpMatch? output = RegExp(
          r'let (\w+)(?:: AVCaptureMovieFileOutput)? = self\.captureSession\??\.outputs\.first\(where: \{ \$0 is AVCaptureMovieFileOutput \}\) as\? AVCaptureMovieFileOutput',
        ).firstMatch(condition);
        expect(
          output,
          isNotNull,
          reason: '$method must find the session movie file output',
        );
        final String movieOutput = output!.group(1)!;
        expect(condition, contains('self.isRecording'));
        expect(condition, contains('$movieOutput.isRecording'));
        expect(
          otherwise,
          contains(
            'result(FlutterError(code: "NOT_RECORDING", message: "No movie recording is in progress", details: nil))',
          ),
        );
        expect(otherwise, contains('return'));
        expect(body, isNot(contains('toFlutterResult')));
        expect(body, isNot(contains('toMap')));
        final String recording = body.substring(guard.end);
        final int call = recording.indexOf('$movieOutput.$method()');
        expect(call, isNot(-1), reason: '$method must call $method()');
        expect(recording.indexOf('result(true)'), greaterThan(call));
      }

      final String modifications = File(_localModifications).readAsStringSync();
      expect(
        _numberedItems(modifications).where(
          (String item) =>
              item.contains('pauseRecording') &&
              item.contains('resumeRecording'),
        ),
        isNotEmpty,
        reason:
            'LOCAL_MODIFICATIONS.md must name pauseRecording and '
            'resumeRecording in a numbered delta',
      );
    },
  );
}
