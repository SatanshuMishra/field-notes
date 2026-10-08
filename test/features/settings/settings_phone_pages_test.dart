import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/device_names.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/widgets/settings_notice.dart';
import 'package:field_notes/features/settings/widgets/settings_phone_pages.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:field_notes/features/sync/ui/device_list.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../app/support/app_shell_harness.dart';
import '../../support/sync_overrides.dart';
import 'support/settings_harness.dart';

const Size _phone = Size(384, 832);
const double _statusBar = 34;
const double _gestureBar = 24;
const double _rowMinHeight = 68;
const double _rowLabelSize = 15;
const double _eyebrowSize = 15;
const double _titleSize = 30;
const double _pillHeight = 48;
const double _pillLeft = 12;
const double _pillLift = 86;
const double _tolerance = 0.01;

const Key _chipsKey = ValueKey<String>('settings-tab-chips');
const Key _gearKey = ValueKey<String>('gear-button');

const Map<SettingsTab, String> _labels = <SettingsTab, String>{
  SettingsTab.journal: 'Journal',
  SettingsTab.syncStorage: 'Sync & storage',
  SettingsTab.remindersSound: 'Reminders & sound',
  SettingsTab.data: 'Data',
};

const Map<SettingsTab, String> _syncOffSummaries = <SettingsTab, String>{
  SettingsTab.journal: 'Appearance, text size, calendar, spell check',
  SettingsTab.syncStorage: 'Only on this phone',
  SettingsTab.remindersSound: 'Daily nudge, reflection prompt, sound',
  SettingsTab.data: 'Export, reclaim space, delete',
};

const List<String> _journalRows = <String>[
  'Appearance',
  'Text size',
  'Week starts on',
  'Spell check',
  'Show the tour again',
];

final Finder _list = find.byType(SettingsSectionList);
final Finder _pill = find.byType(SettingsBackPill);
final Finder _heading = find.byType(SettingsPageHeading);
final Finder _content = find.byKey(settingsTabContentKey);

Finder _row(SettingsTab tab) => find.byKey(settingsTabKey(tab));

Finder _inside(Finder parent, Finder child) =>
    find.descendant(of: parent, matching: child);

List<JournalDevice> _devices(DateTime now, {required bool alone}) =>
    <JournalDevice>[
      JournalDevice(
        deviceId: 'field-phone',
        name: 'Field phone',
        createdAt: now.subtract(const Duration(days: 30)),
        lastSeenAt: now,
        isThisDevice: true,
      ),
      if (!alone)
        JournalDevice(
          deviceId: 'studio-mac',
          name: 'Studio Mac',
          createdAt: now.subtract(const Duration(days: 20)),
          lastSeenAt: now.subtract(const Duration(hours: 3)),
          isThisDevice: false,
        ),
    ];

List<Override> _overrides(List<Override> sync) {
  final Set<Object> replaced = <Object>{
    for (final Override override in sync) override.origin,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    ...sync,
    appSettingsProvider.overrideWith(
      (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
    ),
    settingsDataControllerProvider.overrideWith(
      (Ref ref) async => FakeSettingsDataController(),
    ),
  ];
}

Future<void> _pumpPhone(WidgetTester tester, {List<Override>? sync}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(sync ?? syncOffOverrides()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.android),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(_gearKey));
  await tester.pumpAndSettle();
}

ShellDestination _selected(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppShell)))
        .read(shellNavigationProvider);

Text _text(WidgetTester tester, Finder finder) => tester.widget<Text>(finder);

void _expectSummaries(WidgetTester tester, Map<SettingsTab, String> summaries) {
  for (final MapEntry<SettingsTab, String> entry in summaries.entries) {
    final Finder summary = _inside(_row(entry.key), find.text(entry.value));
    expect(summary, findsOneWidget, reason: entry.value);
    final Text text = _text(tester, summary);
    expect(text.maxLines, 1, reason: entry.value);
    expect(text.overflow, TextOverflow.ellipsis, reason: entry.value);
    expect(text.style?.fontFamily, TypographyTokens.sans, reason: entry.value);
  }
}

void _expectPageHeading(WidgetTester tester, String title) {
  expect(_heading, findsOneWidget, reason: title);
  final Finder eyebrow = _inside(_heading, find.text('settings'));
  final Finder name = _inside(_heading, find.text(title));
  expect(
    _text(tester, eyebrow).style?.fontFamily,
    TypographyTokens.accent,
    reason: title,
  );
  expect(_text(tester, eyebrow).style?.fontSize, _eyebrowSize);
  expect(_text(tester, name).style?.fontFamily, TypographyTokens.serif);
  expect(_text(tester, name).style?.fontSize, _titleSize);
  expect(
    tester.getRect(eyebrow).bottom,
    lessThanOrEqualTo(tester.getRect(name).top + _tolerance),
    reason: title,
  );
}

Rect _expectPill(WidgetTester tester, String label) {
  expect(_pill, findsOneWidget, reason: label);
  expect(_inside(_pill, find.text(label)), findsOneWidget, reason: label);
  expect(
    _inside(
      _pill,
      find.byWidgetPredicate(
        (Widget widget) => widget is ChevronGlyph && widget.pointsBack,
      ),
    ),
    findsOneWidget,
    reason: label,
  );
  final Finder glass = _inside(_pill, find.byType(GlassSurface));
  expect(tester.widget<GlassSurface>(glass).tone, GlassTone.paper);
  final Rect rect = tester.getRect(glass);
  expect(rect.height, moreOrLessEquals(_pillHeight, epsilon: _tolerance));
  expect(rect.left, moreOrLessEquals(_pillLeft, epsilon: _tolerance));
  expect(
    rect.bottom,
    moreOrLessEquals(
      _phone.height - _gestureBar - _pillLift,
      epsilon: _tolerance,
    ),
    reason: label,
  );
  expect(
    tester.getSemantics(_pill),
    isSemantics(label: 'Back to $label', isButton: true, hasTapAction: true),
  );
  return rect;
}

ScrollableState _scroll(WidgetTester tester) => tester.state<ScrollableState>(
  find.ancestor(of: _content, matching: find.byType(Scrollable)).first,
);

Future<void> _open(WidgetTester tester, SettingsTab tab) async {
  await tester.tap(_row(tab));
  await tester.pumpAndSettle();
}

Future<void> _manage(WidgetTester tester) async {
  final Finder manage = find.widgetWithText(StickerButton, manageLabel);
  await tester.ensureVisible(manage);
  await tester.pumpAndSettle();
  await tester.tap(manage);
  await tester.pumpAndSettle();
}

final class _HeldRelay {
  _HeldRelay({required this.now})
    : journal = JournalKeys.generate(),
      phone = DeviceKeys.generate(),
      mac = DeviceKeys.generate(),
      recoveryBox = DeviceKeys.generate().boxKeyPair.publicKey,
      keyStore = KeyStore(MemorySecureValues()),
      database = AppDatabase(NativeDatabase.memory()) {
    _listed = <DeviceInfo>[
      _info(phone, 'Field phone', now),
      _info(mac, 'Studio Mac', now.subtract(const Duration(hours: 3))),
    ];
  }

  final DateTime now;
  final JournalKeys journal;
  final DeviceKeys phone;
  final DeviceKeys mac;
  final Uint8List recoveryBox;
  final KeyStore keyStore;
  final AppDatabase database;
  final Completer<void> release = Completer<void>();
  late List<DeviceInfo> _listed;
  bool removalPending = false;

  Future<void> holdKeys() async {
    await keyStore.writeDeviceKeys(phone);
    await keyStore.writeJournalKeys(journal);
  }

  DeviceService service() => DeviceService(
    database: database,
    keyStore: keyStore,
    client: RelayClient(
      baseUrl: Uri.parse('https://sync.example.com'),
      device: phone,
      client: MockClient(_answer),
    ),
  );

  DeviceInfo _info(DeviceKeys device, String name, DateTime seen) => DeviceInfo(
    deviceId: device.deviceId,
    signPublicKey: device.signKeyPair.publicKey,
    boxPublicKey: device.boxKeyPair.publicKey,
    certificate: device.certifyWith(journal),
    encryptedName: sealDeviceName(name, device.deviceId, journal),
    createdAt: now.subtract(const Duration(days: 30)),
    lastSeenAt: seen,
  );

  bool _is(
    http.Request request,
    SyncRoute route, [
    Map<String, Object> parameters = const <String, Object>{},
  ]) =>
      request.method == route.method &&
      request.url.path == route.path(parameters);

  http.Response _json(SyncMessage message) => http.Response(
    jsonEncode(message.toJson()),
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );

  Future<http.Response> _answer(http.Request request) async {
    final DateTime later = DateTime.now().toUtc().add(const Duration(hours: 1));
    if (_is(request, SyncRoutes.sessionChallenge)) {
      return _json(
        ChallengeResponse(
          challengeId: 'challenge',
          nonce: 'nonce',
          expiresAt: later,
        ),
      );
    }
    if (_is(request, SyncRoutes.session)) {
      return _json(
        SessionResponse(
          token: 'session',
          expiresAt: later,
          currentEpoch: journal.currentEpoch,
          uploadPass: 'pass',
          uploadPassExpiresAt: later,
          generation: 'generation',
        ),
      );
    }
    if (_is(request, SyncRoutes.keys)) {
      return _json(
        EpochKeysResponse(
          currentEpoch: journal.currentEpoch,
          rotations: const <EpochRotation>[],
          recoveryBoxPublicKey: recoveryBox,
          recoveryBoxCertificate: certifyRecoveryKey(journal, recoveryBox),
          devices: _listed,
        ),
      );
    }
    if (_is(request, SyncRoutes.devices)) {
      return _json(DeviceListResponse(devices: _listed));
    }
    if (_is(request, SyncRoutes.removeDevice, <String, Object>{
      SyncRoutes.deviceIdParameter: mac.deviceId,
    })) {
      removalPending = true;
      await release.future;
      _listed = <DeviceInfo>[
        for (final DeviceInfo device in _listed)
          if (device.deviceId != mac.deviceId) device,
      ];
      removalPending = false;
      return http.Response('', 204);
    }
    return http.Response('', 404);
  }
}

void main() {
  testWidgets('the phone settings root lists every section with a summary', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpPhone(tester);

    expect(find.byKey(_chipsKey), findsNothing);
    expect(find.byKey(settingsTabRailKey), findsNothing);
    expect(_pill, findsNothing);
    expect(_list, findsOneWidget);

    final Text eyebrow = _text(tester, find.text('preferences'));
    expect(eyebrow.style?.fontFamily, TypographyTokens.accent);
    expect(eyebrow.style?.fontSize, _eyebrowSize);
    final Finder title = _inside(_list, find.text('Settings'));
    expect(_text(tester, title).style?.fontFamily, TypographyTokens.serif);
    expect(_text(tester, title).style?.fontSize, _titleSize);
    expect(tester.getSemantics(title), isSemantics(isHeader: true));
    expect(
      tester.getRect(find.text('preferences')).bottom,
      lessThanOrEqualTo(tester.getRect(title).top + _tolerance),
    );

    final Finder card = _inside(_list, find.byType(StickerCard));
    expect(card, findsOneWidget);
    final List<Rect> rules = <Rect>[
      for (final Element rule in _inside(
        card,
        find.byType(DashedDivider),
      ).evaluate())
        tester.getRect(find.byElementPredicate((Element e) => e == rule)),
    ];
    expect(rules, hasLength(SettingsTab.values.length - 1));
    Rect? previous;
    for (final SettingsTab tab in SettingsTab.values) {
      final String label = _labels[tab]!;
      final Finder row = _row(tab);
      expect(_inside(card, row), findsOneWidget, reason: label);
      final Rect rect = tester.getRect(row);
      expect(rect.height, greaterThanOrEqualTo(_rowMinHeight), reason: label);
      final Finder name = _inside(row, find.text(label));
      expect(_text(tester, name).style?.fontSize, _rowLabelSize);
      expect(_text(tester, name).style?.fontFamily, TypographyTokens.sans);
      final Finder chevron = _inside(row, find.byType(ChevronGlyph));
      expect(chevron, findsOneWidget, reason: label);
      expect(tester.widget<ChevronGlyph>(chevron).pointsBack, isFalse);
      expect(
        tester.getRect(chevron).left,
        greaterThan(tester.getRect(name).right),
        reason: label,
      );
      expect(
        tester.getSemantics(row),
        isSemantics(
          label: label,
          hint: _syncOffSummaries[tab],
          isButton: true,
          hasTapAction: true,
        ),
      );
      if (previous != null) {
        final Rect before = previous;
        expect(
          rules.where(
            (Rect rule) =>
                rule.top >= before.bottom - _tolerance &&
                rule.bottom <= rect.top + _tolerance,
          ),
          hasLength(1),
          reason: '$label is not separated by a dashed rule',
        );
      }
      previous = rect;
    }
    _expectSummaries(tester, _syncOffSummaries);
    semantics.dispose();

    final DateTime now = DateTime.now().toUtc();
    await _pumpPhone(tester, sync: syncOnOverrides(status: SyncedStatus(now)));
    _expectSummaries(tester, <SettingsTab, String>{
      SettingsTab.syncStorage: 'Synced · just now',
    });

    await _pumpPhone(
      tester,
      sync: syncOnOverrides(status: const PausedStatus()),
    );
    _expectSummaries(tester, <SettingsTab, String>{
      SettingsTab.syncStorage: 'Sync paused',
    });
  });

  testWidgets('a section opens as its own page with a glass Back pill', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpPhone(tester);
    final Rect tabBar = tester.getRect(find.byType(PhoneBottomBar));
    final Rect gear = tester.getRect(find.byKey(_gearKey));
    final Rect streak = tester.getRect(find.byType(StreakPill));

    await _open(tester, SettingsTab.journal);

    expect(_list, findsNothing);
    _expectPageHeading(tester, 'Journal');
    for (final String row in _journalRows) {
      expect(find.text(row), findsOneWidget, reason: row);
    }
    expect(_scroll(tester).position.pixels, 0);
    final Rect pill = _expectPill(tester, 'Settings');
    expect(tester.getRect(find.byType(PhoneBottomBar)), tabBar);
    expect(tester.getRect(find.byKey(_gearKey)), gear);
    expect(tester.getRect(find.byType(StreakPill)), streak);
    expect(pill.bottom, lessThan(tabBar.top));

    final ScrollableState scroll = _scroll(tester);
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    expect(
      tester.getRect(find.byType(SettingsFieldRow).last).bottom,
      lessThanOrEqualTo(pill.top),
    );
    expect(tester.getRect(_content).bottom, lessThanOrEqualTo(pill.top));

    await tester.tap(_pill);
    await tester.pumpAndSettle();

    expect(_list, findsOneWidget);
    expect(_pill, findsNothing);
    expect(_heading, findsNothing);

    await _open(tester, SettingsTab.data);
    _expectPageHeading(tester, 'Data');
    _expectPill(tester, 'Settings');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(_list, findsOneWidget);
    expect(_pill, findsNothing);
    expect(_selected(tester), ShellDestination.settings);
    expect(tester.getRect(find.byType(PhoneBottomBar)), tabBar);
    expect(tester.getRect(find.byKey(_gearKey)), gear);
    semantics.dispose();
  });

  testWidgets('Manage opens the Devices page', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final DateTime now = DateTime.now().toUtc();
    await _pumpPhone(
      tester,
      sync: syncOnOverrides(
        status: SyncedStatus(now),
        devices: _devices(now, alone: false),
      ),
    );
    await _open(tester, SettingsTab.syncStorage);
    _expectPageHeading(tester, 'Sync & storage');

    await _manage(tester);

    expect(find.byType(PhoneSheet), findsNothing);
    _expectPageHeading(tester, devicesTitle);
    expect(find.byType(DeviceList), findsOneWidget);
    expect(find.byType(SyncStorageSection), findsNothing);
    expect(find.text('Field phone'), findsOneWidget);
    expect(find.text('This phone'), findsOneWidget);
    expect(find.text('Studio Mac'), findsOneWidget);
    expect(find.text('Last seen 3 hours ago'), findsOneWidget);
    expect(
      find.widgetWithText(StickerButton, deviceRemoveLabel),
      findsNWidgets(2),
    );
    expect(find.byKey(deviceRemoveKey('studio-mac')), findsOneWidget);
    final Finder addDevice = find.widgetWithText(
      SettingsFieldRow,
      'Add a device',
    );
    expect(addDevice, findsOneWidget);
    expect(
      _inside(addDevice, find.widgetWithText(StickerButton, 'Show code')),
      findsOneWidget,
    );
    expect(
      tester.getRect(addDevice).top,
      greaterThan(tester.getRect(find.text('Studio Mac')).bottom),
    );
    _expectPill(tester, 'Sync & storage');

    await tester.tap(_pill);
    await tester.pumpAndSettle();

    _expectPageHeading(tester, 'Sync & storage');
    expect(find.byType(DeviceList), findsNothing);
    expect(find.widgetWithText(StickerButton, manageLabel), findsOneWidget);
    _expectPill(tester, 'Settings');

    await _manage(tester);
    _expectPageHeading(tester, devicesTitle);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    _expectPageHeading(tester, 'Sync & storage');
    _expectPill(tester, 'Settings');
    expect(_selected(tester), ShellDestination.settings);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(_list, findsOneWidget);
    semantics.dispose();

    await _pumpPhone(
      tester,
      sync: syncOnOverrides(
        status: SyncedStatus(now),
        devices: _devices(now, alone: true),
      ),
    );
    await _open(tester, SettingsTab.syncStorage);
    await _manage(tester);

    expect(find.text('Field phone'), findsOneWidget);
    expect(find.widgetWithText(StickerButton, deviceRemoveLabel), findsNothing);
    expect(
      find.widgetWithText(StickerButton, 'Delete journal everywhere'),
      findsOneWidget,
    );
  });

  testWidgets('leaving Devices while a removal is pending still refreshes it', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now().toUtc();
    final _HeldRelay relay = _HeldRelay(now: now);
    addTearDown(relay.database.close);
    await relay.holdKeys();
    final Set<Object> real = <Object>{
      deviceServiceProvider,
      journalDevicesProvider,
    };
    await _pumpPhone(
      tester,
      sync: <Override>[
        for (final Override override in syncOnOverrides(
          status: SyncedStatus(now),
        ))
          if (!real.contains(override.origin)) override,
        deviceServiceProvider.overrideWith((Ref ref) async => relay.service()),
        journalDevicesProvider.overrideWith(journalDevices),
      ],
    );
    await _open(tester, SettingsTab.syncStorage);
    expect(find.text(deviceCountLabel(2)), findsOneWidget);
    await _manage(tester);
    expect(find.text('Studio Mac'), findsOneWidget);

    await tester.tap(find.byKey(deviceRemoveKey(relay.mac.deviceId)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(confirmDialogConfirmKey));
    await tester.pumpAndSettle();
    expect(relay.removalPending, isTrue);

    await tester.tap(_pill);
    await tester.pumpAndSettle();
    _expectPageHeading(tester, 'Sync & storage');

    relay.release.complete();
    await tester.pumpAndSettle();

    expect(relay.removalPending, isFalse);
    expect(find.text(removeDeviceFailedMessage), findsNothing);
    expect(find.byType(SettingsNotice), findsNothing);
    expect(find.text(deviceCountLabel(1)), findsOneWidget);

    await _manage(tester);
    _expectPageHeading(tester, devicesTitle);
    expect(find.text('Field phone'), findsOneWidget);
    expect(find.text('Studio Mac'), findsNothing);
  });
}
