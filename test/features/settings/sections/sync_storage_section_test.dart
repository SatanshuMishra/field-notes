import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/settings/sync/pairing_qr_placeholder.dart';
import 'package:field_notes/features/settings/sync/sync_shell_options.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/settings_harness.dart';

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
  testWidgets('renders every sync field at full fidelity',
      (WidgetTester tester) async {
    await _pumpSection(tester);

    expect(find.text('Sync & storage'), findsOneWidget);
    expect(find.text('Syncing arrives in a future update'), findsOneWidget);
    expect(find.text('Storage mode'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Access token'), findsOneWidget);
    expect(find.text('Sync frequency'), findsOneWidget);
    expect(find.text('Recovery passphrase'), findsOneWidget);
    expect(find.text('Pair a device'), findsOneWidget);
    expect(find.text('Connection'), findsOneWidget);
    expect(find.byType(PairingQrPlaceholder), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
    expect(
      find.text(
        'Entries are stored only on this device. Nothing is uploaded '
        'and there is no syncing across devices.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('locks storage mode to On this device',
      (WidgetTester tester) async {
    await _pumpSection(tester);

    final SettingsSegmented<SyncStorageChoice> segmented =
        tester.widget<SettingsSegmented<SyncStorageChoice>>(
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
  });

  testWidgets('leaves every sync control inert', (WidgetTester tester) async {
    await _pumpSection(tester);

    for (final SettingsTextField field
        in tester.widgetList<SettingsTextField>(
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

    final SettingsSelect<SyncFrequency> select =
        tester.widget<SettingsSelect<SyncFrequency>>(
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
  });
}
