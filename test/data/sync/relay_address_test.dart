import 'dart:io';

import 'package:field_notes/data/sync/relay_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a sync server address must use HTTPS', () {
    expect(
      isUsableRelayAddress(Uri.parse('https://sync.satanshu.tech')),
      isTrue,
    );
    expect(isUsableRelayAddress(Uri.parse('https://10.0.0.5:8443')), isTrue);

    expect(
      isUsableRelayAddress(Uri.parse('http://sync.satanshu.tech')),
      isFalse,
    );
    expect(isUsableRelayAddress(Uri.parse('http://10.0.0.5:8080')), isFalse);
    expect(isUsableRelayAddress(Uri.parse('http://nas.local')), isFalse);
    expect(
      isUsableRelayAddress(Uri.parse('ftp://sync.satanshu.tech')),
      isFalse,
    );
  });

  test('only a server on the device itself may use plain HTTP', () {
    expect(isUsableRelayAddress(Uri.parse('http://127.0.0.1:8080')), isTrue);
    expect(isUsableRelayAddress(Uri.parse('http://localhost:8080')), isTrue);
    expect(isUsableRelayAddress(Uri.parse('http://[::1]:8080')), isTrue);

    expect(isUsableRelayAddress(Uri.parse('http://127.0.0.1.nip.io')), isFalse);
    expect(
      isUsableRelayAddress(Uri.parse('http://localhost.example')),
      isFalse,
    );
  });

  test('an address refused only for plain HTTP is told apart', () {
    for (final String address in <String>[
      'http://sync.satanshu.tech',
      'http://10.0.0.5:8080',
      'http://nas.local:8080/relay',
    ]) {
      expect(
        isPlainHttpRelayAddress(Uri.parse(address)),
        isTrue,
        reason: address,
      );
    }

    for (final String address in <String>[
      'https://sync.satanshu.tech',
      'http://127.0.0.1:8080',
      'http://sync.satanshu.tech@relay.attacker.test',
      'http://relay.attacker.test?sync.satanshu.tech',
      'http://${'a' * 64}.example.test',
      'ftp://sync.satanshu.tech',
    ]) {
      expect(
        isPlainHttpRelayAddress(Uri.parse(address)),
        isFalse,
        reason: address,
      );
    }
  });

  test('Android background uploads refuse plain HTTP beyond the device', () {
    final String item = File(
      'android/app/src/main/kotlin/dev/satanshumishra/field_notes/uploads/UploadItem.kt',
    ).readAsStringSync();

    expect(item, isNot(contains('url.startsWith("http://")')));
    expect(item, contains('isAllowedAddress(url)'));
  });
}
