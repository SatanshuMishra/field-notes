import 'package:field_notes/domain/settings/settings.dart';

enum SyncStorageChoice {
  onDevice('On this device'),
  syncToServer('Sync to server');

  const SyncStorageChoice(this.label);

  final String label;

  static SyncStorageChoice fromStorageMode(StorageMode mode) {
    return switch (mode) {
      StorageMode.onDevice => SyncStorageChoice.onDevice,
    };
  }
}

enum SyncFrequency {
  automatic('Automatic'),
  manual('Manual');

  const SyncFrequency(this.label);

  final String label;
}
