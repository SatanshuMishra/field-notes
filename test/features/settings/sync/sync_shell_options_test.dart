import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sync/sync_shell_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v1 storage mode maps to the on-device choice', () {
    expect(
      SyncStorageChoice.fromStorageMode(StorageMode.onDevice),
      SyncStorageChoice.onDevice,
    );
  });

  test('the shell offers both storage choices for the v2 flip', () {
    expect(
      SyncStorageChoice.values.map((SyncStorageChoice c) => c.label),
      <String>['On this device', 'Sync to server'],
    );
  });

  test('sync frequency is automatic or manual', () {
    expect(
      SyncFrequency.values.map((SyncFrequency f) => f.label),
      <String>['Automatic', 'Manual'],
    );
  });
}
