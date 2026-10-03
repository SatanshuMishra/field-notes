import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/settings/sync/pairing_qr_placeholder.dart';
import 'package:field_notes/features/settings/sync/sync_shell_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/settings_harness.dart';

const String _onDeviceNote =
    'Entries are stored only on this device. Nothing is uploaded '
    'and there is no syncing across devices.';

const List<String> _serverRows = <String>[
  'Server URL',
  'Access token',
  'Sync frequency',
  'Recovery passphrase',
  'Pair a device',
  'Connection',
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

Future<void> _pumpSection(WidgetTester tester) async {
  useWideSurface(tester);
  await tester.pumpWidget(
    settingsFeatureHarness(
      const SyncStorageSection(storageMode: StorageMode.onDevice),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('macOS renders every sync field at full fidelity', (
    WidgetTester tester,
  ) async {
    await _pumpSection(tester);

    expect(find.text('Sync & storage'), findsOneWidget);
    expect(find.text('Syncing arrives in a future update'), findsOneWidget);
    expect(find.text('Storage mode'), findsOneWidget);
    for (final String row in _serverRows) {
      expect(find.text(row), findsOneWidget, reason: row);
    }
    expect(find.byType(PairingQrPlaceholder), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text(_onDeviceNote), findsOneWidget);
  }, variant: _macOS);

  testWidgets('the phone shows only the storage mode and the on-device note', (
    WidgetTester tester,
  ) async {
    await _pumpSection(tester);

    expect(find.text('Sync & storage'), findsOneWidget);
    expect(find.text('Syncing arrives in a future update'), findsOneWidget);
    expect(find.text('Storage mode'), findsOneWidget);
    expect(find.text(_onDeviceNote), findsOneWidget);
    for (final String row in _serverRows) {
      expect(find.text(row, skipOffstage: false), findsNothing, reason: row);
    }
    expect(find.byType(PairingQrPlaceholder), findsNothing);
    expect(find.byType(SettingsTextField), findsNothing);
    expect(find.byType(SettingsSecretField), findsNothing);
    expect(find.byType(DashedDivider), findsNWidgets(2));
  }, variant: _android);

  testWidgets('locks storage mode to On this device', (
    WidgetTester tester,
  ) async {
    await _pumpSection(tester);

    final SettingsSegmented<SyncStorageChoice> segmented = tester
        .widget<SettingsSegmented<SyncStorageChoice>>(
          find.byType(SettingsSegmented<SyncStorageChoice>),
        );

    expect(segmented.value, SyncStorageChoice.onDevice);
    expect(segmented.enabled, isFalse);
    expect(segmented.onChanged, isNull);

    await tester.tap(find.text('Sync to server'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SettingsSegmented<SyncStorageChoice>>(
            find.byType(SettingsSegmented<SyncStorageChoice>),
          )
          .value,
      SyncStorageChoice.onDevice,
    );
  }, variant: _bothPlatforms);

  testWidgets('macOS leaves every sync control inert', (
    WidgetTester tester,
  ) async {
    await _pumpSection(tester);

    expect(find.byType(SettingsTextField), findsNWidgets(3));
    expect(find.byType(SettingsSecretField), findsNWidgets(2));
    for (final SettingsTextField field in tester.widgetList<SettingsTextField>(
      find.byType(SettingsTextField),
    )) {
      expect(field.enabled, isFalse);
    }
    for (final SettingsSecretField field
        in tester.widgetList<SettingsSecretField>(
          find.byType(SettingsSecretField),
        )) {
      expect(field.enabled, isFalse);
    }

    final SettingsSelect<SyncFrequency> select = tester
        .widget<SettingsSelect<SyncFrequency>>(
          find.byType(SettingsSelect<SyncFrequency>),
        );
    expect(select.enabled, isFalse);
    expect(select.onChanged, isNull);

    await tester.tap(find.byType(SettingsSelect<SyncFrequency>));
    await tester.pumpAndSettle();
    expect(find.text('Manual'), findsNothing);

    final StickerButton testConnection = tester.widget<StickerButton>(
      find.widgetWithText(StickerButton, 'Test connection'),
    );
    expect(testConnection.onPressed, isNull);
  }, variant: _macOS);
}
