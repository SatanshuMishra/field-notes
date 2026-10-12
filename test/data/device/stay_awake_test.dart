import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/data/device/stay_awake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stay-awake requests go to the platform channel', () async {
    const MethodChannel channel = MethodChannel(stayAwakeChannelName);
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final List<MethodCall> calls = <MethodCall>[];
    final List<String> logged = <String>[];
    final DebugPrintCallback original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      logged.add(message ?? '');
    };
    addTearDown(() => debugPrint = original);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    const StayAwake stayAwake = PlatformStayAwake();

    expect(stayAwakeChannelName, 'field_notes/stay_awake');

    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return null;
    });
    await stayAwake.hold();
    await stayAwake.release();
    expect(calls.map((MethodCall call) => call.method).toList(), <String>[
      'hold',
      'release',
    ]);
    expect(calls.map((MethodCall call) => call.arguments).toList(), <Object?>[
      null,
      null,
    ]);
    expect(logged, isEmpty);

    messenger.setMockMethodCallHandler(channel, null);
    await expectLater(stayAwake.hold(), completes);
    await expectLater(stayAwake.release(), completes);
    expect(logged, hasLength(2));
    expect(logged, everyElement(contains('MissingPluginException')));
    expect(logged.first, contains('"hold"'));
    expect(logged.last, contains('"release"'));

    calls.clear();
    logged.clear();
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      throw PlatformException(code: 'unavailable', message: 'No window');
    });
    await expectLater(stayAwake.hold(), completes);
    await expectLater(stayAwake.release(), completes);
    expect(calls.map((MethodCall call) => call.method).toList(), <String>[
      'hold',
      'release',
    ]);
    expect(logged, hasLength(2));
    expect(logged, everyElement(contains('PlatformException(unavailable')));
    expect(logged.first, contains('"hold"'));
    expect(logged.last, contains('"release"'));
  });
}
