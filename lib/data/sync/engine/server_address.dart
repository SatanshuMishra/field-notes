import 'package:drift/drift.dart';
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/settings/journal_settings_store.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/data/sync/synced_tables.dart';

const String relayAddressKey = 'relay_address';

typedef SyncTrigger = Future<void> Function();

String normalizedAddress(String address) =>
    Uri.parse(address.trim()).toString();

Future<Uri?> addressToFollow(AppDatabase database) async {
  final JournalSetting? setting = await (database.select(
    database.journalSettings,
  )..where((t) => t.key.equals(relayAddressKey))).getSingleOrNull();
  final String? inUse = await readSyncState(database, SyncStateKeys.relayUrl);
  if (setting == null || inUse == null) {
    return null;
  }
  final Uri? target = Uri.tryParse(setting.value.trim());
  if (target == null ||
      !target.hasScheme ||
      normalizedAddress(setting.value) == normalizedAddress(inUse)) {
    return null;
  }
  final SyncOutboxData? unsent =
      await (database.select(database.syncOutbox)..where(
            (t) =>
                t.recordTable.equals(SyncedTables.journalSettings) &
                t.rowId.equals(relayAddressKey),
          ))
          .getSingleOrNull();
  return unsent == null ? target : null;
}

final class ServerAddress {
  ServerAddress({
    required AppDatabase database,
    required this._keyStore,
    required this._settings,
    required this._syncNow,
    this._clientFor = defaultRelayClient,
  }) : _db = database;

  final AppDatabase _db;
  final KeyStore _keyStore;
  final JournalSettingsStore _settings;
  final SyncTrigger _syncNow;
  final RelayClientFactory _clientFor;

  Future<Uri?> addressInUse() async {
    final String? address = await readSyncState(_db, SyncStateKeys.relayUrl);
    return address == null ? null : Uri.parse(address);
  }

  Future<String?> changeServerAddress(Uri newAddress) async {
    final DeviceKeys? device = await _keyStore.readDeviceKeys();
    if (device == null) {
      return setupFailedMessage;
    }
    final RelayClient client = _clientFor(newAddress, device);
    try {
      await client.signIn();
    } on RelayException catch (error) {
      return setupMessageFor(error);
    } finally {
      client.close();
    }
    await _settings.put(relayAddressKey, normalizedAddress('$newAddress'));
    await _syncNow();
    return null;
  }
}
