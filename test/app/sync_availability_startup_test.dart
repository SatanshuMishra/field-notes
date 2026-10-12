import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_shell_harness.dart';

const MethodChannel _channel = MethodChannel('field_notes/background_uploads');

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

List<String> _answering(bool answer) {
  final List<String> calls = <String>[];
  _messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
    calls.add(call.method);
    return answer;
  });
  return calls;
}

Future<bool> _syncAvailableInShell(
  WidgetTester tester,
  FieldNotesApp app,
) async {
  await tester.pumpWidget(
    ProviderScope(overrides: shellOverrides(), child: app),
  );
  await tester.pump();
  final bool available = ProviderScope.containerOf(
    tester.element(find.byType(AppShell)),
  ).read(syncAvailableProvider);
  await tester.pumpWidget(const SizedBox.shrink());
  return available;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('startup asks Android before building the app', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      _messenger.setMockMethodCallHandler(_channel, null);
    });

    final List<String> no = _answering(false);
    expect((await fieldNotesAppForThisDevice()).syncAvailable, isFalse);
    expect(no, <String>['available']);

    final List<String> yes = _answering(true);
    expect((await fieldNotesAppForThisDevice()).syncAvailable, isTrue);
    expect(yes, <String>['available']);
  });

  testWidgets('the startup answer reaches the app providers', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    expect(
      await _syncAvailableInShell(
        tester,
        const FieldNotesApp(syncAvailable: false),
      ),
      isFalse,
    );
    expect(await _syncAvailableInShell(tester, const FieldNotesApp()), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
