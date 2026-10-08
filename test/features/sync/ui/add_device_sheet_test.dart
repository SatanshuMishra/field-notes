import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/device_names.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/pairing/pairing_code.dart';
import 'package:field_notes/data/sync/pairing/pairing_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/sync/ui/add_device_sheet.dart';
import 'package:field_notes/features/sync/ui/comparison_number.dart';
import 'package:field_notes/features/sync/ui/pairing_qr.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:field_notes/features/sync/ui/sync_flow_page.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sync_protocol/sync_protocol.dart'
    show
        ChallengeResponse,
        DeviceRegistration,
        PairingJoinRequest,
        PairingStatus,
        PairingStatusResponse,
        SessionResponse,
        SyncMessage,
        deviceCertificateBytes;

import '../../../support/sync_overrides.dart';

const Size _phone = Size(384, 832);
const Size _mac = Size(1440, 900);
const double _statusBar = 34;
const double _gestureBar = 24;
const double _phoneCode = 268;
const double _macCode = 300;
const double _macPanel = 820;
const double _dialogMaxWidth = 460;
const double _macWordSize = 18;
const Offset _macCorner = Offset(5, 5);
const Color _rose = Color(0xFFB8566A);
const String _joinerName = 'Kitchen laptop';
const String _fullCountdown = 'Works for 10:00 more';

final DateTime _now = DateTime.utc(2026, 10, 8, 9);
final DateTime _farAway = DateTime.utc(2100);
final Uri _relay = Uri.parse('https://relay.example');

final Finder _paintedCode = find.byWidgetPredicate(
  (Widget widget) => widget is CustomPaint && widget.painter is FlowerQrPainter,
);

final class _FakeRelay {
  final Map<String, PairingJoinRequest> _joins = <String, PairingJoinRequest>{};
  Completer<void> _polled = Completer<void>();

  Future<void> wait(Duration _) => _polled.future;

  RelayClient client(Uri baseUrl, DeviceKeys? device) => RelayClient(
    baseUrl: baseUrl,
    device: device,
    client: MockClient(_answer),
  );

  void join(PairingCode code) {
    final DeviceKeys device = DeviceKeys.generate();
    final DeviceRegistration registration = device.registration(
      certificate: device.sign(
        deviceCertificateBytes(
          deviceId: device.deviceId,
          signPublicKey: device.signKeyPair.publicKey,
          boxPublicKey: device.boxKeyPair.publicKey,
        ),
      ),
      encryptedName: sealNameUnder(
        _joinerName,
        device.deviceId,
        code.pairingKey,
      ),
    );
    _joins[code.mailboxId] = PairingJoinRequest(
      device: registration,
      authenticator: code.authenticatorFor(registration),
    );
    final Completer<void> polled = _polled;
    _polled = Completer<void>();
    polled.complete();
  }

  Future<http.Response> _answer(http.Request request) async {
    final SyncMessage reply = switch ((
      request.method,
      request.url.pathSegments,
    )) {
      ('POST', <String>['v1', 'session', 'challenge']) => ChallengeResponse(
        challengeId: 'challenge',
        nonce: 'nonce',
        expiresAt: _farAway,
      ),
      ('POST', <String>['v1', 'session']) => SessionResponse(
        token: 'session',
        expiresAt: _farAway,
        currentEpoch: 1,
        uploadPass: 'pass',
        uploadPassExpiresAt: _farAway,
        generation: 'generation',
      ),
      ('POST', <String>['v1', 'pairing']) => PairingStatusResponse(
        status: PairingStatus.open,
      ),
      ('GET', <String>['v1', 'pairing', final String mailbox]) => _statusOf(
        mailbox,
      ),
      _ => throw StateError('No answer for ${request.method} ${request.url}'),
    };
    return http.Response(
      jsonEncode(reply.toJson()),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }

  PairingStatusResponse _statusOf(String mailbox) {
    final PairingJoinRequest? join = _joins[mailbox];
    return join == null
        ? PairingStatusResponse(status: PairingStatus.open)
        : PairingStatusResponse(status: PairingStatus.joined, join: join);
  }
}

final class _Host {
  late BuildContext context;
}

final class _Opened {
  bool closed = false;
}

Future<PairingService> _pairingService(
  AppDatabase database,
  _FakeRelay relay,
) async {
  final KeyStore keyStore = KeyStore(MemorySecureValues());
  await storeEnrolledDevice(
    database: database,
    keyStore: keyStore,
    relayUrl: _relay,
    accountId: 'account',
    journalKeys: JournalKeys.generate(),
    deviceKeys: DeviceKeys.generate(),
  );
  return PairingService(
    database: database,
    keyStore: keyStore,
    clientFor: relay.client,
    deviceName: () async => 'Desk',
    wait: relay.wait,
    clock: () => _now,
  );
}

void _useSurface(WidgetTester tester, TargetPlatform platform) {
  final bool phone = platform == TargetPlatform.android;
  final FakeViewPadding bars = phone
      ? const FakeViewPadding(top: _statusBar, bottom: _gestureBar)
      : FakeViewPadding.zero;
  tester.view.physicalSize = phone ? _phone : _mac;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = bars;
  tester.view.viewPadding = bars;
  addTearDown(tester.view.reset);
}

Future<_Host> _pumpHost(
  WidgetTester tester, {
  required TargetPlatform platform,
  required PairingService service,
  required Brightness brightness,
}) async {
  _useSurface(tester, platform);
  final _Host host = _Host();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        for (final Override override in syncOffOverrides())
          if (override.origin != pairingServiceProvider) override,
        pairingServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform, brightness: brightness),
        home: Builder(
          builder: (BuildContext context) {
            host.context = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return host;
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<_Opened> _open(WidgetTester tester, _Host host) async {
  final _Opened opened = _Opened();
  unawaited(
    showSyncFlow<void>(
      host.context,
      builder: (BuildContext _) => AddDeviceSheet(clock: () => _now),
    ).then((void _) => opened.closed = true),
  );
  await _settle(tester);
  return opened;
}

PairingCode _shownCode(WidgetTester tester) =>
    PairingCode.parse(tester.widget<PairingQr>(find.byType(PairingQr)).payload);

Future<void> _joinFrom(WidgetTester tester, _FakeRelay relay) async {
  relay.join(_shownCode(tester));
  for (
    int frame = 0;
    frame < 20 && find.text(addDeviceCandidateTitle).evaluate().isEmpty;
    frame++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await _settle(tester);
}

FieldNotesColors _colorsFor(Brightness brightness) => switch (brightness) {
  Brightness.light => FieldNotesColors.light,
  Brightness.dark => FieldNotesColors.dark,
};

Future<PairingCode> _expectPhonePage(
  WidgetTester tester,
  Brightness brightness,
) async {
  final Finder page = find.byType(SyncFlowPage);
  expect(page, findsOneWidget);
  expect(tester.getRect(page), Offset.zero & _phone);
  expect(find.byType(PhoneSheet), findsNothing);
  expect(
    tester
        .widget<ColoredBox>(
          find.descendant(of: page, matching: find.byType(ColoredBox)).first,
        )
        .color
        .toARGB32(),
    _colorsFor(brightness).page.toARGB32(),
  );
  expect(
    find.descendant(of: page, matching: find.text(addDeviceKicker)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: page, matching: find.text(addDeviceTitle)),
    findsOneWidget,
  );

  expect(_paintedCode, findsOneWidget);
  final Rect code = tester.getRect(_paintedCode);
  expect(code.size, const Size.square(_phoneCode));
  expect(code.center.dx, closeTo(_phone.width / 2, 0.5));

  final PairingCode shown = _shownCode(tester);
  expect(shown.words, hasLength(8));
  final Finder words = find.text(shown.words.join(pairingWordSeparator));
  expect(words, findsOneWidget);
  expect(find.text(typeTheseWordsLabel), findsOneWidget);
  expect(tester.getRect(words).top, greaterThan(code.bottom));
  final Finder countdown = find.text(_fullCountdown);
  expect(countdown, findsOneWidget);
  expect(
    tester.getRect(countdown).top,
    greaterThan(tester.getRect(words).bottom),
  );

  final Finder footer = find.byKey(syncFlowPageFooterKey);
  final Finder done = find.descendant(
    of: footer,
    matching: find.text(addDeviceDoneLabel),
  );
  expect(done, findsOneWidget);
  expect(tester.getRect(done).top, greaterThan(tester.getRect(countdown).top));
  expect(
    tester.getRect(footer).bottom,
    lessThanOrEqualTo(_phone.height - _gestureBar),
  );
  expect(find.bySemanticsLabel(pairingQrLabel), findsOneWidget);
  expect(find.bySemanticsLabel(syncFlowCloseLabel), findsOneWidget);
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  return shown;
}

Future<PairingCode> _expectMacPanel(
  WidgetTester tester,
  Brightness brightness,
) async {
  final FieldNotesColors colors = _colorsFor(brightness);
  expect(find.byType(SyncFlowPage), findsNothing);
  expect(find.byType(PhoneSheet), findsNothing);
  final Finder panel = find.byKey(addDevicePanelKey);
  expect(panel, findsOneWidget);
  final Rect panelRect = tester.getRect(panel);
  expect(panelRect.width, _macPanel);
  expect(panelRect.center.dx, closeTo(_mac.width / 2, 0.5));
  expect(panelRect.center.dy, closeTo(_mac.height / 2, 0.5));
  expect(
    tester.widget<StickerCard>(panel).surface!.toARGB32(),
    colors.cardBright.toARGB32(),
  );
  expect(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is ColoredBox &&
          widget.color.toARGB32() ==
              Palette.toolbarInk.withValues(alpha: 0.42).toARGB32(),
    ),
    findsOneWidget,
  );

  expect(_paintedCode, findsOneWidget);
  final Rect code = tester.getRect(_paintedCode);
  expect(code.size, const Size.square(_macCode));
  expect(code.left, greaterThan(panelRect.left));
  final Finder title = find.descendant(
    of: panel,
    matching: find.text(addDeviceTitle),
  );
  expect(title, findsOneWidget);
  expect(code.right, lessThan(tester.getRect(title).left));
  final Finder kicker = find.descendant(
    of: panel,
    matching: find.text(addDeviceKicker),
  );
  expect(kicker, findsOneWidget);
  expect(
    tester.widget<Text>(kicker).style!.fontFamily,
    TypographyTokens.accent,
  );
  expect(
    find.descendant(of: panel, matching: find.text(addDeviceMessage)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: panel, matching: find.text(typeTheseWordsLabel)),
    findsOneWidget,
  );

  final PairingCode shown = _shownCode(tester);
  expect(shown.words, hasLength(8));
  final List<Rect> rows = <Rect>[
    for (int position = 1; position <= 8; position++)
      tester.getRect(find.byKey(addDeviceWordKey(position))),
  ];
  for (int position = 1; position <= 8; position++) {
    final Finder row = find.byKey(addDeviceWordKey(position));
    expect(
      find.descendant(of: row, matching: find.text('$position')),
      findsOneWidget,
    );
    final Finder word = find.descendant(
      of: row,
      matching: find.text(shown.words[position - 1]),
    );
    expect(word, findsOneWidget);
    final TextStyle style = tester.widget<Text>(word).style!;
    expect(style.fontFamily, TypographyTokens.serif);
    expect(style.fontSize, _macWordSize);
    expect(rows[position - 1].left, greaterThan(code.right));
  }
  for (final int first in <int>[0, 4]) {
    for (int offset = 1; offset < 4; offset++) {
      expect(rows[first + offset].left, rows[first].left);
      expect(
        rows[first + offset].top,
        greaterThan(rows[first + offset - 1].top),
      );
    }
  }
  expect(rows[4].top, rows[0].top);
  expect(rows[4].left, greaterThan(rows[0].right));

  final Finder countdown = find.descendant(
    of: panel,
    matching: find.text(_fullCountdown),
  );
  expect(countdown, findsOneWidget);
  expect(tester.getRect(countdown).top, greaterThan(rows[3].bottom));

  final Finder done = find.descendant(
    of: panel,
    matching: find.widgetWithText(StickerButton, addDeviceDoneLabel),
  );
  expect(done, findsOneWidget);
  final StickerButton button = tester.widget<StickerButton>(done);
  expect(button.variant, StickerButtonVariant.primary);
  final BoxDecoration face =
      tester
              .widget<DecoratedBox>(
                find.descendant(of: done, matching: find.byType(DecoratedBox)),
              )
              .decoration
          as BoxDecoration;
  expect(face.color!.toARGB32(), _rose.toARGB32());
  final Rect doneRect = tester.getRect(done);
  expect(doneRect.top, greaterThan(tester.getRect(countdown).bottom));
  expect(doneRect.right, greaterThan(panelRect.right - 48));
  expect(doneRect.bottom, greaterThan(panelRect.bottom - 48));
  expect(doneRect.left, greaterThan(panelRect.center.dx));
  expect(find.bySemanticsLabel(pairingQrLabel), findsOneWidget);
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  return shown;
}

void main() {
  testWidgets('the phone add-device page paints a 268-point code', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    try {
      final _FakeRelay relay = _FakeRelay();
      final PairingService service = await _pairingService(database, relay);

      final _Host dark = await _pumpHost(
        tester,
        platform: TargetPlatform.android,
        service: service,
        brightness: Brightness.dark,
      );
      final _Opened darkPage = await _open(tester, dark);
      await _expectPhonePage(tester, Brightness.dark);
      await tester.tap(find.byKey(syncFlowPageCloseKey));
      await _settle(tester);
      expect(darkPage.closed, isTrue);
      expect(find.byType(SyncFlowPage), findsNothing);

      final _Host light = await _pumpHost(
        tester,
        platform: TargetPlatform.android,
        service: service,
        brightness: Brightness.light,
      );
      final _Opened page = await _open(tester, light);
      await _expectPhonePage(tester, Brightness.light);

      await _joinFrom(tester, relay);
      expect(find.byType(SyncFlowPage), findsNothing);
      expect(_paintedCode, findsNothing);
      final Finder sheet = find.ancestor(
        of: find.text(addDeviceCandidateTitle),
        matching: find.byType(PhoneSheet),
      );
      expect(sheet, findsOneWidget);
      final Rect sheetRect = tester.getRect(sheet);
      expect(sheetRect.bottom, _phone.height);
      expect(sheetRect.width, _phone.width);
      expect(sheetRect.height, lessThan(_phone.height / 2));
      expect(
        find.descendant(of: sheet, matching: find.byType(ComparisonNumber)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text(_joinerName)),
        findsOneWidget,
      );
      expect(find.byKey(addDeviceConfirmKey), findsOneWidget);

      await tester.tap(find.text(dontAddLabel));
      await _settle(tester);
      expect(page.closed, isTrue);
      expect(find.text(addDeviceCandidateTitle), findsNothing);
    } finally {
      await tester.runAsync(database.close);
    }
    semantics.dispose();
  });

  testWidgets('the Mac add-device panel paints a 300-point code', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    try {
      final _FakeRelay relay = _FakeRelay();
      final PairingService service = await _pairingService(database, relay);

      final _Host light = await _pumpHost(
        tester,
        platform: TargetPlatform.macOS,
        service: service,
        brightness: Brightness.light,
      );
      final _Opened escaped = await _open(tester, light);
      await _expectMacPanel(tester, Brightness.light);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(escaped.closed, isTrue);
      expect(find.byKey(addDevicePanelKey), findsNothing);

      final _Opened candidate = await _open(tester, light);
      await _expectMacPanel(tester, Brightness.light);
      await _joinFrom(tester, relay);
      expect(find.byKey(addDevicePanelKey), findsNothing);
      expect(_paintedCode, findsNothing);
      expect(find.byType(PhoneSheet), findsNothing);
      final Finder dialog = find.ancestor(
        of: find.text(addDeviceCandidateTitle),
        matching: find.byType(StickerCard),
      );
      expect(dialog, findsOneWidget);
      final Rect dialogRect = tester.getRect(dialog);
      expect(dialogRect.width, lessThanOrEqualTo(_dialogMaxWidth));
      expect(dialogRect.center.dx, closeTo(_mac.width / 2, 0.5));
      expect(
        find.descendant(of: dialog, matching: find.byType(ComparisonNumber)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text(_joinerName)),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(candidate.closed, isTrue);

      final _Host dark = await _pumpHost(
        tester,
        platform: TargetPlatform.macOS,
        service: service,
        brightness: Brightness.dark,
      );
      final _Opened tapped = await _open(tester, dark);
      await _expectMacPanel(tester, Brightness.dark);
      await tester.tapAt(_macCorner);
      await _settle(tester);
      expect(tapped.closed, isTrue);
      expect(find.byKey(addDevicePanelKey), findsNothing);
    } finally {
      await tester.runAsync(database.close);
    }
    semantics.dispose();
  });
}
