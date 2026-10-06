import 'package:field_notes/data/crypto/key_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the platform key store reports a refused read as key access', () async {
    const MethodChannel channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          throw PlatformException(code: '-128', message: 'User canceled');
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    const PlatformSecureValues values = PlatformSecureValues(
      FlutterSecureStorage(),
    );

    await expectLater(
      values.read(KeyStore.deviceKeysKey),
      throwsA(isA<KeyAccessException>()),
    );
    await expectLater(
      values.write(KeyStore.uploadPassKey, '{}'),
      throwsA(isA<KeyAccessException>()),
    );
  });
}
