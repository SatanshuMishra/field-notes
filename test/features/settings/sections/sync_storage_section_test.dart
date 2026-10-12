import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/sync/ui/device_list.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';
import '../support/fake_settings_repository.dart';
import '../support/settings_harness.dart';

const String _address = 'https://sync.example.com';

const List<String> _mockUpControls = <String>[
  'Storage mode',
  'Server URL',
  'Access token',
  'Sync frequency',
  'Recovery passphrase',
  'Pair a device',
  'Connection',
  'Not connected',
  'Test connection',
];

const Size _smallDesktop = Size(1140, 726);
const Size _largeDesktop = Size(1440, 900);
const Size _phoneView = Size(384, 832);
const FakeViewPadding _phoneBars = FakeViewPadding(top: 34, bottom: 24);

const String _macIntro =
    'Your journal is stored only on this Mac. Turn on sync to keep it on your '
    'other devices too. Everything is encrypted before it leaves this Mac.';
const String _pcIntro =
    'Your journal is stored only on this PC. Turn on sync to keep it on your '
    'other devices too. Everything is encrypted before it leaves this PC.';
const String _phoneIntro =
    'Your journal is only on this phone. Sync keeps it on your other devices, '
    'encrypted.';
const String _macMediaCaption =
    'Download every photo, voice note and video in the background. On for '
    'Macs.';
const String _pcMediaCaption =
    'Download every photo, voice note and video in the background. On for '
    'PCs.';
const String _pauseCaption =
    'Stops sending and receiving until you switch it back';

final TargetPlatformVariant _macOS = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

final TargetPlatformVariant _android = TargetPlatformVariant.only(
  TargetPlatform.android,
);

final TargetPlatformVariant _bothPlatforms = TargetPlatformVariant(
  <TargetPlatform>{TargetPlatform.macOS, TargetPlatform.android},
);

bool get _onPhone => defaultTargetPlatform == TargetPlatform.android;

List<JournalDevice> _twoDevices(DateTime now) => <JournalDevice>[
  JournalDevice(
    deviceId: 'this-device',
    name: 'Satanshu MacBook',
    createdAt: now.subtract(const Duration(days: 30)),
    lastSeenAt: now,
    isThisDevice: true,
  ),
  JournalDevice(
    deviceId: 'phone-device',
    name: 'Galaxy S24 Ultra',
    createdAt: now.subtract(const Duration(days: 20)),
    lastSeenAt: now.subtract(const Duration(hours: 3)),
    isThisDevice: false,
  ),
];

Future<void> _pumpSection(
  WidgetTester tester,
  List<Override> sync, {
  AppSettings settings = AppSettings.defaults,
  VoidCallback? onManageDevices,
}) async {
  tester.view.physicalSize = _onPhone
      ? const Size(412, 1800)
      : const Size(1400, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    settingsFeatureHarness(
      SyncStorageSection(
        settings: settings,
        onFeedback: (String _) {},
        onManageDevices: onManageDevices,
      ),
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        ...sync,
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpOn(
  WidgetTester tester,
  TargetPlatform platform,
  List<Override> sync, {
  Size window = _largeDesktop,
  VoidCallback? onManageDevices,
}) async {
  final bool phone = platform == TargetPlatform.android;
  final FakeViewPadding bars = phone ? _phoneBars : FakeViewPadding.zero;
  tester.view.physicalSize = phone ? _phoneView : window;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = bars;
  tester.view.viewPadding = bars;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        ...sync,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SyncStorageSection(
              settings: AppSettings.defaults,
              onFeedback: (String _) {},
              onManageDevices: onManageDevices,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _rowOf(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(SettingsFieldRow),
);

Finder _rowControl(String label, Finder control) =>
    find.descendant(of: _rowOf(label), matching: control);

Finder _button(String label) => find.widgetWithText(StickerButton, label);

Finder _action(String label) =>
    find.widgetWithText(SettingsActionButton, label);

final Finder _statusDot = find.byWidgetPredicate(
  (Widget widget) =>
      widget is DecoratedBox &&
      widget.decoration is BoxDecoration &&
      (widget.decoration as BoxDecoration).shape == BoxShape.circle,
  description: 'the status dot',
);

SettingsSection _section(WidgetTester tester) =>
    tester.widget<SettingsSection>(find.byType(SettingsSection));

List<String> _groupLabels(WidgetTester tester) => <String>[
  for (final SettingsGroup group in _section(tester).groups) group.label,
];

void _expectTopToBottom(
  WidgetTester tester,
  List<String> texts,
  String reason,
) {
  double previous = double.negativeInfinity;
  for (final String text in texts) {
    final Finder found = find.text(text);
    expect(found, findsOneWidget, reason: '$reason: $text');
    final double top = tester.getTopLeft(found).dy;
    expect(
      top,
      greaterThan(previous),
      reason: '$reason: $text is out of order',
    );
    previous = top;
  }
}

void _expectGroupLabelsDrawn(WidgetTester tester, String reason) {
  for (final String label in _groupLabels(tester)) {
    final Finder text = find.text(label);
    expect(text, findsOneWidget, reason: '$reason: $label');
    expect(
      tester.widget<Text>(text).style?.fontFamily,
      TypographyTokens.accent,
      reason: '$reason: $label',
    );
  }
}

void _expectStatusRow(
  WidgetTester tester, {
  required String label,
  required String? description,
  required Color tone,
  required bool syncNow,
  required String reason,
}) {
  final Finder row = _rowOf(label);
  expect(row, findsOneWidget, reason: reason);
  final SettingsFieldRow field = tester.widget<SettingsFieldRow>(row);
  expect(field.description, description, reason: reason);
  expect(field.leading, isNotNull, reason: reason);
  final Finder dot = find.descendant(of: row, matching: _statusDot);
  expect(dot, findsOneWidget, reason: reason);
  expect(tester.getSize(dot), const Size(8, 8), reason: reason);
  final BoxDecoration paint =
      tester.widget<DecoratedBox>(dot).decoration as BoxDecoration;
  expect(paint.color?.toARGB32(), tone.toARGB32(), reason: reason);
  expect(
    tester.getRect(dot).right,
    lessThan(tester.getRect(find.text(label)).left),
    reason: reason,
  );
  expect(
    _rowControl(label, _action(syncNowLabel)),
    syncNow ? findsOneWidget : findsNothing,
    reason: reason,
  );
  if (!syncNow) {
    expect(find.text(syncNowLabel), findsNothing, reason: reason);
  }
  expect(find.byType(SettingsStatusPill), findsNothing, reason: reason);
}

void _expectManageDevices(
  WidgetTester tester,
  String description,
  String reason,
) {
  final Finder row = _rowOf('Manage devices');
  expect(row, findsOneWidget, reason: reason);
  final SettingsFieldRow field = tester.widget<SettingsFieldRow>(row);
  expect(field.description, description, reason: reason);
  expect(field.onPressed, isNotNull, reason: reason);
  final Finder chevron = find.descendant(
    of: row,
    matching: find.byType(ChevronGlyph),
  );
  expect(chevron, findsOneWidget, reason: reason);
  final ChevronGlyph glyph = tester.widget<ChevronGlyph>(chevron);
  expect(glyph.pointsBack, isFalse, reason: reason);
  expect(
    glyph.color.toARGB32(),
    FieldNotesColors.light.muted.toARGB32(),
    reason: reason,
  );
}

void _expectNoInlineDevices(WidgetTester tester, String reason) {
  expect(find.byType(DeviceList), findsNothing, reason: reason);
  expect(find.text('Your devices'), findsNothing, reason: reason);
  expect(find.text('Satanshu MacBook'), findsNothing, reason: reason);
  expect(find.text('Galaxy S24 Ultra'), findsNothing, reason: reason);
  expect(find.text('Status'), findsNothing, reason: reason);
  expect(find.text('Sync & storage'), findsNothing, reason: reason);
}

int _sectionDividers(WidgetTester tester) => find
    .descendant(
      of: find.byType(SyncStorageSection),
      matching: find.byType(DashedDivider),
    )
    .evaluate()
    .length;

void _expectOnlyUsableControls(WidgetTester tester) {
  for (final StickerButton button in tester.widgetList<StickerButton>(
    find.byType(StickerButton),
  )) {
    expect(button.onPressed, isNotNull, reason: button.label);
  }
  for (final SettingsToggle toggle in tester.widgetList<SettingsToggle>(
    find.byType(SettingsToggle),
  )) {
    expect(toggle.enabled, isTrue, reason: toggle.semanticLabel);
  }
}

void _expectNoMockUpControls() {
  for (final String control in _mockUpControls) {
    expect(
      find.text(control, skipOffstage: false),
      findsNothing,
      reason: control,
    );
  }
  expect(find.byType(SettingsTextField), findsNothing);
  expect(find.byType(SettingsSecretField), findsNothing);
  expect(find.bySubtype<SettingsSegmented<Object?>>(), findsNothing);
}

void main() {
  testWidgets('sync off offers start, join and restore', (
    WidgetTester tester,
  ) async {
    await _pumpSection(tester, syncOffOverrides());

    expect(find.text('Sync & storage'), findsNothing);
    expect(find.text(_onPhone ? _phoneIntro : _macIntro), findsOneWidget);
    final Map<String, String> captions = _onPhone
        ? <String, String>{
            'Start syncing': 'First device. Server address and invite code.',
            'Join my journal': 'Scan the code on your other device.',
            'Restore with recovery phrase': 'Use your 12 words.',
          }
        : <String, String>{
            'Start syncing':
                'First device. Needs your server address and an invite code.',
            'Join my journal': 'You already sync on another device. Type the 8 words it shows.',
            'Restore with recovery phrase':
                'You lost every device. Use your 12 words.',
          };
    for (final MapEntry<String, String> action in captions.entries) {
      final Finder row = find.widgetWithText(SyncActionRow, action.key);
      expect(row, findsOneWidget, reason: action.key);
      expect(
        find.descendant(of: row, matching: find.text(action.value)),
        findsOneWidget,
        reason: action.value,
      );
      expect(
        tester.getSize(row).height,
        greaterThanOrEqualTo(48),
        reason: action.key,
      );
    }
    _expectNoMockUpControls();
    _expectOnlyUsableControls(tester);
    expect(find.text('Sync now'), findsNothing);
    expect(find.text('Pause sync'), findsNothing);

    await tester.tap(find.text('Start syncing'));
    await tester.pumpAndSettle();

    expect(find.text(startSyncMessage), findsOneWidget);
    expect(find.text(serverAddressLabel), findsOneWidget);
    expect(find.text(inviteCodeLabel), findsOneWidget);
    expect(find.text(syncCancelLabel), findsOneWidget);
    expect(find.text(syncContinueLabel), findsOneWidget);
  }, variant: _bothPlatforms);

  testWidgets('sync on shows every control on the Mac', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now().toUtc();
    final SyncedStatus status = SyncedStatus(now);
    await _pumpSection(
      tester,
      syncOnOverrides(status: status, devices: _twoDevices(now)),
    );

    expect(find.text(status.label(now)), findsOneWidget);
    expect(find.text('Last change sent just now'), findsOneWidget);
    expect(_rowControl(status.label(now), _action('Sync now')), findsOneWidget);
    expect(find.text('Pause sync'), findsOneWidget);
    expect(find.text(_pauseCaption), findsOneWidget);
    expect(
      _rowControl('Pause sync', find.byType(SettingsToggle)),
      findsOneWidget,
    );
    expect(find.text('Server address'), findsOneWidget);
    expect(find.text(_address), findsOneWidget);
    expect(_rowControl('Server address', _action('Change')), findsOneWidget);
    expect(find.text('Add a device'), findsOneWidget);
    expect(find.text('Show a code to scan'), findsOneWidget);
    expect(_rowControl('Add a device', _action('Show code')), findsOneWidget);
    expect(find.text('Manage devices'), findsOneWidget);
    expect(find.text('2 devices · add or remove'), findsOneWidget);
    expect(find.text('Delete journal everywhere'), findsNothing);
    _expectNoInlineDevices(tester, 'the Mac');
    expect(find.text('Keep all media on this device'), findsOneWidget);
    expect(find.text(_macMediaCaption), findsOneWidget);
    expect(
      _rowControl('Keep all media on this device', find.byType(SettingsToggle)),
      findsOneWidget,
    );
    expect(find.text('Allow mobile data for media'), findsNothing);
    expect(find.text('Background uploads'), findsNothing);
    expect(find.text('Start syncing'), findsNothing);
    _expectNoMockUpControls();
  }, variant: _macOS);

  testWidgets('sync on shows every control on the phone', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now().toUtc();
    final SyncedStatus status = SyncedStatus(now);
    int manages = 0;
    await _pumpSection(
      tester,
      syncOnOverrides(status: status, devices: _twoDevices(now)),
      onManageDevices: () => manages++,
    );

    expect(find.text(status.label(now)), findsOneWidget);
    expect(find.text(_address), findsNWidgets(2));
    expect(_button('Sync now'), findsOneWidget);
    expect(
      _rowControl('Pause sync', find.byType(SettingsToggle)),
      findsOneWidget,
    );
    expect(
      _rowControl('Keep all media on this phone', find.byType(SettingsToggle)),
      findsOneWidget,
    );
    expect(
      find.text('Off: videos download when you open them'),
      findsOneWidget,
    );
    expect(
      _rowControl('Allow mobile data for media', find.byType(SettingsToggle)),
      findsOneWidget,
    );
    expect(find.text('Off: full videos move on Wi-Fi only'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('2 devices · add or remove'), findsOneWidget);
    expect(_rowControl('Server address', _button('Change')), findsOneWidget);
    expect(find.text('Background uploads'), findsOneWidget);
    expect(find.text('Keep all media on this device'), findsNothing);
    expect(find.text('Your devices'), findsNothing);
    expect(find.text('Satanshu MacBook'), findsNothing);
    _expectNoMockUpControls();
    _expectOnlyUsableControls(tester);

    await tester.tap(_rowControl('Devices', find.byType(StickerButton)));
    await tester.pumpAndSettle();

    expect(manages, 1);
    expect(find.byType(PhoneSheet), findsNothing);
  }, variant: _android);

  testWidgets('paused sync shows only the controls that still work', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now().toUtc();
    await _pumpSection(
      tester,
      syncOnOverrides(status: const PausedStatus(), devices: _twoDevices(now)),
      onManageDevices: _onPhone ? () {} : null,
    );

    expect(find.text('Sync paused'), findsOneWidget);
    expect(find.text(syncNowLabel), findsNothing);
    final Finder pause = _rowControl(
      pauseSyncLabel,
      find.byType(SettingsToggle),
    );
    expect(pause, findsOneWidget);
    expect(tester.widget<SettingsToggle>(pause).value, isTrue);
    expect(_rowControl('Server address', _action('Change')), findsOneWidget);
    _expectOnlyUsableControls(tester);
  }, variant: _bothPlatforms);

  testWidgets(
    'desktop sync rows sit in sync, server and devices, and media groups',
    (WidgetTester tester) async {
      final DateTime now = DateTime.now().toUtc();
      final FieldNotesColors colors = FieldNotesColors.light;

      await _pumpOn(
        tester,
        TargetPlatform.macOS,
        syncOffOverrides(),
        window: _smallDesktop,
      );
      expect(_section(tester).title, isNull, reason: 'Mac, sync off');
      expect(_groupLabels(tester), <String>['turn on sync']);
      _expectGroupLabelsDrawn(tester, 'Mac, sync off');
      _expectTopToBottom(tester, <String>[
        'turn on sync',
        _macIntro,
        'Start syncing',
        'First device. Needs your server address and an invite code.',
        'Join my journal',
        'You already sync on another device. Type the 8 words it shows.',
        'Restore with recovery phrase',
        'You lost every device. Use your 12 words.',
      ], 'Mac, sync off');
      final TextStyle? intro = tester.widget<Text>(find.text(_macIntro)).style;
      expect(intro?.fontFamily, TypographyTokens.captionSans.fontFamily);
      expect(intro?.fontSize, TypographyTokens.captionSans.fontSize);
      expect(find.byType(SyncActionRow), findsNWidgets(3));
      expect(find.text('Sync & storage'), findsNothing);
      expect(find.text('Sync now'), findsNothing);

      final SyncedStatus synced = SyncedStatus(now);
      await _pumpOn(
        tester,
        TargetPlatform.macOS,
        syncOnOverrides(status: synced, devices: _twoDevices(now)),
        window: _smallDesktop,
      );
      expect(_section(tester).title, isNull, reason: 'Mac, synced');
      expect(_groupLabels(tester), <String>[
        'sync',
        'server & devices',
        'media',
      ]);
      _expectGroupLabelsDrawn(tester, 'Mac, synced');
      _expectTopToBottom(tester, <String>[
        'sync',
        synced.label(now),
        'Last change sent just now',
        'Pause sync',
        _pauseCaption,
        'server & devices',
        'Server address',
        _address,
        'Add a device',
        'Show a code to scan',
        'Manage devices',
        '2 devices · add or remove',
        'media',
        'Keep all media on this device',
        _macMediaCaption,
      ], 'Mac, synced');
      _expectStatusRow(
        tester,
        label: synced.label(now),
        description: 'Last change sent just now',
        tone: colors.sage,
        syncNow: true,
        reason: 'Mac, synced',
      );
      expect(
        _rowControl('Pause sync', find.byType(SettingsToggle)),
        findsOneWidget,
      );
      expect(_rowControl('Server address', _action('Change')), findsOneWidget);
      expect(_rowControl('Add a device', _action('Show code')), findsOneWidget);
      _expectManageDevices(tester, '2 devices · add or remove', 'Mac, synced');
      expect(
        _rowControl(
          'Keep all media on this device',
          find.byType(SettingsToggle),
        ),
        findsOneWidget,
      );
      _expectNoInlineDevices(tester, 'Mac, synced');
      expect(
        find.text('Every device follows when you change it'),
        findsNothing,
      );

      await _pumpOn(
        tester,
        TargetPlatform.macOS,
        syncOnOverrides(
          status: const PausedStatus(),
          devices: _twoDevices(now).take(1).toList(),
        ),
        window: _smallDesktop,
      );
      _expectTopToBottom(tester, <String>[
        'sync',
        'Sync paused',
        'Pause sync',
        'server & devices',
        'Manage devices',
        'media',
      ], 'Mac, paused');
      _expectStatusRow(
        tester,
        label: 'Sync paused',
        description: null,
        tone: colors.muted,
        syncNow: false,
        reason: 'Mac, paused',
      );
      _expectManageDevices(tester, '1 device · add or remove', 'Mac, paused');
      _expectNoInlineDevices(tester, 'Mac, paused');

      await _pumpOn(tester, TargetPlatform.windows, syncOffOverrides());
      expect(_groupLabels(tester), <String>['turn on sync']);
      _expectTopToBottom(tester, <String>[
        'turn on sync',
        _pcIntro,
        'Start syncing',
        'Join my journal',
        'Restore with recovery phrase',
      ], 'Windows, sync off');
      expect(find.text(_macIntro), findsNothing);

      const AttentionStatus unreachable = AttentionStatus(
        AttentionReason.unreachable,
      );
      await _pumpOn(
        tester,
        TargetPlatform.windows,
        syncOnOverrides(status: unreachable, devices: _twoDevices(now)),
      );
      expect(_groupLabels(tester), <String>[
        'sync',
        'server & devices',
        'media',
      ]);
      _expectGroupLabelsDrawn(tester, 'Windows, attention');
      _expectTopToBottom(tester, <String>[
        'sync',
        unreachable.label(now),
        unreachable.fix!,
        'Pause sync',
        'server & devices',
        'Server address',
        'Add a device',
        'Manage devices',
        'media',
        'Keep all media on this device',
        _pcMediaCaption,
      ], 'Windows, attention');
      _expectStatusRow(
        tester,
        label: unreachable.label(now),
        description: null,
        tone: colors.dangerInk,
        syncNow: true,
        reason: 'Windows, attention',
      );
      _expectManageDevices(
        tester,
        '2 devices · add or remove',
        'Windows, attention',
      );
      _expectNoInlineDevices(tester, 'Windows, attention');
      expect(find.text(_macMediaCaption), findsNothing);

      await _pumpOn(tester, TargetPlatform.android, syncOffOverrides());
      expect(_section(tester).title, isNull, reason: 'phone, sync off');
      expect(_section(tester).groups, hasLength(1));
      expect(find.text('Sync & storage'), findsNothing);
      expect(find.text('turn on sync'), findsNothing);
      _expectTopToBottom(tester, <String>[
        _phoneIntro,
        'Start syncing',
        'First device. Server address and invite code.',
        'Join my journal',
        'Scan the code on your other device.',
        'Restore with recovery phrase',
        'Use your 12 words.',
      ], 'phone, sync off');
      expect(_sectionDividers(tester), 3);

      int manages = 0;
      await _pumpOn(
        tester,
        TargetPlatform.android,
        syncOnOverrides(status: synced, devices: _twoDevices(now)),
        onManageDevices: () => manages++,
      );
      expect(_section(tester).title, isNull, reason: 'phone, synced');
      expect(_section(tester).groups, hasLength(1));
      expect(find.text('Sync & storage'), findsNothing);
      for (final String label in <String>[
        'sync',
        'server & devices',
        'media',
        'Manage devices',
      ]) {
        expect(find.text(label), findsNothing, reason: 'phone: $label');
      }
      _expectTopToBottom(tester, <String>[
        synced.label(now),
        'Pause sync',
        'Keep all media on this phone',
        'Allow mobile data for media',
        'Devices',
        'Server address',
        'Background uploads',
      ], 'phone, synced');
      expect(find.byType(SettingsStatusPill), findsOneWidget);
      expect(find.text(_address), findsNWidgets(2));
      expect(_button('Sync now'), findsOneWidget);
      expect(_rowControl('Devices', _button('Manage')), findsOneWidget);
      expect(_rowControl('Server address', _button('Change')), findsOneWidget);
      expect(find.text('2 devices · add or remove'), findsOneWidget);
      expect(find.byType(DeviceList), findsNothing);
      expect(find.byType(ChevronGlyph), findsNothing);
      expect(_sectionDividers(tester), 6);

      await tester.tap(_rowControl('Devices', _button('Manage')));
      await tester.pumpAndSettle();
      expect(manages, 1);
    },
  );

  testWidgets('background uploads shows the battery state', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now().toUtc();
    final FakeBatterySettings battery = FakeBatterySettings();
    await _pumpSection(
      tester,
      syncOnOverrides(
        status: SyncedStatus(now),
        devices: _twoDevices(now),
        battery: battery,
      ),
    );

    expect(find.text('Background uploads'), findsOneWidget);
    expect(find.text('Battery: Optimised'), findsOneWidget);
    expect(find.text('Battery: Unrestricted'), findsNothing);
    final Finder open = _rowControl(
      'Background uploads',
      _button(openBatterySettingsLabel),
    );
    expect(open, findsOneWidget);

    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.text(backgroundUploadsTitle), findsOneWidget);
    expect(find.text(backgroundUploadsMessage), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(PhoneSheet),
        matching: find.text(openBatterySettingsLabel),
      ),
    );
    await tester.pumpAndSettle();
    expect(battery.opens, 1);
    expect(find.text(backgroundUploadsTitle), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _pumpSection(
      tester,
      syncOnOverrides(
        status: SyncedStatus(now),
        devices: _twoDevices(now),
        battery: FakeBatterySettings(exempt: true),
      ),
    );

    expect(find.text('Background uploads'), findsOneWidget);
    expect(find.text('Battery: Unrestricted'), findsOneWidget);
    expect(find.text('Battery: Optimised'), findsNothing);
    expect(_button(openBatterySettingsLabel), findsNothing);
  }, variant: _android);
}
