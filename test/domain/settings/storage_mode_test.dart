import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/domain/settings/storage_mode.dart';

void main() {
  group('StorageMode', () {
    test('v1 exposes only the on_device mode', () {
      expect(StorageMode.values, <StorageMode>[StorageMode.onDevice]);
      expect(StorageMode.onDevice.id, 'on_device');
    });

    test('fromId resolves on_device and rejects everything else', () {
      expect(StorageMode.fromId('on_device'), StorageMode.onDevice);
      expect(StorageMode.fromId('sync'), isNull);
      expect(StorageMode.fromId(null), isNull);
    });
  });
}
