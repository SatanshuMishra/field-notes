import 'package:drift/native.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/pairing/pairing_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/sync/ui/add_device_sheet.dart';
import 'package:field_notes/features/sync/ui/device_list.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../support/sync_overrides.dart';
import '../support/fake_settings_repository.dart';

const Size _window = Size(1140, 726);
const String _manageDevices = 'Manage devices';
const String _dialogTitle = 'Devices';
const String _done = 'Done';
const String _addDevice = 'Add a device';
const String _otherDevice = 'galaxy';

final Uri _relay = Uri.parse('https://relay.example');

List<JournalDevice> _devices(DateTime now) => <JournalDevice>[
  JournalDevice(
    deviceId: 'studio-mac',
    name: 'Studio Mac',
    createdAt: now.subtract(const Duration(days: 30)),
    lastSeenAt: now,
    isThisDevice: true,
  ),
  JournalDevice(
    deviceId: _otherDevice,
    name: 'Galaxy S24 Ultra',
    createdAt: now.subtract(const Duration(days: 20)),
    lastSeenAt: now.subtract(const Duration(hours: 3)),
    isThisDevice: false,
  ),
];

Future<PairingService> _unreachablePairing(AppDatabase database) async {
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
    clientFor: (Uri baseUrl, DeviceKeys? device) => RelayClient(
      baseUrl: baseUrl,
      device: device,
      client: MockClient(
        (http.Request request) async => http.Response('', 503),
      ),
    ),
    deviceName: () async => 'Studio Mac',
  );
}

Future<void> _pumpSection(
  WidgetTester tester,
  List<JournalDevice> devices,
  PairingService pairing,
) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        for (final Override override in syncOnOverrides(
          status: SyncedStatus(DateTime.now().toUtc()),
          devices: devices,
        ))
          if (override.origin != pairingServiceProvider) override,
        pairingServiceProvider.overrideWithValue(pairing),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: SyncStorageSection(
              settings: AppSettings.defaults,
              onFeedback: (String _) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _manageRow() => find.ancestor(
  of: find.text(_manageDevices),
  matching: find.byType(SettingsFieldRow),
);

Finder _dialog() => find.ancestor(
  of: find.text(_dialogTitle),
  matching: find.byType(StickerCard),
);

Finder _inDialog(Finder finder) =>
    find.descendant(of: _dialog(), matching: finder);

Future<void> _openDialog(WidgetTester tester) async {
  await tester.ensureVisible(_manageRow());
  await tester.pumpAndSettle();
  await tester.tap(_manageRow());
  await tester.pumpAndSettle();
}

T? _focusedAncestor<T extends Widget>() => FocusManager
    .instance
    .primaryFocus
    ?.context
    ?.findAncestorWidgetOfExactType<T>();

void main() {
  testWidgets('Manage devices opens the devices dialog on desktop', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    try {
      final List<JournalDevice> devices = _devices(DateTime.now().toUtc());
      final PairingService pairing = await _unreachablePairing(database);
      await _pumpSection(tester, devices, pairing);

      expect(_manageRow(), findsOneWidget);
      expect(find.byType(DeviceList), findsNothing);
      expect(_dialog(), findsNothing);

      await _openDialog(tester);

      expect(_dialog(), findsOneWidget);
      final Rect card = tester.getRect(_dialog());
      expect(card.center.dx, moreOrLessEquals(_window.width / 2, epsilon: 1));
      expect(card.center.dy, moreOrLessEquals(_window.height / 2, epsilon: 1));
      expect(
        tester.widget<Text>(find.text(_dialogTitle)).style?.fontFamily,
        TypographyTokens.serif,
      );
      expect(_inDialog(find.byType(DeviceList)), findsOneWidget);
      for (final JournalDevice device in devices) {
        expect(
          _inDialog(find.text(device.name)),
          findsOneWidget,
          reason: device.name,
        );
        final Finder remove = _inDialog(
          find.byKey(deviceRemoveKey(device.deviceId)),
        );
        expect(remove, findsOneWidget, reason: device.name);
        expect(
          tester.widget<StickerButton>(remove).label,
          deviceRemoveLabel,
          reason: device.name,
        );
        expect(
          tester.widget<StickerButton>(remove).onPressed,
          isNotNull,
          reason: device.name,
        );
      }
      expect(_inDialog(find.text('This Mac')), findsOneWidget);
      expect(_inDialog(find.text('Last seen 3 hours ago')), findsOneWidget);
      expect(_focusedAncestor<StickerButton>()?.label, _done);

      await tester.tap(_inDialog(find.byKey(deviceRemoveKey(_otherDevice))));
      await tester.pumpAndSettle();
      expect(find.text(removeDevicePrompt('Galaxy S24 Ultra')), findsOneWidget);
      await tester.tap(find.byKey(confirmDialogCancelKey));
      await tester.pumpAndSettle();
      expect(find.text(removeDevicePrompt('Galaxy S24 Ultra')), findsNothing);
      expect(_dialog(), findsOneWidget);

      await tester.tap(_inDialog(find.widgetWithText(StickerButton, _done)));
      await tester.pumpAndSettle();
      expect(_dialog(), findsNothing);
      expect(find.byType(AddDeviceSheet), findsNothing);

      await _openDialog(tester);
      expect(_dialog(), findsOneWidget);
      await tester.tap(
        _inDialog(find.widgetWithText(StickerButton, _addDevice)),
      );
      await tester.pumpAndSettle();
      expect(_dialog(), findsNothing);
      final Finder sheet = find.byType(AddDeviceSheet);
      expect(sheet, findsOneWidget);
      await tester.tap(
        find.descendant(
          of: sheet,
          matching: find.widgetWithText(StickerButton, addDeviceDoneLabel),
        ),
      );
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);

      await _openDialog(tester);
      expect(_dialog(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_dialog(), findsNothing);
      expect(find.byType(AddDeviceSheet), findsNothing);
      expect(_focusedAncestor<SettingsFieldRow>()?.label, _manageDevices);
    } finally {
      await tester.runAsync(database.close);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
