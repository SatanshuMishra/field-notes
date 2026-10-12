import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/drafts/draft_paths.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/sync_overrides.dart';
import '../sync/support/simulated_device.dart' show SilentMediaProbe;

const MethodChannel _channel = MethodChannel('field_notes/background_uploads');

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late ProviderContainer container;
  late List<String> calls;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls = <String>[];
    _messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      calls.add(call.method);
      throw PlatformException(code: 'unavailable');
    });
    root = await Directory.systemTemp.createTemp('fn_sync_availability_');
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        keyStoreProvider.overrideWithValue(KeyStore(MemorySecureValues())),
        networkMonitorProvider.overrideWithValue(FakeNetworkMonitor()),
        appLifecycleProvider.overrideWithValue(FakeLifecycleSource()),
        mediaRootProvider.overrideWith(
          (Ref ref) async => Directory(p.join(root.path, mediaSubdir)),
        ),
        draftRootProvider.overrideWith(
          (Ref ref) async => Directory(p.join(root.path, draftsSubdir)),
        ),
        mediaProbeProvider.overrideWithValue(const SilentMediaProbe()),
        syncAvailableProvider.overrideWithValue(false),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    _messenger.setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
    await root.delete(recursive: true);
  });

  test(
    'a copy without sync never calls the background uploads channel',
    () async {
      expect(await container.read(backgroundTransferProvider.future), isNull);

      container.read(syncEngineProvider);
      await pumpEventQueue();
      await container.read(settingsRepositoryProvider).watch().first;
      await pumpEventQueue();

      expect(calls, isEmpty);
    },
  );
}
