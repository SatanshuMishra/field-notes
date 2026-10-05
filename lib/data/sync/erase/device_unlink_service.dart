import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/erase/local_journal_wipe.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:sync_protocol/sync_protocol.dart';

const String unlinkOfflineMessage =
    'Connect to the internet to remove this device.';
const String unlinkLastDeviceMessage =
    'This is the only device on your journal. Use "Delete journal everywhere" '
    'instead.';
const String unlinkFailedMessage =
    "This device couldn't be removed. Try again.";

class DeviceUnlinkException implements Exception {
  const DeviceUnlinkException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'DeviceUnlinkException: $message'
      : 'DeviceUnlinkException: $message ($cause)';
}

final class DeviceUnlinkService {
  DeviceUnlinkService({
    required AppDatabase database,
    required this._keyStore,
    required this._wipe,
    required this._network,
    this._clientFor = defaultRelayClient,
  }) : _db = database;

  static const Set<SyncErrorCode> _alreadyGone = <SyncErrorCode>{
    SyncErrorCode.deviceRemoved,
    SyncErrorCode.journalErased,
  };

  final AppDatabase _db;
  final KeyStore _keyStore;
  final LocalJournalWipe _wipe;
  final NetworkMonitor _network;
  final RelayClientFactory _clientFor;

  Future<void> removeThisDevice() async {
    if (await _network.current() == NetworkKind.offline) {
      throw const DeviceUnlinkException(unlinkOfflineMessage);
    }
    final String? address = await readSyncState(_db, SyncStateKeys.relayUrl);
    final DeviceKeys? device = await _keyStore.readDeviceKeys();
    if (address != null && device != null) {
      await _unregister(Uri.parse(address), device);
    }
    await _wipe.wipe();
  }

  Future<void> _unregister(Uri relayUrl, DeviceKeys device) async {
    final RelayClient client = _clientFor(relayUrl, device);
    try {
      await DeviceService(
        database: _db,
        keyStore: _keyStore,
        client: client,
      ).remove(device.deviceId);
    } on LastDeviceException catch (error) {
      throw DeviceUnlinkException(unlinkLastDeviceMessage, error);
    } on RelayRejected catch (error) {
      if (!_alreadyGone.contains(error.code)) {
        throw DeviceUnlinkException(unlinkFailedMessage, error);
      }
    } on RelayUnreachable catch (error) {
      throw DeviceUnlinkException(unlinkOfflineMessage, error);
    } on RelayException catch (error) {
      throw DeviceUnlinkException(unlinkFailedMessage, error);
    } finally {
      client.close();
    }
  }
}
