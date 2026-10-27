import 'dart:async';
import 'dart:io';

import 'package:camera_macos/camera_macos.dart' show CameraImageData;
import 'package:camera_platform_interface/camera_platform_interface.dart'
    show CameraDescription, CameraPlatform;
import 'package:drift/native.dart';
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/pairing/pairing_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/settings/widgets/devices_dialog.dart';
import 'package:field_notes/features/sync/ui/add_device_sheet.dart';
import 'package:field_notes/features/sync/ui/device_list.dart';
import 'package:field_notes/features/sync/ui/join_journal_flow.dart';
import 'package:field_notes/features/sync/ui/join_scan_page.dart';
import 'package:field_notes/features/sync/ui/mac_code_scanner.dart';
import 'package:field_notes/features/sync/ui/restore_flow.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/sync_overrides.dart';
import '../support/a11y_state.dart';

final DateTime _now = DateTime.utc(2026, 9, 18, 15, 30);
final Uri _relay = Uri.parse('https://sync.example.com');
const String _typedServer = 'https://sync.example.com';
const String _typedInvite = 'invite-1';

final class _Host {
  BuildContext? context;
}

Future<_Host> _pumpHost(
  WidgetTester tester,
  A11yVariant variant, {
  required List<Override> overrides,
}) async {
  variant.useWindow(tester);
  final _Host host = _Host();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      retry: (int retryCount, Object error) => null,
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: variant.theme,
        builder: variant.scaleText,
        home: Builder(
          builder: (BuildContext context) {
            host.context = context;
            return Scaffold(
              backgroundColor: context.colors.page,
              body: const SizedBox.expand(),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return host;
}

Future<void> _openFlow(
  WidgetTester tester,
  A11yVariant variant, {
  required List<Override> overrides,
  required WidgetBuilder flow,
}) async {
  final _Host host = await _pumpHost(tester, variant, overrides: overrides);
  unawaited(showSyncFlow<Object?>(host.context!, builder: flow));
  await tester.pumpAndSettle();
}

List<Override> _syncOn() =>
    syncOnOverrides(status: SyncedStatus(_now), address: _typedServer);

List<Override> _replacing(
  List<Override> base,
  Object provider,
  Override replacement,
) => <Override>[
  for (final Override override in base)
    if (override.origin != provider) override,
  replacement,
];

AppDatabase _database() {
  final AppDatabase database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  return database;
}

RelayClient _unreachableRelay(Uri baseUrl, DeviceKeys? device) => RelayClient(
  baseUrl: baseUrl,
  device: device,
  client: MockClient(
    (http.Request request) async =>
        throw http.ClientException('Connection refused', request.url),
  ),
);

Future<PairingService> _pairingService() async {
  final AppDatabase database = _database();
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
    clientFor: _unreachableRelay,
    deviceName: () async => 'Desk',
    wait: (Duration _) => Completer<void>().future,
    clock: () => _now,
  );
}

Future<void> _neverJoins(
  String code, {
  required JournalConfirmation confirmJournal,
  Uri? relayUrl,
  bool Function()? cancelled,
  void Function(String comparison)? onComparison,
}) => Completer<void>().future;

final class _NoCameras extends CameraPlatform {
  @override
  Future<List<CameraDescription>> availableCameras() async =>
      const <CameraDescription>[];
}

final class _StillMacCamera implements MacScannerCamera {
  const _StillMacCamera();

  @override
  Widget preview() => const SizedBox.expand();

  @override
  Future<void> start() async {}

  @override
  Future<CameraImageData?> takeFrame() => Completer<CameraImageData?>().future;

  @override
  Future<void> stop() async {}
}

void _withoutCameras() {
  final CameraPlatform original = CameraPlatform.instance;
  CameraPlatform.instance = _NoCameras();
  addTearDown(() => CameraPlatform.instance = original);
}

JournalDevice _device(
  String id,
  String name, {
  required bool thisDevice,
  Duration seen = Duration.zero,
}) => JournalDevice(
  deviceId: id,
  name: name,
  createdAt: _now.subtract(const Duration(days: 9)),
  lastSeenAt: _now.subtract(seen),
  isThisDevice: thisDevice,
);

final List<JournalDevice> _devices = <JournalDevice>[
  _device('this', 'Field phone', thisDevice: true),
  _device(
    'studio',
    'Studio Mac',
    thisDevice: false,
    seen: const Duration(days: 2),
  ),
];

Future<void> _pumpDevices(
  WidgetTester tester,
  A11yVariant variant, {
  required List<Override> overrides,
}) async {
  final _Host host = await _pumpHost(tester, variant, overrides: overrides);
  final BuildContext context = host.context!;
  if (variant.desktop) {
    unawaited(showDevicesDialog(context, onFeedback: (String _) {}));
  } else {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext page) => Scaffold(
            backgroundColor: page.colors.page,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DeviceList(onFeedback: (String _) {}, now: () => _now),
              ),
            ),
          ),
        ),
      ),
    );
  }
  await tester.pumpAndSettle();
}

Finder _fieldLabelled(String label) => find
    .descendant(
      of: find
          .ancestor(of: find.text(label), matching: find.byType(Column))
          .first,
      matching: find.byType(EditableText),
    )
    .first;

Future<void> _pumpStartUnreachable(
  WidgetTester tester,
  A11yVariant variant,
) async {
  final EnrolmentService unreachable = EnrolmentService(
    database: _database(),
    keyStore: KeyStore(MemorySecureValues()),
    clientFor: _unreachableRelay,
    deviceName: () async => 'Test device',
  );
  await _openFlow(
    tester,
    variant,
    overrides: _replacing(
      syncOffOverrides(),
      enrolmentServiceProvider,
      enrolmentServiceProvider.overrideWithValue(unreachable),
    ),
    flow: (BuildContext _) => const StartSyncFlow(),
  );
  await tester.enterText(_fieldLabelled(serverAddressLabel), _typedServer);
  await tester.enterText(_fieldLabelled(inviteCodeLabel), _typedInvite);
  await tester.pump();
  await tester.tap(find.byKey(startSyncContinueKey));
  await tester.pumpAndSettle();
}

final Finder _joinFirstStep = find.byWidgetPredicate(
  (Widget widget) =>
      widget is JoinScanPage ||
      (widget is Text && widget.data == joinTypeTitle),
  description: 'the scan page on the phone, the typed words on desktop',
);

final List<A11yState> syncStates = <A11yState>[
  A11yState(
    id: 's1-sync-start',
    pump: (WidgetTester tester, A11yVariant variant) => _openFlow(
      tester,
      variant,
      overrides: syncOffOverrides(),
      flow: (BuildContext _) => const StartSyncFlow(),
    ),
    proof: <A11yProof>[
      A11yProof(find.text(startSyncTitle)),
      A11yProof(find.byKey(startSyncContinueKey)),
    ],
  ),
  A11yState(
    id: 's2-sync-join',
    pump: (WidgetTester tester, A11yVariant variant) {
      _withoutCameras();
      return _openFlow(
        tester,
        variant,
        overrides: syncOffOverrides(),
        flow: (BuildContext _) => const JoinJournalFlow(
          join: _neverJoins,
          macCamera: _StillMacCamera(),
        ),
      );
    },
    proof: <A11yProof>[
      A11yProof(find.byType(JoinJournalFlow)),
      A11yProof(_joinFirstStep),
    ],
  ),
  A11yState(
    id: 's3-sync-restore',
    pump: (WidgetTester tester, A11yVariant variant) => _openFlow(
      tester,
      variant,
      overrides: syncOffOverrides(),
      flow: (BuildContext _) => const RestoreFlow(),
    ),
    proof: <A11yProof>[
      A11yProof(find.text(restoreTitle)),
      A11yProof(find.byKey(restoreConfirmKey)),
    ],
  ),
  A11yState(
    id: 's4-add-device-unreachable',
    pump: (WidgetTester tester, A11yVariant variant) async {
      final PairingService pairing = await _pairingService();
      await _openFlow(
        tester,
        variant,
        overrides: _replacing(
          _syncOn(),
          pairingServiceProvider,
          pairingServiceProvider.overrideWithValue(pairing),
        ),
        flow: (BuildContext _) => AddDeviceSheet(clock: () => _now),
      );
    },
    proof: <A11yProof>[
      A11yProof(find.byType(AddDeviceSheet)),
      A11yProof(find.text(addDeviceTitle)),
      A11yProof(find.text(unreachableMessage)),
    ],
  ),
  A11yState(
    id: 's5-change-server',
    pump: (WidgetTester tester, A11yVariant variant) => _openFlow(
      tester,
      variant,
      overrides: _syncOn(),
      flow: (BuildContext _) => const ChangeServerAddressFlow(),
    ),
    proof: <A11yProof>[
      A11yProof(find.byType(ChangeServerAddressFlow)),
      A11yProof(find.text(changeAddressTitle)),
    ],
  ),
  A11yState(
    id: 's6-devices-list',
    pump: (WidgetTester tester, A11yVariant variant) => _pumpDevices(
      tester,
      variant,
      overrides: syncOnOverrides(
        status: SyncedStatus(_now),
        address: _typedServer,
        devices: _devices,
      ),
    ),
    proof: <A11yProof>[
      A11yProof(find.byType(DeviceList)),
      A11yProof(find.text('Studio Mac')),
    ],
  ),
  A11yState(
    id: 's7-sync-error-unreachable',
    pump: _pumpStartUnreachable,
    proof: <A11yProof>[
      A11yProof(find.byType(SyncFlowError)),
      A11yProof(find.text(unreachableMessage)),
    ],
  ),
  A11yState(
    id: 's8-devices-list-sync-error',
    pump: (WidgetTester tester, A11yVariant variant) => _pumpDevices(
      tester,
      variant,
      overrides: syncOnOverrides(
        status: SyncedStatus(_now),
        address: _typedServer,
        devicesError: const SocketException('Connection refused'),
      ),
    ),
    proof: <A11yProof>[
      A11yProof(find.byType(DeviceList)),
      A11yProof(find.text(devicesUnavailableMessage)),
    ],
  ),
];
