import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:field_notes/data/sync/background/sync_availability.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel('field_notes/background_uploads');

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

List<String> _answering(Future<Object?> Function() answer) {
  final List<String> calls = <String>[];
  _messenger.setMockMethodCallHandler(_channel, (MethodCall call) {
    calls.add(call.method);
    return answer();
  });
  return calls;
}

List<String> _replyingWithNoHandler() {
  final List<String> calls = <String>[];
  _messenger.setMockMessageHandler(_channel.name, (ByteData? message) async {
    calls.add(_channel.codec.decodeMethodCall(message).method);
    return null;
  });
  return calls;
}

Future<bool> _askAndroid() =>
    syncAvailableOnThisDevice(platform: TargetPlatform.android);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    _messenger.setMockMethodCallHandler(_channel, null);
    _messenger.setMockMessageHandler(_channel.name, null);
  });

  test(
    'only an explicit no from Android means this copy has no sync',
    () async {
      final List<String> no = _answering(() async => false);
      expect(await _askAndroid(), isFalse);
      expect(no, <String>['available']);

      final List<String> yes = _answering(() async => true);
      expect(await _askAndroid(), isTrue);
      expect(yes, <String>['available']);

      final List<String> empty = _answering(() async => null);
      expect(await _askAndroid(), isTrue);
      expect(empty, <String>['available']);

      final List<String> refused = _answering(
        () async => throw PlatformException(code: 'unavailable'),
      );
      expect(await _askAndroid(), isTrue);
      expect(refused, <String>['available']);

      final List<String> missing = _replyingWithNoHandler();
      expect(await _askAndroid(), isTrue);
      expect(missing, <String>['available']);

      _messenger.setMockMessageHandler(_channel.name, null);
      expect(await _askAndroid(), isTrue);

      final List<String> held = _answering(() => Completer<Object?>().future);
      fakeAsync((FakeAsync async) {
        bool? answer;
        unawaited(_askAndroid().then((bool value) => answer = value));
        async.elapse(const Duration(milliseconds: 999));
        expect(answer, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(answer, isTrue);
      });
      expect(held, <String>['available']);
    },
  );

  test('macOS and Windows have sync without asking', () async {
    final List<String> calls = _answering(() async => false);
    expect(
      await syncAvailableOnThisDevice(platform: TargetPlatform.macOS),
      isTrue,
    );
    expect(
      await syncAvailableOnThisDevice(platform: TargetPlatform.windows),
      isTrue,
    );
    expect(calls, isEmpty);
  });
}
