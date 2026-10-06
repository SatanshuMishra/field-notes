import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/pairing/pairing_code.dart';
import 'package:field_notes/data/sync/pairing/pairing_service.dart';
import 'package:field_notes/features/sync/ui/join_journal_flow.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

final Uri _relay = Uri.parse('https://relay.example');
final String _pairing = _payload(1);
final String _otherPairing = _payload(2);

String _payload(int fill) => PairingCode(
  secret: List<int>.filled(pairingSecretBytes, fill),
  relayUrl: _relay,
).qrPayload;

class _NoCameras extends CameraPlatform {
  @override
  Future<List<CameraDescription>> availableCameras() async =>
      const <CameraDescription>[];
}

class _FakeJoin {
  final List<String> codes = <String>[];
  final List<bool Function()> cancelSignals = <bool Function()>[];
  Completer<void> answer = Completer<void>();

  Future<void> call(String code, {Uri? relayUrl, bool Function()? cancelled}) {
    codes.add(code);
    if (cancelled != null) {
      cancelSignals.add(cancelled);
    }
    return answer.future;
  }
}

class _Opened {
  bool? result;
  bool closed = false;
}

Future<_Opened> _openFlow(WidgetTester tester, _FakeJoin join) async {
  final _Opened opened = _Opened();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              opened.result = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (BuildContext _) =>
                      Scaffold(body: JoinJournalFlow(join: join.call)),
                ),
              );
              opened.closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return opened;
}

void _scan(WidgetTester tester, String text) {
  tester.widget<ReaderWidget>(find.byType(ReaderWidget)).onScan!(
    Code(text: text, isValid: true),
  );
}

void _usePhoneCamera() {
  final CameraPlatform original = CameraPlatform.instance;
  CameraPlatform.instance = _NoCameras();
  addTearDown(() => CameraPlatform.instance = original);
}

void main() {
  test('only a pairing code is taken from what the scanner reads', () {
    expect(
      pairingCodeIn(<String?>[
        null,
        'https://example.com',
        '  FieldNotes-Pair:abc  ',
      ]),
      '  FieldNotes-Pair:abc  ',
    );
    expect(pairingCodeIn(<String?>['fieldnotes-pairing:abc', null]), isNull);
    expect(pairingCodeIn(const <String?>[]), isNull);
  });

  testWidgets('a scanned code joins only after its server is confirmed', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _FakeJoin join = _FakeJoin();
    final _Opened opened = await _openFlow(tester, join);

    _scan(tester, 'https://example.com');
    await tester.pump();
    expect(join.codes, isEmpty);

    _scan(tester, _pairing);
    await tester.pump();
    expect(find.text(joinServerTitle(_relay)), findsOneWidget);
    expect(find.text('Join relay.example?'), findsOneWidget);
    expect(find.text(joinServerMessage(phone: true)), findsOneWidget);
    expect(find.text('https://relay.example'), findsOneWidget);
    expect(find.byType(ReaderWidget), findsNothing);
    expect(join.codes, isEmpty);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.tap(find.byKey(joinServerConfirmKey));
    await tester.pump();
    expect(find.text(joinWaitingTitle), findsOneWidget);
    expect(find.byType(ReaderWidget), findsNothing);
    expect(join.codes, <String>[_pairing]);

    join.answer.complete();
    await tester.pumpAndSettle();
    expect(opened.result, isTrue);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('declining a server goes back to scanning and skips that code', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    final _FakeJoin join = _FakeJoin();
    await _openFlow(tester, join);

    _scan(tester, _pairing);
    await tester.pump();
    await tester.tap(find.text(joinDeclineLabel));
    await tester.pump();
    expect(find.byType(ReaderWidget), findsOneWidget);
    expect(find.text(joinServerTitle(_relay)), findsNothing);

    _scan(tester, _pairing);
    await tester.pump();
    expect(find.byType(ReaderWidget), findsOneWidget);

    _scan(tester, _otherPairing);
    await tester.pump();
    expect(find.text(joinServerTitle(_relay)), findsOneWidget);
    expect(join.codes, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a second tap on Join starts nothing more', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    final _FakeJoin join = _FakeJoin();
    await _openFlow(tester, join);

    _scan(tester, _pairing);
    await tester.pump();
    await tester.tap(find.byKey(joinServerConfirmKey));
    await tester.tap(find.byKey(joinServerConfirmKey), warnIfMissed: false);
    await tester.pump();

    expect(join.codes, <String>[_pairing]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Cancel while waiting tells the join to stop', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    final _FakeJoin join = _FakeJoin();
    final _Opened opened = await _openFlow(tester, join);

    _scan(tester, _pairing);
    await tester.pump();
    await tester.tap(find.byKey(joinServerConfirmKey));
    await tester.pump();
    expect(join.cancelSignals.single(), isFalse);

    await tester.tap(find.text(syncCancelLabel));
    await tester.pumpAndSettle();

    expect(opened.result, isFalse);
    expect(join.cancelSignals.single(), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a code whose address hides another server is refused', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    final _FakeJoin join = _FakeJoin();
    await _openFlow(tester, join);

    _scan(
      tester,
      _pairing.replaceFirst(
        'https://relay.example',
        'https://relay.example@attacker.example',
      ),
    );
    await tester.pump();

    expect(find.text(pairingRetryMessage), findsOneWidget);
    expect(find.byType(ReaderWidget), findsOneWidget);
    expect(find.textContaining('attacker'), findsNothing);
    expect(join.codes, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a refused code is not retried while it stays in view', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    final _FakeJoin join = _FakeJoin();
    await _openFlow(tester, join);

    _scan(tester, _pairing);
    await tester.pump();
    await tester.tap(find.byKey(joinServerConfirmKey));
    await tester.pump();
    join.answer.completeError(const SyncSetupException('That code expired.'));
    await tester.pumpAndSettle();
    expect(find.text('That code expired.'), findsOneWidget);
    expect(find.byType(ReaderWidget), findsOneWidget);

    join.answer = Completer<void>();
    _scan(tester, _pairing);
    await tester.pump();
    expect(join.codes, <String>[_pairing]);
    expect(find.text('That code expired.'), findsOneWidget);

    _scan(tester, _otherPairing);
    await tester.pump();
    expect(join.codes, <String>[_pairing]);
    await tester.tap(find.byKey(joinServerConfirmKey));
    await tester.pump();
    expect(join.codes, <String>[_pairing, _otherPairing]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a code read after Cancel starts nothing', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    final _FakeJoin join = _FakeJoin();
    final _Opened opened = await _openFlow(tester, join);
    final ValueChanged<Code> onScan = tester
        .widget<ReaderWidget>(find.byType(ReaderWidget))
        .onScan!;

    await tester.tap(find.text(syncCancelLabel));
    await tester.pump();
    onScan(Code(text: _pairing, isValid: true));
    await tester.pumpAndSettle();

    expect(join.codes, isEmpty);
    expect(opened.result, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a phone can switch to typing the 8 words and back', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    await _openFlow(tester, _FakeJoin());

    await tester.tap(find.byKey(typeWordsInsteadKey));
    await tester.pump();
    expect(find.byType(ReaderWidget), findsNothing);
    expect(find.text(joinWordsLabel), findsOneWidget);

    await tester.tap(find.text(joinBackLabel));
    await tester.pump();
    expect(find.byType(ReaderWidget), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a pairing code pasted into the words asks about its server', (
    WidgetTester tester,
  ) async {
    final _FakeJoin join = _FakeJoin();
    await _openFlow(tester, join);

    await tester.enterText(find.byType(EditableText).first, _pairing);
    await tester.tap(find.byKey(joinConfirmKey));
    await tester.pump();
    expect(find.text(joinServerTitle(_relay)), findsOneWidget);
    expect(find.text(joinServerMessage(phone: false)), findsOneWidget);
    expect(join.codes, isEmpty);

    await tester.tap(find.text(joinDeclineLabel));
    await tester.pump();
    expect(find.text(joinWordsLabel), findsOneWidget);

    await tester.tap(find.byKey(joinConfirmKey));
    await tester.pump();
    await tester.tap(find.byKey(joinServerConfirmKey));
    await tester.pump();
    expect(join.codes, <String>[_pairing]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
    'a pasted code for another server than the typed one is refused',
    (WidgetTester tester) async {
      final _FakeJoin join = _FakeJoin();
      await _openFlow(tester, join);

      await tester.enterText(find.byType(EditableText).first, _pairing);
      await tester.enterText(
        find.byType(EditableText).last,
        'sync.example.test',
      );
      await tester.tap(find.byKey(joinConfirmKey));
      await tester.pump();

      expect(
        find.text('That code is for relay.example, not sync.example.test.'),
        findsOneWidget,
      );
      expect(find.text(joinServerTitle(_relay)), findsNothing);
      expect(join.codes, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('a Mac joins by typing the 8 words and can cancel', (
    WidgetTester tester,
  ) async {
    final _Opened opened = await _openFlow(tester, _FakeJoin());

    expect(find.byType(ReaderWidget), findsNothing);
    expect(find.text(joinWordsLabel), findsOneWidget);
    expect(find.text(joinBackLabel), findsNothing);

    await tester.tap(find.text(syncCancelLabel));
    await tester.pumpAndSettle();
    expect(opened.result, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
