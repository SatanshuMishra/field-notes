import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

const String _push = '/v1/records/push';

final class _RefusingValues implements SecureValues {
  _RefusingValues(this._inner);

  final SecureValues _inner;
  bool refusing = true;
  bool refusingWrites = false;
  int reads = 0;

  @override
  Future<String?> read(String key) async {
    reads += 1;
    if (refusing) {
      throw KeyAccessException(
        PlatformException(code: '-128', message: 'User canceled'),
      );
    }
    return _inner.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (refusingWrites) {
      throw KeyAccessException(
        PlatformException(code: '-128', message: 'User canceled'),
      );
    }
    await _inner.write(key, value);
  }

  @override
  Future<void> delete(String key) => _inner.delete(key);
}

SyncEngine _engineWith(SyncTestDevice device, KeyStore keyStore) => SyncEngine(
  database: device.database,
  keyStore: keyStore,
  recorder: device.recorder,
  network: device.network,
  lifecycle: device.lifecycle,
  deviceName: () async => device.name,
  clock: device.clock,
  clientFor:
      (
        Uri baseUrl,
        DeviceKeys keys,
        void Function(SessionResponse session) onSession,
      ) => RelayClient(
        baseUrl: baseUrl,
        device: keys,
        onSession: onSession,
        client: device.http,
      ),
  random: NoJitter(),
);

Future<void> _note(SyncTestDevice device, String text) => device.journal
    .saveNote(date: '2026-10-06', source: text, photoMediaIds: const <String>[])
    .then((_) {});

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late RelayFixture relay;
  late List<SyncTestDevice> devices;

  setUp(() async {
    relay = await RelayFixture.start(rateBurst: 1000);
    devices = <SyncTestDevice>[];
  });

  tearDown(() async {
    for (final SyncTestDevice device in devices) {
      await device.dispose();
    }
    await relay.dispose();
  });

  SyncTestDevice device(String name) {
    final SyncTestDevice created = SyncTestDevice(name);
    devices.add(created);
    return created;
  }

  test(
    'a refused key read needs attention and never retries on its own',
    () async {
      final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
      final _RefusingValues values = _RefusingValues(mac.secureValues);
      final SyncEngine engine = _engineWith(
        mac,
        KeyStore(CachedSecureValues(values)),
      );
      addTearDown(engine.dispose);
      mac.http.sent.clear();

      await engine.start();
      await engine.syncNow();
      await eventually(
        () async =>
            await engine.status() ==
            const AttentionStatus(AttentionReason.keysLocked),
      );
      final int readsAfterRefusal = values.reads;

      await _note(mac, 'written while the keys are locked');
      await mac.clock.advance(const Duration(minutes: 30));

      expect(values.reads, readsAfterRefusal);
      expect(mac.http.sent, isEmpty);
      expect(
        await engine.status(),
        const AttentionStatus(AttentionReason.keysLocked),
      );

      values.refusing = false;
      await engine.syncNow();

      await eventually(() async => await engine.status() is SyncedStatus);
      expect(mac.http.countOf('POST', _push), greaterThan(0));
    },
  );

  test(
    'a refusal outside the engine locks it until Sync now, even while paused',
    () async {
      final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
      final SyncEngine engine = _engineWith(
        mac,
        KeyStore(CachedSecureValues(mac.secureValues)),
      );
      addTearDown(engine.dispose);
      await engine.start();
      await engine.syncNow();
      await eventually(() async => await engine.status() is SyncedStatus);
      final List<bool> locks = <bool>[];
      final StreamSubscription<bool> watching = engine.watchKeysLocked().listen(
        locks.add,
      );
      addTearDown(watching.cancel);
      await engine.pause(true);

      engine.keysRefused();

      expect(engine.keysLocked, isTrue);
      expect(await engine.status(), isA<PausedStatus>());
      await engine.pause(false);
      expect(engine.keysLocked, isTrue);
      expect(
        await engine.status(),
        const AttentionStatus(AttentionReason.keysLocked),
      );

      await engine.syncNow();

      expect(engine.keysLocked, isFalse);
      await eventually(() async => locks.contains(true) && !locks.last);
    },
  );

  test('keys read once are not read from the platform again', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final _RefusingValues values = _RefusingValues(mac.secureValues)
      ..refusing = false;
    final SyncEngine engine = _engineWith(
      mac,
      KeyStore(CachedSecureValues(values)),
    );
    addTearDown(engine.dispose);

    await engine.start();
    await engine.syncNow();
    await eventually(() async => await engine.status() is SyncedStatus);
    final int readsAfterFirstCycle = values.reads;
    values.refusing = true;

    for (int round = 0; round < 5; round++) {
      await _note(mac, 'round $round');
      await mac.clock.advance(localWriteDelay);
      await engine.syncNow();
    }

    await eventually(
      () async =>
          await engine.status() is SyncedStatus &&
          (await mac.database.select(mac.database.syncOutbox).get()).isEmpty,
    );
    expect(values.reads, readsAfterFirstCycle);
  });

  test('a cached read is shared and a failed read is not remembered', () async {
    final _RefusingValues values = _RefusingValues(
      MemorySecureValues(<String, String>{'k': 'v'}),
    );
    final CachedSecureValues cached = CachedSecureValues(values);

    await expectLater(cached.read('k'), throwsA(isA<KeyAccessException>()));
    values.refusing = false;
    final List<String?> together = await Future.wait(<Future<String?>>[
      cached.read('k'),
      cached.read('k'),
    ]);
    expect(together, <String?>['v', 'v']);
    expect(values.reads, 2);

    await cached.write('k', 'w');
    values.refusing = true;
    expect(await cached.read('k'), 'w');
    await cached.delete('k');
    expect(await cached.read('k'), isNull);
    expect(values.reads, 2);
  });

  test('a refused key write keeps the value already known', () async {
    final _RefusingValues values = _RefusingValues(
      MemorySecureValues(<String, String>{'k': 'v'}),
    )..refusing = false;
    final CachedSecureValues cached = CachedSecureValues(values);
    expect(await cached.read('k'), 'v');
    values.refusingWrites = true;

    await expectLater(
      cached.write('k', 'w'),
      throwsA(isA<KeyAccessException>()),
    );
    values.refusing = true;

    expect(await cached.read('k'), 'v');
  });

  test('an unexpected failure is retried with back-off and reported', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    bool broken = true;
    mac.http.intercept = (http.BaseRequest request) async {
      if (broken && request.url.path == _push) {
        throw UnsupportedError('a fault the engine has never seen');
      }
      return null;
    };
    final SyncEngine engine = mac.engine();
    await engine.start();
    await _note(mac, 'a note that hits the fault');
    while (engine.consecutiveFailures < unreachableAfterFailures) {
      await engine.syncNow();
    }
    await eventually(
      () async =>
          await engine.status() ==
          const AttentionStatus(AttentionReason.problem),
    );

    broken = false;
    await mac.clock.advance(maxBackoff);

    await eventually(() async => await engine.status() is SyncedStatus);
    expect(engine.consecutiveFailures, 0);
  });

  test(
    'writes that never pause are still sent within the longest delay',
    () async {
      final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
      final SyncEngine engine = mac.engine();
      await engine.start();
      await engine.syncNow();
      await eventually(() async => engine.isLive);
      await engine.syncNow();
      mac.http.sent.clear();

      const Duration gap = Duration(milliseconds: 500);
      Duration elapsed = Duration.zero;
      while (elapsed < localWriteMaxDelay + localWriteDelay) {
        await _note(mac, 'typing at ${elapsed.inMilliseconds}');
        await eventually(() async => mac.clock.pendingTimers > 0);
        await mac.clock.advance(gap);
        elapsed += gap;
      }

      await eventually(() async => mac.http.countOf('POST', _push) > 0);
    },
  );

  test('retry waits follow the jittered exponential formula', () {
    final Random random = Random(7);
    for (int failures = 1; failures <= 12; failures++) {
      final Duration base = backoffAfter(failures);
      final Duration wait = jitteredBackoff(failures, random);
      expect(wait, greaterThanOrEqualTo(base));
      expect(wait, lessThanOrEqualTo(base + maxBackoffJitter));
      expect(wait, lessThanOrEqualTo(maxBackoff));
    }
    expect(backoffAfter(1), firstBackoff);
    expect(backoffAfter(30), maxBackoff);
    expect(jitteredBackoff(30, Random(1)), maxBackoff);
    expect(jitteredBackoff(0, Random(1)), Duration.zero);
    expect(
      <Duration>{
        for (int seed = 0; seed < 20; seed++) jitteredBackoff(1, Random(seed)),
      }.length,
      greaterThan(1),
    );
  });

  test('a lost connection error never escapes the engine', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    mac.http.intercept = (http.BaseRequest request) async =>
        throw const SocketException('connection reset');
    final SyncEngine engine = mac.engine();
    await engine.start();
    await engine.syncNow();
    await eventually(() async => engine.consecutiveFailures >= 1);
    expect(
      await engine.status(),
      isNot(const AttentionStatus(AttentionReason.problem)),
    );
  });
}
