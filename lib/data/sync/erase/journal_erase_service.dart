import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/erase/local_journal_wipe.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:sync_protocol/sync_protocol.dart';

const String journalErasedNotice = 'Your journal was deleted everywhere';
const String deviceRemovedNotice = 'This device was removed from your journal';
const String eraseFailedMessage =
    "Your journal couldn't be deleted from your server. Try again.";
const String eraseOfflineMessage =
    'Connect to the internet to delete your journal everywhere.';

class JournalEraseException implements Exception {
  const JournalEraseException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'JournalEraseException: $message'
      : 'JournalEraseException: $message ($cause)';
}

final class JournalEraseService {
  JournalEraseService({
    required AppDatabase database,
    required this._keyStore,
    required this._wipe,
    this._clientFor = defaultRelayClient,
  }) : _db = database;

  final AppDatabase _db;
  final KeyStore _keyStore;
  final LocalJournalWipe _wipe;
  final RelayClientFactory _clientFor;

  Future<void> eraseEverywhere() async {
    final String? address = await readSyncState(_db, SyncStateKeys.relayUrl);
    final DeviceKeys? device = await _keyStore.readDeviceKeys();
    if (address == null || device == null) {
      throw const JournalEraseException(eraseFailedMessage);
    }
    final RelayClient client = _clientFor(Uri.parse(address), device);
    try {
      await client.eraseJournal();
    } on RelayRejected catch (error) {
      if (error.code != SyncErrorCode.journalErased) {
        throw JournalEraseException(eraseFailedMessage, error);
      }
    } on RelayUnreachable catch (error) {
      throw JournalEraseException(eraseOfflineMessage, error);
    } on RelayException catch (error) {
      throw JournalEraseException(eraseFailedMessage, error);
    } finally {
      client.close();
    }
    await _wipe.wipe();
  }
}
