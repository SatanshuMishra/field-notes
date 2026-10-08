import 'dart:async';

import 'package:camera_macos/camera_macos.dart' show CameraImageData;
import 'package:camera_platform_interface/camera_platform_interface.dart'
    show CameraDescription, CameraPlatform;
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/pairing/pairing_code.dart';
import 'package:field_notes/data/sync/pairing/pairing_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/features/sync/ui/join_journal_flow.dart';
import 'package:field_notes/features/sync/ui/join_window.dart';
import 'package:field_notes/features/sync/ui/mac_code_scanner.dart';
import 'package:field_notes/features/sync/ui/qr_frame_decoder.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:sync_protocol/sync_protocol.dart';

const Size _phone = Size(384, 832);
const Size _mac = Size(1280, 800);
const double _statusBar = 34;
const double _gestureBar = 24;

final Uri _relay = Uri.parse('https://relay.example');
final String _pairing = _payload(1);
final String _otherPairing = _payload(2);

String _payload(int fill) => PairingCode(
  secret: List<int>.filled(pairingSecretBytes, fill),
  relayUrl: _relay,
).qrPayload;

const SyncSetupException _expired = SyncSetupException(
  'That code expired.',
  RelayRejected(
    code: SyncErrorCode.pairingExpired,
    message: 'Pairing expired',
    statusCode: 410,
  ),
);

CameraImageData _frame() =>
    CameraImageData(width: 4, height: 2, bytesPerRow: 16, bytes: Uint8List(32));

Future<String?> _decodePairing(CameraImageData frame) async => _pairing;

class _NoCameras extends CameraPlatform {
  @override
  Future<List<CameraDescription>> availableCameras() async =>
      const <CameraDescription>[];
}

class _StillMacCamera implements MacScannerCamera {
  @override
  Widget preview() => const SizedBox.expand();

  @override
  Future<void> start() async {}

  @override
  Future<CameraImageData?> takeFrame() => Completer<CameraImageData?>().future;

  @override
  Future<void> stop() async {}
}

class _FrameMacCamera implements MacScannerCamera {
  Completer<CameraImageData?>? _request;

  @override
  Widget preview() => const SizedBox.expand();

  @override
  Future<void> start() async {}

  @override
  Future<CameraImageData?> takeFrame() {
    final Completer<CameraImageData?> request = Completer<CameraImageData?>();
    _request = request;
    return request.future;
  }

  void send(CameraImageData? frame) {
    final Completer<CameraImageData?>? request = _request;
    _request = null;
    request?.complete(frame);
  }

  @override
  Future<void> stop() async => send(null);
}

class _FakeJoin {
  final List<String> codes = <String>[];
  final List<Uri?> relays = <Uri?>[];
  final List<bool Function()> cancelSignals = <bool Function()>[];
  JournalConfirmation? confirmJournal;
  void Function(String comparison)? showComparison;
  Completer<void> answer = Completer<void>();

  Future<void> call(
    String code, {
    required JournalConfirmation confirmJournal,
    Uri? relayUrl,
    bool Function()? cancelled,
    void Function(String comparison)? onComparison,
  }) {
    codes.add(code);
    relays.add(relayUrl);
    if (cancelled != null) {
      cancelSignals.add(cancelled);
    }
    this.confirmJournal = confirmJournal;
    showComparison = onComparison;
    return answer.future;
  }
}

class _Opened {
  bool? result;
  bool closed = false;
}

void _useSurface(WidgetTester tester) {
  final bool phone = defaultTargetPlatform == TargetPlatform.android;
  final FakeViewPadding bars = phone
      ? const FakeViewPadding(top: _statusBar, bottom: _gestureBar)
      : FakeViewPadding.zero;
  tester.view.physicalSize = phone ? _phone : _mac;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = bars;
  tester.view.viewPadding = bars;
  addTearDown(tester.view.reset);
}

Future<_Opened> _openFlow(
  WidgetTester tester,
  _FakeJoin join, {
  MacScannerCamera? macCamera,
  QrFrameDecode? macDecode,
}) async {
  _useSurface(tester);
  final _Opened opened = _Opened();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              opened.result = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (BuildContext _) => Scaffold(
                    body: JoinJournalFlow(
                      join: join.call,
                      macCamera: macCamera ?? _StillMacCamera(),
                      macDecode: macDecode,
                    ),
                  ),
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
    expect(find.text(joinCheckingTitle), findsOneWidget);
    expect(find.byType(ReaderWidget), findsNothing);
    expect(join.codes, <String>[_pairing]);

    join.answer.complete();
    await tester.pumpAndSettle();
    expect(opened.result, isTrue);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the journal is named and confirmed before the number shows', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _FakeJoin join = _FakeJoin();
    final _Opened opened = await _openFlow(tester, join);
    _scan(tester, _pairing);
    await tester.pump();
    await tester.tap(find.byKey(joinServerConfirmKey));
    await tester.pump();

    final Future<bool> asked = join.confirmJournal!('Satanshu');
    await tester.pump();
    expect(find.text(joinJournalTitle), findsOneWidget);
    expect(find.text(joinJournalMessage(phone: true)), findsOneWidget);
    expect(find.text(joinJournalNameLabel), findsOneWidget);
    expect(find.text('Satanshu'), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(find.byKey(joinJournalConfirmKey));
    await tester.tap(find.byKey(joinJournalConfirmKey), warnIfMissed: false);
    await tester.pump();
    expect(await asked, isTrue);
    expect(find.text(joinCheckingTitle), findsOneWidget);

    join.showComparison!('482 913');
    await tester.pump();
    expect(find.text(joinWaitingTitle), findsOneWidget);
    expect(find.text(joinWaitingMessage), findsOneWidget);
    expect(find.text('482 913'), findsOneWidget);
    expect(find.bySemanticsLabel('Number 482 913'), findsOneWidget);

    join.answer.complete();
    await tester.pumpAndSettle();
    expect(opened.result, isTrue);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('declining the journal goes back without an error', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    final _FakeJoin join = _FakeJoin();
    await _openFlow(tester, join);
    _scan(tester, _pairing);
    await tester.pump();
    await tester.tap(find.byKey(joinServerConfirmKey));
    await tester.pump();
    final Future<bool> asked = join.confirmJournal!('Alex');
    await tester.pump();

    await tester.tap(find.text(joinDeclineLabel));
    await tester.pump();
    expect(await asked, isFalse);
    join.answer.completeError(const PairingDeclined());
    await tester.pumpAndSettle();

    expect(find.byType(ReaderWidget), findsOneWidget);
    expect(find.text(pairingDeclinedMessage), findsNothing);
    expect(find.text(joinJournalTitle), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('an unnamed journal is joined only with a warning', (
    WidgetTester tester,
  ) async {
    final _FakeJoin join = _FakeJoin();
    await _openFlow(tester, join);
    await tester.enterText(
      find.byType(EditableText).first,
      'abandon ability able about above absent absorb abstract',
    );
    await tester.enterText(
      find.byType(EditableText).last,
      'https://relay.example',
    );
    await tester.tap(find.byKey(joinConfirmKey));
    await tester.pump();

    final Future<bool> asked = join.confirmJournal!(null);
    await tester.pump();

    expect(find.text(joinJournalTitle), findsOneWidget);
    expect(find.text(joinUnnamedJournalMessage(phone: false)), findsOneWidget);
    expect(find.text(joinJournalNameLabel), findsNothing);
    expect(join.codes, <String>[
      'abandon ability able about above absent absorb abstract',
    ]);
    expect(join.relays, <Uri?>[_relay]);
    await tester.tap(find.text(joinDeclineLabel));
    await tester.pump();
    expect(await asked, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('closing the sheet while asking about the journal answers no', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    final _FakeJoin join = _FakeJoin();
    await _openFlow(tester, join);
    _scan(tester, _pairing);
    await tester.pump();
    await tester.tap(find.byKey(joinServerConfirmKey));
    await tester.pump();
    final Future<bool> asked = join.confirmJournal!('Satanshu');
    await tester.pump();

    final NavigatorState navigator = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    navigator.pop();
    await tester.pumpAndSettle();

    expect(await asked, isFalse);
    expect(join.cancelSignals.single(), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a code another device used says so', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    final _FakeJoin join = _FakeJoin();
    await _openFlow(tester, join);
    _scan(tester, _pairing);
    await tester.pump();
    await tester.tap(find.byKey(joinServerConfirmKey));
    await tester.pump();

    join.answer.completeError(const PairingTaken());
    await tester.pumpAndSettle();

    expect(find.text(pairingTakenMessage), findsOneWidget);
    expect(find.byType(ReaderWidget), findsOneWidget);
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
    join.answer.completeError(_expired);
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

  testWidgets('a Mac retries the same code after a network failure', (
    WidgetTester tester,
  ) async {
    final _FrameMacCamera camera = _FrameMacCamera();
    final _FakeJoin join = _FakeJoin();
    final _Opened opened = await _openFlow(
      tester,
      join,
      macCamera: camera,
      macDecode: _decodePairing,
    );

    camera.send(_frame());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(joinServerConfirmKey));
    await tester.pump();
    expect(join.codes, <String>[_pairing]);

    join.answer.completeError(
      setupFailure(const RelayUnreachable('connection refused')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(JoinWindow), findsOneWidget);
    expect(find.text(unreachableMessage), findsOneWidget);

    join.answer = Completer<void>();
    camera.send(_frame());
    await tester.pumpAndSettle();
    expect(find.text(joinServerTitle(_relay)), findsOneWidget);
    await tester.tap(find.byKey(joinServerConfirmKey));
    await tester.pump();
    expect(join.codes, <String>[_pairing, _pairing]);

    join.answer.complete();
    await tester.pumpAndSettle();
    expect(opened.closed, isTrue);
    expect(opened.result, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a Mac skips a code the server declined', (
    WidgetTester tester,
  ) async {
    final _FrameMacCamera camera = _FrameMacCamera();
    final _FakeJoin join = _FakeJoin();
    await _openFlow(tester, join, macCamera: camera, macDecode: _decodePairing);

    camera.send(_frame());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(joinServerConfirmKey));
    await tester.pump();
    join.answer.completeError(_expired);
    await tester.pumpAndSettle();
    expect(find.byType(JoinWindow), findsOneWidget);
    expect(find.text('That code expired.'), findsOneWidget);

    camera.send(_frame());
    await tester.pumpAndSettle();
    expect(find.text(joinServerTitle(_relay)), findsNothing);
    expect(find.byType(JoinWindow), findsOneWidget);
    expect(join.codes, <String>[_pairing]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

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
    expect(find.text(joinTypeTitle), findsOneWidget);

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
    await tester.pump();
    await tester.tap(find.byKey(joinConfirmKey));
    await tester.pump();
    expect(find.text(joinServerTitle(_relay)), findsOneWidget);
    expect(find.text(joinServerMessage(phone: false)), findsOneWidget);
    expect(join.codes, isEmpty);

    await tester.tap(find.text(joinDeclineLabel));
    await tester.pump();
    expect(find.byType(JoinWindow), findsOneWidget);
    expect(find.text(joinTypeTitle), findsOneWidget);

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
    expect(find.byType(JoinWindow), findsOneWidget);
    expect(find.text(joinTypeTitle), findsOneWidget);
    expect(find.text(joinBackLabel), findsNothing);

    await tester.tap(find.text(syncCancelLabel));
    await tester.pumpAndSettle();
    expect(opened.result, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
