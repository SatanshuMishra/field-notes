import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/note_engine/platform/android_clipboard_image.dart';
import 'package:field_notes/features/note_engine/platform/image_pasteboard.dart';

const MethodChannel _channel = MethodChannel(androidClipboardImageChannelName);

const String _kotlinFolder =
    'android/app/src/main/kotlin/dev/satanshumishra/field_notes';

List<MethodCall> _mockChannel(Object? Function(MethodCall) answer) {
  final List<MethodCall> calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (MethodCall call) async {
        calls.add(call);
        return answer(call);
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );
  return calls;
}

List<String> _methods(List<MethodCall> calls) =>
    calls.map((MethodCall call) => call.method).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidClipboardImage', () {
    test('the android bridge returns clipboard image bytes', () async {
      Object? image = <String, Object?>{
        'bytes': Uint8List.fromList(<int>[255, 216, 255]),
        'mime': 'image/jpeg',
      };
      final List<MethodCall> calls = _mockChannel(
        (MethodCall call) => switch (call.method) {
          'hasImage' => true,
          'image' => image,
          _ => null,
        },
      );
      const AndroidClipboardImage clipboard = AndroidClipboardImage();

      expect(await clipboard.hasImage(), isTrue);
      expect(_methods(calls), <String>['hasImage']);

      expect(
        await clipboard.readImage(),
        PastedImage(
          bytes: Uint8List.fromList(<int>[255, 216, 255]),
          mime: 'image/jpeg',
        ),
      );
      expect(_methods(calls), <String>['hasImage', 'image']);

      image = null;
      expect(await clipboard.readImage(), isNull);
      expect(_methods(calls), <String>['hasImage', 'image', 'image']);
    });

    test('a false or null hasImage answer gives false', () async {
      Object? answer = false;
      final List<MethodCall> calls = _mockChannel((MethodCall call) => answer);
      const AndroidClipboardImage clipboard = AndroidClipboardImage();

      expect(await clipboard.hasImage(), isFalse);
      answer = null;
      expect(await clipboard.hasImage(), isFalse);
      expect(_methods(calls), <String>['hasImage', 'hasImage']);
    });

    test('an answer missing bytes or mime gives null', () async {
      Object? answer = <String, Object?>{'mime': 'image/png'};
      final List<MethodCall> calls = _mockChannel((MethodCall call) => answer);
      const AndroidClipboardImage clipboard = AndroidClipboardImage();

      expect(await clipboard.readImage(), isNull);
      answer = <String, Object?>{
        'bytes': Uint8List.fromList(<int>[1, 2]),
      };
      expect(await clipboard.readImage(), isNull);
      expect(_methods(calls), <String>['image', 'image']);
    });

    test('without a handler hasImage is false and readImage is null', () async {
      const AndroidClipboardImage clipboard = AndroidClipboardImage();

      expect(await clipboard.hasImage(), isFalse);
      expect(await clipboard.readImage(), isNull);
    });

    test('a hasImage platform error gives false', () async {
      final List<MethodCall> calls = _mockChannel(
        (MethodCall call) =>
            throw PlatformException(code: 'unreadable', message: 'denied'),
      );
      const AndroidClipboardImage clipboard = AndroidClipboardImage();

      expect(await clipboard.hasImage(), isFalse);
      expect(_methods(calls), <String>['hasImage']);
    });

    test('an image platform error propagates out of readImage', () async {
      final List<MethodCall> calls = _mockChannel(
        (MethodCall call) =>
            throw PlatformException(code: 'unreadable', message: 'denied'),
      );
      const AndroidClipboardImage clipboard = AndroidClipboardImage();

      await expectLater(
        clipboard.readImage(),
        throwsA(
          isA<PlatformException>()
              .having(
                (PlatformException error) => error.code,
                'code',
                'unreadable',
              )
              .having(
                (PlatformException error) => error.message,
                'message',
                'denied',
              ),
        ),
      );
      expect(_methods(calls), <String>['image']);
    });

    test('constructing the wrapper makes no call', () async {
      final List<MethodCall> calls = _mockChannel((MethodCall call) => true);

      const AndroidClipboardImage clipboard = AndroidClipboardImage();
      final AndroidClipboardImage custom = AndroidClipboardImage(
        channel: const MethodChannel(androidClipboardImageChannelName),
      );

      expect(clipboard, isNotNull);
      expect(custom, isNotNull);
      expect(calls, isEmpty);
    });
  });

  group('Android clipboard image bridge source', () {
    final String bridge = File(
      '$_kotlinFolder/ClipboardImageBridge.kt',
    ).readAsStringSync();
    final String activity = File(
      '$_kotlinFolder/MainActivity.kt',
    ).readAsStringSync();

    test('the bridge declares its package, channel and methods', () {
      expect(bridge, contains('package dev.satanshumishra.field_notes'));
      expect(bridge, contains('"field_notes/clipboard_image"'));
      expect(bridge, contains('"hasImage"'));
      expect(bridge, contains('"image"'));
      expect(bridge, contains('startsWith("image/")'));
      expect(bridge, contains('openInputStream'));
      expect(bridge, contains('Looper.getMainLooper()'));
    });

    test('the background image read answers every failure', () {
      final int read = bridge.indexOf('openInputStream');
      expect(read, isNot(-1));
      final int nextFunction = bridge.indexOf('private fun ', read);
      final String readTail = bridge.substring(
        read,
        nextFunction == -1 ? bridge.length : nextFunction,
      );
      final List<String> caught = RegExp(r'catch \(\w+: (\w+)\)')
          .allMatches(readTail)
          .map((RegExpMatch match) => match.group(1)!)
          .toList();
      final Iterable<Match> answers = 'result.error("unreadable", '.allMatches(
        readTail,
      );

      expect(caught, containsAll(<String>['Exception', 'OutOfMemoryError']));
      expect(answers.length, greaterThan(caught.length));
    });

    test('every bridge shares one reader thread', () {
      final int companion = bridge.indexOf('companion object');
      final Iterable<RegExpMatch> executors = RegExp(
        r'Executors\.new\w+\(',
      ).allMatches(bridge);

      expect(companion, isNot(-1));
      expect(executors, hasLength(1));
      expect(executors.single.start, greaterThan(companion));
    });

    test('the dart channel name equals the kotlin channel', () {
      final RegExpMatch? match = RegExp(
        r'const val CHANNEL = "([^"]+)"',
      ).firstMatch(bridge);
      expect(match, isNotNull);
      expect(match!.group(1), androidClipboardImageChannelName);
    });

    test('the activity registers the bridge after the plugins', () {
      expect(
        activity,
        contains(
          'override fun configureFlutterEngine(flutterEngine: FlutterEngine)',
        ),
      );
      final int superCall = activity.indexOf(
        'super.configureFlutterEngine(flutterEngine)',
      );
      final int bridgeCall = activity.indexOf('ClipboardImageBridge(');
      expect(superCall, isNot(-1));
      expect(bridgeCall, greaterThan(superCall));
    });
  });
}
