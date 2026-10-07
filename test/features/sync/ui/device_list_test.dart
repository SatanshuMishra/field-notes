import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/settings/widgets/delete_all_dialog.dart';
import 'package:field_notes/features/sync/ui/device_list.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';

final TargetPlatformVariant _bothPlatforms = TargetPlatformVariant(
  <TargetPlatform>{TargetPlatform.macOS, TargetPlatform.android},
);

JournalDevice _device(
  String id,
  String name, {
  required bool thisDevice,
  Duration seen = Duration.zero,
}) {
  final DateTime now = DateTime.now().toUtc();
  return JournalDevice(
    deviceId: id,
    name: name,
    createdAt: now.subtract(const Duration(days: 9)),
    lastSeenAt: now.subtract(seen),
    isThisDevice: thisDevice,
  );
}

Future<void> _pumpList(WidgetTester tester, List<JournalDevice> devices) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        ...syncOnOverrides(
          status: SyncedStatus(DateTime.now().toUtc()),
          devices: devices,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: DeviceList(onFeedback: (String _) {}),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the last device offers delete everywhere instead of remove', (
    WidgetTester tester,
  ) async {
    await _pumpList(tester, <JournalDevice>[
      _device('this', 'Field phone', thisDevice: true),
      _device(
        'other',
        'Studio Mac',
        thisDevice: false,
        seen: const Duration(days: 2),
      ),
    ]);

    expect(find.text('Field phone'), findsOneWidget);
    expect(find.text('Studio Mac'), findsOneWidget);
    expect(find.text('Last seen 2 days ago'), findsOneWidget);
    expect(find.widgetWithText(StickerButton, 'Remove'), findsNWidgets(2));
    expect(find.text('Delete journal everywhere'), findsNothing);

    await _pumpList(tester, <JournalDevice>[
      _device('this', 'Field phone', thisDevice: true),
    ]);

    expect(find.text('Field phone'), findsOneWidget);
    expect(
      find.text(
        defaultTargetPlatform == TargetPlatform.android
            ? 'This phone'
            : 'This Mac',
      ),
      findsOneWidget,
    );
    expect(find.text('Remove'), findsNothing);
    final Finder deleteEverywhere = find.widgetWithText(
      StickerButton,
      'Delete journal everywhere',
    );
    expect(deleteEverywhere, findsOneWidget);

    await tester.tap(deleteEverywhere);
    await tester.pumpAndSettle();

    expect(find.byType(SyncDeleteAllDialog), findsOneWidget);
    expect(find.text('Delete your journal'), findsOneWidget);
    expect(find.text(removeFromThisDeviceMessage), findsOneWidget);
    expect(find.text(deleteJournalEverywhereMessage), findsOneWidget);
  }, variant: _bothPlatforms);

  testWidgets('locked keys are named instead of the server', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (int retryCount, Object error) => null,
        overrides: <Override>[
          ...syncOnOverrides(
            status: const AttentionStatus(AttentionReason.keysLocked),
            devicesError: const KeyAccessException(AttentionReason.keysLocked),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: DeviceList(onFeedback: (String _) {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(devicesLockedMessage), findsOneWidget);
    expect(find.text(devicesUnavailableMessage), findsNothing);
  });

  testWidgets('removing a device while the keys are locked says so', (
    WidgetTester tester,
  ) async {
    final List<String> feedback = <String>[];
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (int retryCount, Object error) => null,
        overrides: <Override>[
          ...syncOnOverrides(
            status: SyncedStatus(DateTime.now().toUtc()),
            devices: <JournalDevice>[
              _device('this', 'Field phone', thisDevice: true),
              _device('other', 'Studio Mac', thisDevice: false),
            ],
            deviceServiceError: const KeyAccessException(
              AttentionReason.keysLocked,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: DeviceList(onFeedback: feedback.add)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(deviceRemoveKey('other')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(confirmDialogConfirmKey));
    await tester.pumpAndSettle();

    expect(feedback, <String>[keysLockedFix]);
  });

  test(
    'the device list leaves the keys alone while sync has them locked',
    () async {
      final SyncTestDevice mac = SyncTestDevice('Mac');
      addTearDown(mac.dispose);
      await mac.keyStore.writeDeviceKeys(DeviceKeys.generate());
      final _CountingValues values = _CountingValues(mac.secureValues);

      ProviderContainer showing({required bool locked}) {
        final ProviderContainer container = ProviderContainer(
          retry: (int retryCount, Object error) => null,
          overrides: <Override>[
            databaseProvider.overrideWithValue(mac.database),
            keyStoreProvider.overrideWithValue(KeyStore(values)),
            syncEnabledProvider.overrideWith(
              (Ref ref) => Stream<bool>.value(true),
            ),
            relayAddressProvider.overrideWith(
              (Ref ref) => Stream<String?>.value('https://sync.example.com'),
            ),
            syncKeysLockedProvider.overrideWith(
              (Ref ref) => Stream<bool>.value(locked),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.listen(deviceServiceProvider, (_, _) {});
        return container;
      }

      await expectLater(
        showing(locked: true).read(deviceServiceProvider.future),
        throwsA(isA<KeyAccessException>()),
      );
      expect(values.reads, 0);

      expect(
        await showing(locked: false).read(deviceServiceProvider.future),
        isNotNull,
      );
      expect(values.reads, greaterThan(0));
    },
  );

  test('a refused read in the device list locks sync', () async {
    final SyncTestDevice mac = SyncTestDevice('Mac');
    addTearDown(mac.dispose);
    final SyncEngine engine = mac.engine();
    final ProviderContainer container = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: <Override>[
        databaseProvider.overrideWithValue(mac.database),
        keyStoreProvider.overrideWithValue(KeyStore(_RefusedValues())),
        syncEngineProvider.overrideWithValue(engine),
        syncEnabledProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
        relayAddressProvider.overrideWith(
          (Ref ref) => Stream<String?>.value('https://sync.example.com'),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(deviceServiceProvider, (_, _) {});

    await expectLater(
      container.read(deviceServiceProvider.future),
      throwsA(isA<KeyAccessException>()),
    );

    expect(engine.keysLocked, isTrue);
  });
}

final class _RefusedValues implements SecureValues {
  @override
  Future<String?> read(String key) async =>
      throw const KeyAccessException('refused');

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

final class _CountingValues implements SecureValues {
  _CountingValues(this._inner);

  final SecureValues _inner;
  int reads = 0;

  @override
  Future<String?> read(String key) {
    reads += 1;
    return _inner.read(key);
  }

  @override
  Future<void> write(String key, String value) => _inner.write(key, value);

  @override
  Future<void> delete(String key) => _inner.delete(key);
}
