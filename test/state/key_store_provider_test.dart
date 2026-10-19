import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/crypto/recovery_phrase.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

({Map<String, String> keychain, KeyStore store}) _keyStoreOn(
  TargetPlatform platform,
) {
  final Map<String, String> keychain = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (MethodCall call) async {
        final Map<Object?, Object?> arguments =
            call.arguments as Map<Object?, Object?>;
        final String? key = arguments['key'] as String?;
        switch (call.method) {
          case 'read':
            return keychain[key];
          case 'containsKey':
            return keychain.containsKey(key);
          case 'write':
            keychain[key!] = arguments['value']! as String;
            return null;
          case 'delete':
            keychain.remove(key);
            return null;
          case 'readAll':
            return Map<String, String>.of(keychain);
          case 'deleteAll':
            keychain.clear();
            return null;
        }
        return null;
      });
  debugDefaultTargetPlatformOverride = platform;
  final ProviderContainer container = ProviderContainer();
  addTearDown(() {
    container.dispose();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });
  return (keychain: keychain, store: container.read(keyStoreProvider));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Mac key store keeps every sync key in one keychain item', () async {
    final (:Map<String, String> keychain, :KeyStore store) = _keyStoreOn(
      TargetPlatform.macOS,
    );

    await store.writeJournalKeys(JournalKeys.generate());
    await store.writeDeviceKeys(DeviceKeys.generate());
    await store.writeRecoveryPublicKeys(
      RecoveryKeys.fromSeed(newRecoverySeed()).publicKeys,
    );
    await store.writeAccountId('account-1');
    await store.writeUploadPass(
      UploadPass(token: 'pass', expiresAt: DateTime.utc(2026, 10, 19)),
    );

    expect(keychain.keys, hasLength(1));
  });

  test('off the Mac every key keeps its own item', () async {
    final (:Map<String, String> keychain, :KeyStore store) = _keyStoreOn(
      TargetPlatform.windows,
    );

    await store.writeAccountId('account-1');
    await store.writeUploadPass(
      UploadPass(token: 'pass', expiresAt: DateTime.utc(2026, 10, 19)),
    );

    expect(
      keychain.keys,
      unorderedEquals(<String>[
        'field_notes.sync.account_id',
        'field_notes.sync.upload_pass',
      ]),
    );
  });
}
