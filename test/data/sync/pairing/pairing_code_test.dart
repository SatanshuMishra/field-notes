import 'dart:typed_data';

import 'package:field_notes/data/crypto/bip39_english.dart';
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/sync/pairing/pairing_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_protocol/sync_protocol.dart';

DeviceRegistration _registration(DeviceKeys device, List<int> name) =>
    device.registration(
      certificate: Uint8List.fromList(List<int>.filled(64, 7)),
      encryptedName: Uint8List.fromList(name),
    );

void main() {
  final Uri relayUrl = Uri.parse('https://sync.example.test');

  test('the 8 words and the QR payload carry the same secret', () {
    final PairingCode code = PairingCode.generate(relayUrl: relayUrl);

    expect(code.secret, hasLength(11));
    expect(code.words, hasLength(8));
    expect(code.words.every(bip39English.contains), isTrue);
    expect(
      code.qrPayload,
      'fieldnotes-pair:https://sync.example.test#${encodeBase64Url(code.secret)}',
    );

    final String typed = code.words
        .map((String word) => word.toUpperCase())
        .join('   ');
    final PairingCode fromWords = PairingCode.parse('  $typed\n');
    final PairingCode fromQr = PairingCode.parse(code.qrPayload);

    expect(fromWords.secret, code.secret);
    expect(fromWords.relayUrl, isNull);
    expect(fromQr.secret, code.secret);
    expect(fromQr.relayUrl, relayUrl);
    for (final PairingCode parsed in <PairingCode>[fromWords, fromQr]) {
      expect(parsed.mailboxId, code.mailboxId);
      expect(parsed.mailboxToken, code.mailboxToken);
      expect(parsed.pairingKey, code.pairingKey);
    }
  });

  test('the mailbox id, token and pairing key are separate and opaque', () {
    final PairingCode code = PairingCode.generate(relayUrl: relayUrl);
    final PairingCode other = PairingCode.generate(relayUrl: relayUrl);

    expect(isSyncId(code.mailboxId), isTrue);
    expect(code.mailboxToken, hasLength(43));
    expect(code.pairingKey, hasLength(32));
    expect(code.mailboxToken, isNot(code.mailboxId));
    expect(decodeBase64Url(code.mailboxToken), isNot(code.pairingKey));
    expect(code.mailboxToken, isNot(contains(encodeBase64Url(code.secret))));
    expect(other.mailboxId, isNot(code.mailboxId));
    expect(other.mailboxToken, isNot(code.mailboxToken));
    expect(other.pairingKey, isNot(code.pairingKey));
  });

  test('the authenticator binds the joining device to the secret', () {
    final PairingCode code = PairingCode.generate(relayUrl: relayUrl);
    final DeviceKeys device = DeviceKeys.generate();
    final DeviceRegistration registration = _registration(device, <int>[1]);
    final PairingJoinRequest honest = PairingJoinRequest(
      device: registration,
      authenticator: code.authenticatorFor(registration),
    );

    expect(code.authenticates(honest), isTrue);
    expect(
      code.authenticates(
        PairingJoinRequest(
          device: _registration(DeviceKeys.generate(), <int>[1]),
          authenticator: honest.authenticator,
        ),
      ),
      isFalse,
    );
    expect(
      code.authenticates(
        PairingJoinRequest(
          device: _registration(device, <int>[2]),
          authenticator: honest.authenticator,
        ),
      ),
      isFalse,
    );
    expect(
      code.authenticates(
        PairingJoinRequest(
          device: registration,
          authenticator: PairingCode.generate().authenticatorFor(registration),
        ),
      ),
      isFalse,
    );
  });

  test('a short, unknown or broken code is refused', () {
    final PairingCode code = PairingCode.generate(relayUrl: relayUrl);

    expect(
      () => PairingCode.parse(code.words.take(7).join(' ')),
      throwsA(isA<PairingCodeException>()),
    );
    expect(
      () => PairingCode.parse(
        (<String>[...code.words]..[2] = 'notaword').join(' '),
      ),
      throwsA(isA<PairingCodeException>()),
    );
    expect(
      () => PairingCode.parse('fieldnotes-pair:https://sync.example.test'),
      throwsA(isA<PairingCodeException>()),
    );
    expect(
      () => PairingCode.parse('fieldnotes-pair:https://sync.example.test#AAAA'),
      throwsA(isA<PairingCodeException>()),
    );
    expect(
      () => PairingCode.parse(
        'fieldnotes-pair:no-address#${encodeBase64Url(code.secret)}',
      ),
      throwsA(isA<PairingCodeException>()),
    );
  });

  test('a QR code whose address hides its real server is refused', () {
    final String secret = encodeBase64Url(
      PairingCode.generate(relayUrl: relayUrl).secret,
    );

    for (final String address in <String>[
      'https://sync.example.test@relay.attacker.test',
      'https://sync.example.test:pw@relay.attacker.test',
      'https://relay.attacker.test?sync.example.test',
      'ftp://sync.example.test',
      'wss://sync.example.test',
      'https://sync.ex\u0430mple.test',
      'https://${'a' * 64}.example.test',
      'https://sync.example.test/${'a' * 120}',
    ]) {
      expect(
        () => PairingCode.parse('fieldnotes-pair:$address#$secret'),
        throwsA(isA<PairingCodeException>()),
        reason: address,
      );
    }
    expect(
      PairingCode.parse(
        'fieldnotes-pair:https://sync.example.test:8443/relay#$secret',
      ).relayUrl,
      Uri.parse('https://sync.example.test:8443/relay'),
    );
  });
}
