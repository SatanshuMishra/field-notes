import 'dart:async';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:field_notes/app/shell/system_bars.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/crypto/recovery_phrase.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/enrolment/restore_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/sync/ui/recovery_phrase_check.dart';
import 'package:field_notes/features/sync/ui/restore_flow.dart';
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

import '../../../support/sync_overrides.dart';

const Size _phone = Size(384, 832);
const Size _mac = Size(1280, 800);
const double _statusBar = 34;
const double _gestureBar = 24;
const double _keyboard = 300;
const double _closeCorner = 60;
const double _minTarget = 48;
const double _footerSide = 12;
const double _dialogMaxWidth = 460;
const Offset _macCorner = Offset(5, 5);
const Offset _aboveSheet = Offset(192, 120);

final RegExp _checkLabel = RegExp(r'^Word (\d+)$');

final class _Host {
  late BuildContext context;
}

final class _Opened<T> {
  T? result;
  bool closed = false;
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

List<Override> _overrides(AppDatabase database, int seed) => <Override>[
  for (final Override override in syncOffOverrides())
    if (override.origin != enrolmentServiceProvider) override,
  enrolmentServiceProvider.overrideWithValue(
    stubRelayEnrolment(database, random: Random(seed)),
  ),
];

Future<_Host> _pumpHost(
  WidgetTester tester, {
  required TargetPlatform platform,
  required List<Override> overrides,
  Brightness brightness = Brightness.light,
}) async {
  _useSurface(tester, platform);
  final _Host host = _Host();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: overrides,
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

Future<_Opened<T>> _open<T>(
  WidgetTester tester,
  _Host host,
  Widget flow,
) async {
  final _Opened<T> opened = _Opened<T>();
  unawaited(
    showSyncFlow<T>(host.context, builder: (BuildContext _) => flow).then((
      T? value,
    ) {
      opened.result = value;
      opened.closed = true;
    }),
  );
  await tester.pumpAndSettle();
  return opened;
}

Finder _fieldLabelled(String label) => find
    .descendant(
      of: find
          .ancestor(of: find.text(label), matching: find.byType(Column))
          .first,
      matching: find.byType(EditableText),
    )
    .first;

Future<void> _continueToPhrase(WidgetTester tester) async {
  await tester.enterText(
    _fieldLabelled(serverAddressLabel),
    'https://sync.example.com',
  );
  await tester.enterText(_fieldLabelled(inviteCodeLabel), 'invite-1');
  await tester.pump();
  await tester.tap(find.byKey(startSyncContinueKey));
  await tester.pumpAndSettle();
  expect(find.text(recoveryPhraseTitle), findsOneWidget);
}

Map<int, String> _readWords(WidgetTester tester) => <int, String>{
  for (int position = 1; position <= 12; position++)
    position: tester.widget<Text>(find.byKey(recoveryWordKey(position))).data!,
};

void _expectWordColumns(WidgetTester tester, int columns) {
  final double firstRow = tester.getTopLeft(find.byKey(recoveryWordKey(1))).dy;
  expect(tester.getTopLeft(find.byKey(recoveryWordKey(columns))).dy, firstRow);
  expect(
    tester.getTopLeft(find.byKey(recoveryWordKey(columns + 1))).dy,
    greaterThan(firstRow),
  );
}

List<int> _askedPositions() => <int>[
  for (final Element element
      in find
          .byWidgetPredicate(
            (Widget widget) =>
                widget is Text && _checkLabel.hasMatch(widget.data ?? ''),
          )
          .evaluate())
    int.parse(
      _checkLabel.firstMatch((element.widget as Text).data!)!.group(1)!,
    ),
];

void _expectPrivateKeyboard(WidgetTester tester, String label) {
  final EditableText field = tester.widget<EditableText>(_fieldLabelled(label));
  expect(field.autocorrect, isFalse, reason: label);
  expect(field.enableSuggestions, isFalse, reason: label);
  expect(field.enableIMEPersonalizedLearning, isFalse, reason: label);
}

Future<void> _confirmWords(WidgetTester tester, Map<int, String> words) async {
  final List<int> asked = _askedPositions();
  expect(asked, hasLength(2));
  for (final int position in asked) {
    await tester.enterText(
      _fieldLabelled(recoveryCheckLabel(position)),
      words[position]!,
    );
  }
  await tester.pump();
  await tester.tap(find.byKey(turnOnSyncKey));
  await tester.pumpAndSettle();
}

Future<void> _escape(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}

Future<void> _expectPhonePage(
  WidgetTester tester, {
  required String title,
  required List<String> actions,
  Brightness brightness = Brightness.light,
  bool closable = true,
}) async {
  final Finder page = find.byType(SyncFlowPage);
  expect(page, findsOneWidget, reason: title);
  expect(find.byType(PhoneSheet), findsNothing, reason: title);
  expect(find.byType(StickerCard), findsNothing, reason: title);
  expect(
    find.descendant(of: page, matching: find.text(title)),
    findsOneWidget,
    reason: title,
  );
  expect(tester.getRect(page), Offset.zero & _phone, reason: title);

  final FieldNotesColors colors = switch (brightness) {
    Brightness.light => FieldNotesColors.light,
    Brightness.dark => FieldNotesColors.dark,
  };
  final ColoredBox ground = tester.widget<ColoredBox>(
    find.descendant(of: page, matching: find.byType(ColoredBox)).first,
  );
  expect(ground.color.toARGB32(), colors.page.toARGB32(), reason: title);
  expect(
    tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find
              .descendant(
                of: page,
                matching: find.byWidgetPredicate(
                  (Widget widget) =>
                      widget is AnnotatedRegion<SystemUiOverlayStyle>,
                ),
              )
              .first,
        )
        .value,
    systemBarsOver(brightness),
    reason: title,
  );

  final Finder close = find.byKey(syncFlowPageCloseKey);
  final Finder closeLabel = find.descendant(
    of: page,
    matching: find.bySemanticsLabel(syncFlowCloseLabel),
  );
  if (closable) {
    final Rect closeRect = tester.getRect(close);
    expect(closeRect.width, greaterThanOrEqualTo(_minTarget), reason: title);
    expect(closeRect.height, greaterThanOrEqualTo(_minTarget), reason: title);
    expect(closeRect.left, greaterThanOrEqualTo(0), reason: title);
    expect(closeRect.right, lessThanOrEqualTo(_closeCorner), reason: title);
    expect(closeRect.top, greaterThanOrEqualTo(_statusBar), reason: title);
    expect(
      closeRect.bottom,
      lessThanOrEqualTo(_statusBar + _closeCorner),
      reason: title,
    );
    expect(closeLabel, findsOneWidget, reason: title);
  } else {
    expect(close, findsNothing, reason: title);
    expect(closeLabel, findsNothing, reason: title);
  }

  final Finder footer = find.byKey(syncFlowPageFooterKey);
  for (final String label in actions) {
    expect(
      find.descendant(of: footer, matching: find.text(label)),
      findsOneWidget,
      reason: '$title: $label',
    );
  }
  expect(
    tester.getRect(footer).bottom,
    lessThanOrEqualTo(_phone.height - _gestureBar),
    reason: title,
  );
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
  await tester.pump();
  expect(tester.getRect(page), Offset.zero & _phone, reason: title);
  final Rect lifted = tester.getRect(footer);
  expect(
    lifted.bottom,
    lessThanOrEqualTo(_phone.height - _keyboard),
    reason: title,
  );
  expect(lifted.height, greaterThanOrEqualTo(_minTarget), reason: title);
  expect(lifted.left, _footerSide, reason: title);
  expect(lifted.right, _phone.width - _footerSide, reason: title);
  tester.view.resetViewInsets();
  await tester.pump();
}

void _expectMacDialog(WidgetTester tester, String title) {
  expect(find.byType(SyncFlowPage), findsNothing, reason: title);
  expect(find.byType(PhoneSheet), findsNothing, reason: title);
  final Finder card = find.ancestor(
    of: find.text(title),
    matching: find.byType(StickerCard),
  );
  expect(card, findsOneWidget, reason: title);
  final Rect rect = tester.getRect(card);
  expect(rect.width, lessThanOrEqualTo(_dialogMaxWidth), reason: title);
  expect(rect.center.dx, closeTo(_mac.width / 2, 1), reason: title);
}

void _expectPhoneSheet(WidgetTester tester, String title) {
  expect(find.byType(SyncFlowPage), findsNothing, reason: title);
  final Finder sheet = find.ancestor(
    of: find.text(title),
    matching: find.byType(PhoneSheet),
  );
  expect(sheet, findsOneWidget, reason: title);
  final Rect rect = tester.getRect(sheet);
  expect(rect.bottom, _phone.height, reason: title);
  expect(rect.width, _phone.width, reason: title);
  expect(rect.height, lessThan(_phone.height / 2), reason: title);
}

Finder _scrim() => find.byWidgetPredicate(
  (Widget widget) =>
      widget is ColoredBox && widget.color == phoneSheetBarrierColor,
);

double _scrimOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.ancestor(of: _scrim(), matching: find.byType(FadeTransition)).first,
    )
    .opacity
    .value;

void _openUnsettled(_Host host, Widget flow) {
  unawaited(
    showSyncFlow<bool>(host.context, builder: (BuildContext _) => flow),
  );
}

Future<void> _provePhone(WidgetTester tester) async {
  final AppDatabase database = AppDatabase(NativeDatabase.memory());
  try {
    final _Host phone = await _pumpHost(
      tester,
      platform: TargetPlatform.android,
      overrides: _overrides(database, 7),
    );

    final _Opened<bool> start = await _open<bool>(
      tester,
      phone,
      const StartSyncFlow(),
    );
    await _expectPhonePage(
      tester,
      title: startSyncTitle,
      actions: <String>[syncCancelLabel, syncContinueLabel],
    );
    expect(
      tester.getCenter(find.text(syncCancelLabel)).dx,
      lessThan(tester.getCenter(find.text(syncContinueLabel)).dx),
    );
    await _continueToPhrase(tester);
    await _expectPhonePage(
      tester,
      title: recoveryPhraseTitle,
      actions: <String>[writtenDownLabel],
      closable: false,
    );
    _expectWordColumns(tester, 2);
    final Map<int, String> words = _readWords(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(start.closed, isFalse);
    expect(find.text(recoveryPhraseTitle), findsOneWidget);
    await tester.tap(find.byKey(writtenDownKey));
    await tester.pumpAndSettle();
    await _expectPhonePage(
      tester,
      title: checkPhraseTitle,
      actions: <String>[checkPhraseBackLabel, turnOnSyncLabel],
      closable: false,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(start.closed, isFalse);
    expect(find.text(checkPhraseTitle), findsOneWidget);
    await _confirmWords(tester, words);
    expect(start.closed, isTrue);
    expect(start.result, isTrue);
    expect(find.byType(SyncFlowPage), findsNothing);

    final _Opened<bool> restore = await _open<bool>(
      tester,
      phone,
      const RestoreFlow(),
    );
    await _expectPhonePage(
      tester,
      title: restoreTitle,
      actions: <String>[syncCancelLabel, restoreLabel],
    );
    await tester.tap(find.byKey(syncFlowPageCloseKey));
    await tester.pumpAndSettle();
    expect(restore.closed, isTrue);
    expect(restore.result, isNull);
    expect(find.byType(SyncFlowPage), findsNothing);

    final _Host dark = await _pumpHost(
      tester,
      platform: TargetPlatform.android,
      overrides: syncOffOverrides(),
      brightness: Brightness.dark,
    );
    await _open<bool>(tester, dark, const RestoreFlow());
    await _expectPhonePage(
      tester,
      title: restoreTitle,
      actions: <String>[syncCancelLabel, restoreLabel],
      brightness: Brightness.dark,
    );
  } finally {
    await tester.runAsync(database.close);
  }
}

Future<void> _proveMac(WidgetTester tester) async {
  final AppDatabase database = AppDatabase(NativeDatabase.memory());
  try {
    final _Host mac = await _pumpHost(
      tester,
      platform: TargetPlatform.macOS,
      overrides: _overrides(database, 9),
    );
    final _Opened<bool> dismissed = await _open<bool>(
      tester,
      mac,
      const StartSyncFlow(),
    );
    _expectMacDialog(tester, startSyncTitle);
    await _escape(tester);
    expect(dismissed.closed, isTrue);
    expect(find.text(startSyncTitle), findsNothing);

    final _Opened<bool> start = await _open<bool>(
      tester,
      mac,
      const StartSyncFlow(),
    );
    await _continueToPhrase(tester);
    _expectMacDialog(tester, recoveryPhraseTitle);
    _expectWordColumns(tester, 3);
    final Map<int, String> words = _readWords(tester);
    await _escape(tester);
    expect(start.closed, isFalse);
    await tester.tap(find.byKey(writtenDownKey));
    await tester.pumpAndSettle();
    _expectMacDialog(tester, checkPhraseTitle);
    await _confirmWords(tester, words);
    expect(start.closed, isTrue);
    expect(start.result, isTrue);

    final _Opened<bool> restore = await _open<bool>(
      tester,
      mac,
      const RestoreFlow(),
    );
    _expectMacDialog(tester, restoreTitle);
    await _escape(tester);
    expect(restore.closed, isTrue);
    expect(find.text(restoreTitle), findsNothing);
  } finally {
    await tester.runAsync(database.close);
  }
}

void main() {
  testWidgets('start syncing and restore fill the phone', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _provePhone(tester);
    await _proveMac(tester);
    semantics.dispose();
  });

  testWidgets('recovery phrase fields never let the keyboard keep the words', (
    WidgetTester tester,
  ) async {
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.macOS,
    ]) {
      final AppDatabase database = AppDatabase(NativeDatabase.memory());
      try {
        final _Host restore = await _pumpHost(
          tester,
          platform: platform,
          overrides: _overrides(database, 11),
        );
        await _open<bool>(tester, restore, const RestoreFlow());
        _expectPrivateKeyboard(tester, restoreWordsLabel);

        final _Host start = await _pumpHost(
          tester,
          platform: platform,
          overrides: _overrides(database, 11),
        );
        await _open<bool>(tester, start, const StartSyncFlow());
        await _continueToPhrase(tester);
        await tester.tap(find.byKey(writtenDownKey));
        await tester.pumpAndSettle();
        final List<int> asked = _askedPositions();
        expect(asked, hasLength(2), reason: '$platform');
        for (final int position in asked) {
          _expectPrivateKeyboard(tester, recoveryCheckLabel(position));
        }
      } finally {
        await tester.runAsync(database.close);
      }
    }
  });

  testWidgets('the phone scrim fades in place while the sheet slides up', (
    WidgetTester tester,
  ) async {
    final _Host sheet = await _pumpHost(
      tester,
      platform: TargetPlatform.android,
      overrides: syncOffOverrides(),
    );
    _openUnsettled(sheet, const BackgroundUploadsSheet());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final Rect rising = tester.getRect(find.byType(PhoneSheet));
    expect(tester.getRect(_scrim()), Offset.zero & _phone);
    expect(_scrimOpacity(tester), allOf(greaterThan(0), lessThan(1)));
    expect(rising.bottom, greaterThan(_phone.height));

    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getRect(_scrim()), Offset.zero & _phone);
    expect(tester.getRect(find.byType(PhoneSheet)).top, lessThan(rising.top));

    await tester.pumpAndSettle();
    expect(tester.getRect(_scrim()), Offset.zero & _phone);
    expect(_scrimOpacity(tester), 1);
    expect(tester.getRect(find.byType(PhoneSheet)).bottom, _phone.height);

    final _Host page = await _pumpHost(
      tester,
      platform: TargetPlatform.android,
      overrides: syncOffOverrides(),
    );
    _openUnsettled(page, const RestoreFlow());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final double risingTitle = tester.getTopLeft(find.text(restoreTitle)).dy;
    await tester.pumpAndSettle();
    expect(
      risingTitle,
      greaterThan(tester.getTopLeft(find.text(restoreTitle)).dy),
    );

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final _Host still = await _pumpHost(
      tester,
      platform: TargetPlatform.android,
      overrides: syncOffOverrides(),
    );
    _openUnsettled(still, const BackgroundUploadsSheet());
    await tester.pump();
    expect(tester.getRect(_scrim()), Offset.zero & _phone);
    expect(_scrimOpacity(tester), 1);
    expect(tester.getRect(find.byType(PhoneSheet)).bottom, _phone.height);
  });

  testWidgets('small flows stay small', (WidgetTester tester) async {
    final _Host phone = await _pumpHost(
      tester,
      platform: TargetPlatform.android,
      overrides: syncOffOverrides(),
    );
    final _Opened<bool> battery = await _open<bool>(
      tester,
      phone,
      const BackgroundUploadsSheet(),
    );
    _expectPhoneSheet(tester, backgroundUploadsTitle);
    await tester.tapAt(_aboveSheet);
    await tester.pumpAndSettle();
    expect(battery.closed, isTrue);
    expect(find.text(backgroundUploadsTitle), findsNothing);

    final _Opened<void> change = await _open<void>(
      tester,
      phone,
      const ChangeServerAddressFlow(),
    );
    _expectPhoneSheet(tester, changeAddressTitle);
    await tester.tap(find.text(syncCancelLabel));
    await tester.pumpAndSettle();
    expect(change.closed, isTrue);

    final _Host mac = await _pumpHost(
      tester,
      platform: TargetPlatform.macOS,
      overrides: syncOffOverrides(),
    );
    final _Opened<bool> macBattery = await _open<bool>(
      tester,
      mac,
      const BackgroundUploadsSheet(),
    );
    _expectMacDialog(tester, backgroundUploadsTitle);
    await _escape(tester);
    expect(macBattery.closed, isTrue);
    expect(find.text(backgroundUploadsTitle), findsNothing);

    final _Opened<void> macChange = await _open<void>(
      tester,
      mac,
      const ChangeServerAddressFlow(),
    );
    _expectMacDialog(tester, changeAddressTitle);
    await _escape(tester);
    expect(macChange.closed, isTrue);
    expect(find.text(changeAddressTitle), findsNothing);

    final _Opened<void> tapped = await _open<void>(
      tester,
      mac,
      const ChangeServerAddressFlow(),
    );
    await tester.tapAt(_macCorner);
    await tester.pumpAndSettle();
    expect(tapped.closed, isTrue);
  });

  testWidgets('restore hides Close while the journal is being restored', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final Completer<http.Response> relay = Completer<http.Response>();
    final RestoreService pending = RestoreService(
      database: database,
      keyStore: KeyStore(MemorySecureValues()),
      clientFor: (Uri baseUrl, DeviceKeys? device) => RelayClient(
        baseUrl: baseUrl,
        device: device,
        client: MockClient((http.Request request) => relay.future),
      ),
      deviceName: () async => 'Test device',
    );
    final _Host host = await _pumpHost(
      tester,
      platform: TargetPlatform.android,
      overrides: <Override>[
        for (final Override override in _overrides(database, 11))
          if (override.origin != restoreServiceProvider) override,
        restoreServiceProvider.overrideWithValue(pending),
      ],
    );
    await _open<bool>(tester, host, const RestoreFlow());
    expect(find.byKey(syncFlowPageCloseKey), findsOneWidget);

    await tester.enterText(
      _fieldLabelled(serverAddressLabel),
      'https://sync.example.com',
    );
    await tester.enterText(
      _fieldLabelled(restoreWordsLabel),
      encodeRecoveryPhrase(Uint8List.fromList(List<int>.filled(16, 7))),
    );
    await tester.tap(find.byKey(restoreConfirmKey));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(syncFlowPageCloseKey), findsNothing);

    relay.complete(http.Response('', 404));
    await tester.pumpAndSettle();
    expect(find.byKey(syncFlowPageCloseKey), findsOneWidget);
  });
}
