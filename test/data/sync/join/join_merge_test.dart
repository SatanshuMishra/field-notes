import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/settings/settings_keys.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/join/join_merge.dart';
import 'package:field_notes/data/sync/merge/record_reader.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

const String _pull = '/v1/records';

Future<List<Entry>> _entries(SyncTestDevice device) =>
    device.database.select(device.database.entries).get();

Future<List<Day>> _daysOn(SyncTestDevice device, String date) =>
    (device.database.select(
      device.database.days,
    )..where((t) => t.date.equals(date))).get();

Future<JournalSetting?> _setting(SyncTestDevice device, String key) =>
    (device.database.select(
      device.database.journalSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();

Future<domain.Entry> _note(
  SyncTestDevice device,
  String date,
  String text,
) async {
  final domain.Day day = await device.journal.ensureDayForDate(date);
  return device.journal.createEntry(
    dayId: day.id,
    type: domain.EntryType.text,
    textContent: text,
  );
}

Future<void> _sync(SyncTestDevice device) async {
  final SyncEngine engine = device.engine(joining: true);
  await engine.start();
  await engine.syncNow();
  await device.disposeEngines();
}

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

  Future<SyncTestDevice> journalOwner() async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    await mac.settings.setWeekStart(WeekStart.sunday);
    await _note(mac, '2026-09-29', 'mac on the shared date');
    await _sync(mac);
    return mac;
  }

  test("a joining device's entries merge and same dates combine", () async {
    final SyncTestDevice mac = await journalOwner();
    final SyncTestDevice phone = device('Phone');
    await _note(phone, '2026-09-29', 'phone on the shared date');
    await _note(phone, '2026-09-30', 'phone alone');
    await _note(phone, '2026-10-01', 'phone later');
    await pairDevice(relay, mac, phone);

    await _sync(phone);
    await _sync(mac);

    for (final SyncTestDevice each in <SyncTestDevice>[mac, phone]) {
      final List<String?> texts = <String?>[
        for (final Entry entry in await _entries(each)) entry.textContent,
      ];
      expect(
        texts,
        unorderedEquals(<String>[
          'mac on the shared date',
          'phone on the shared date',
          'phone alone',
          'phone later',
        ]),
      );
      expect(await _daysOn(each, '2026-09-29'), hasLength(1));
    }
    expect(
      (await _daysOn(mac, '2026-09-29')).single.id,
      (await _daysOn(phone, '2026-09-29')).single.id,
    );
    expect(
      await phone.database.select(phone.database.syncOutbox).get(),
      isEmpty,
    );
  });

  test("a joining device keeps the journal's week start", () async {
    final SyncTestDevice mac = await journalOwner();
    final int journalMeadow = await mac.settings.meadowKey();
    final SyncTestDevice phone = device('Phone');
    await phone.clock.advance(const Duration(minutes: 1));
    await phone.settings.setWeekStart(WeekStart.saturday);
    final int localMeadow = await phone.settings.meadowKey();
    expect(localMeadow, isNot(journalMeadow));
    await pairDevice(relay, mac, phone);

    await _sync(phone);
    await _sync(mac);

    expect((await phone.settings.load()).weekStart, WeekStart.sunday);
    expect((await mac.settings.load()).weekStart, WeekStart.sunday);
    expect(await phone.settings.meadowKey(), journalMeadow);
    expect(await mac.settings.meadowKey(), journalMeadow);
    expect(await phone.syncState(joinPendingKey), isNull);
  });

  test('a join interrupted mid-pull finishes on the next start', () async {
    final SyncTestDevice mac = await journalOwner();
    for (int index = 0; index < 4; index++) {
      await _note(mac, '2026-08-0${index + 1}', 'mac note $index');
    }
    await _sync(mac);
    final SyncTestDevice phone = device('Phone');
    await phone.settings.setReflectionPromptsEnabled(false);
    await pairDevice(relay, mac, phone);
    int pulls = 0;
    phone.http.intercept = (http.BaseRequest request) async {
      if (request.method == 'GET' && request.url.path == _pull) {
        pulls += 1;
        if (pulls >= 2) {
          throw const SocketException('The connection dropped');
        }
      }
      return null;
    };
    final SyncEngine interrupted = phone.engine(joining: true, pullPageSize: 2);
    await interrupted.start();
    await interrupted.syncNow();

    expect(pulls, greaterThanOrEqualTo(2));
    expect((await _entries(phone)).length, lessThan(5));
    expect(await phone.syncState(joinPendingKey), 'true');
    expect(await phone.syncState(joinDoneKey), isNull);
    final JournalSetting held = (await _setting(
      phone,
      SettingsKeys.reflectionPrompts,
    ))!;
    expect(decodeFieldClocks(held.fieldClocks).values.toSet(), <String>{
      lowestClock,
    });
    expect(
      await (phone.database.select(phone.database.syncOutbox)
            ..where((t) => t.recordTable.equals(SyncedTables.journalSettings)))
          .get(),
      isEmpty,
    );
    await phone.disposeEngines();
    phone.http.intercept = null;

    final SyncEngine resumed = phone.engine(joining: true, pullPageSize: 2);
    await resumed.start();
    await resumed.syncNow();
    await phone.disposeEngines();

    expect(await phone.syncState(joinPendingKey), isNull);
    expect(await phone.syncState(joinDoneKey), 'true');
    final JournalSetting stamped = (await _setting(
      phone,
      SettingsKeys.reflectionPrompts,
    ))!;
    expect(
      decodeFieldClocks(stamped.fieldClocks).values,
      everyElement(isNot(lowestClock)),
    );
    expect(await _entries(phone), hasLength(5));
    await _sync(mac);
    expect((await mac.settings.load()).reflectionPromptsEnabled, isFalse);
    expect((await mac.settings.load()).weekStart, WeekStart.sunday);
    expect((await phone.settings.load()).weekStart, WeekStart.sunday);
  });

  test(
    "a meadow opened during the joining pull keeps the journal's meadow",
    () async {
      final SyncTestDevice mac = await journalOwner();
      final int journalMeadow = await mac.settings.meadowKey();
      final SyncTestDevice phone = device('Phone');
      await pairDevice(relay, mac, phone);
      final List<int> readDuringPull = <int>[];
      phone.http.intercept = (http.BaseRequest request) async {
        if (request.method == 'GET' && request.url.path == _pull) {
          readDuringPull.add(await phone.settings.meadowKey());
        }
        return null;
      };
      await phone.clock.advance(const Duration(minutes: 1));

      await _sync(phone);

      expect(readDuringPull, isNotEmpty);
      expect(await phone.settings.meadowKey(), journalMeadow);
      await _sync(mac);
      expect(await mac.settings.meadowKey(), journalMeadow);
      final JournalSetting meadow = (await _setting(
        phone,
        SettingsKeys.meadowKey,
      ))!;
      final JournalSetting journal = (await _setting(
        mac,
        SettingsKeys.meadowKey,
      ))!;
      expect(meadow.fieldClocks, journal.fieldClocks);
    },
  );

  test("a restore keeps local entries and the journal's week start", () async {
    final SyncTestDevice mac = await journalOwner();
    final int journalMeadow = await mac.settings.meadowKey();
    final SyncTestDevice reinstalled = device('Reinstalled');
    await reinstalled.clock.advance(const Duration(minutes: 1));
    await reinstalled.settings.setWeekStart(WeekStart.monday);
    await reinstalled.settings.meadowKey();
    await _note(reinstalled, '2026-10-02', 'kept through the restore');
    await _note(reinstalled, '2026-10-03', 'also kept');
    await restoreDevice(relay, mac.words, reinstalled);

    await _sync(reinstalled);
    await _sync(mac);

    for (final SyncTestDevice each in <SyncTestDevice>[mac, reinstalled]) {
      final List<String?> texts = <String?>[
        for (final Entry entry in await _entries(each)) entry.textContent,
      ];
      expect(
        texts,
        unorderedEquals(<String>[
          'mac on the shared date',
          'kept through the restore',
          'also kept',
        ]),
      );
      expect((await each.settings.load()).weekStart, WeekStart.sunday);
      expect(await each.settings.meadowKey(), journalMeadow);
    }
  });
}
