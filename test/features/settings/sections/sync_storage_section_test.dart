import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

Finder _rowControl(String label, Finder control) => find.descendant(
  of: find.ancestor(
    of: find.text(label),
    matching: find.byType(SettingsFieldRow),
  ),
  matching: control,
);

Finder _button(String label) => find.widgetWithText(StickerButton, label);

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

    expect(find.text('Sync & storage'), findsOneWidget);
    expect(
      find.text(
        _onPhone
            ? 'Your journal is only on this phone. Sync keeps it on your '
                  'other devices, encrypted.'
            : 'Your journal is stored only on this Mac. Turn on sync to keep '
                  'it on your other devices too. Everything is encrypted '
                  'before it leaves this Mac.',
      ),
      findsOneWidget,
    );
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

    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Last change sent just now'), findsOneWidget);
    expect(find.text(status.label(now)), findsOneWidget);
    expect(_button('Sync now'), findsOneWidget);
    expect(find.text('Pause sync'), findsOneWidget);
    expect(
      find.text('Stops sending and receiving until you switch it back'),
      findsOneWidget,
    );
    expect(
      _rowControl('Pause sync', find.byType(SettingsToggle)),
      findsOneWidget,
    );
    expect(find.text('Server address'), findsOneWidget);
    expect(
      find.text('Every device follows when you change it'),
      findsOneWidget,
    );
    expect(find.text(_address), findsOneWidget);
    expect(_rowControl('Server address', _button('Change')), findsOneWidget);
    expect(find.text('Your devices'), findsOneWidget);
    expect(find.text('Satanshu MacBook'), findsOneWidget);
    expect(find.text('This Mac'), findsOneWidget);
    expect(find.text('Galaxy S24 Ultra'), findsOneWidget);
    expect(find.text('Last seen 3 hours ago'), findsOneWidget);
    expect(_rowControl('Galaxy S24 Ultra', _button('Remove')), findsOneWidget);
    expect(find.text('Delete journal everywhere'), findsNothing);
    expect(find.text('Add a device'), findsOneWidget);
    expect(find.text('Show a code to scan'), findsOneWidget);
    expect(_rowControl('Add a device', _button('Show code')), findsOneWidget);
    expect(find.text('Keep all media on this device'), findsOneWidget);
    expect(
      find.text(
        'Download every photo, voice note and video in the background. '
        'On for Macs.',
      ),
      findsOneWidget,
    );
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
