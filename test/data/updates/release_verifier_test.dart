import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:field_notes/data/updates/release_verifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium.dart';

const String _apkName = 'field-notes-1.2.0-android.apk';
const String _dmgName = 'field-notes-1.2.0-macos.dmg';

final class _Signer {
  _Signer() : _pair = loadSodium().crypto.sign.keyPair();

  final KeyPair _pair;

  Uint8List get publicKey => _pair.publicKey;

  Uint8List signatureOf(List<int> message) => loadSodium().crypto.sign.detached(
    message: Uint8List.fromList(message),
    secretKey: _pair.secretKey,
  );

  String signatureText(List<int> message) =>
      base64.encode(signatureOf(message));

  void dispose() => _pair.dispose();
}

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 31 + seed) % 256);

String _sumsFor(Map<String, List<int>> files) => <String>[
  for (final MapEntry<String, List<int>> entry in files.entries)
    '${sha256.convert(entry.value)}  ${entry.key}',
].map((String line) => '$line\n').join();

List<int> _flipped(List<int> bytes, int index) => <int>[
  for (int at = 0; at < bytes.length; at++)
    at == index ? bytes[at] ^ 0x01 : bytes[at],
];

void main() {
  late Directory folder;
  late _Signer signer;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('release_verifier_test');
    signer = _Signer();
  });

  tearDown(() {
    signer.dispose();
    folder.deleteSync(recursive: true);
  });

  test(
    'a download installs only with a valid signature and checksum',
    () async {
      final List<int> apk = _bytes(70000, 7);
      final List<int> dmg = _bytes(4096, 3);
      final File apkFile = File('${folder.path}/$_apkName')
        ..writeAsBytesSync(apk);
      final List<int> sums = utf8.encode(
        _sumsFor(<String, List<int>>{_dmgName: dmg, _apkName: apk}),
      );
      final String signature = signer.signatureText(sums);
      final ReleaseVerifier verifier = ReleaseVerifier(signer.publicKey);

      Future<bool> check({
        ReleaseVerifier? using,
        List<int>? sumsBytes,
        String? signatureText,
        String fileName = _apkName,
        File? file,
      }) => (using ?? verifier).verify(
        sums: sumsBytes ?? sums,
        signature: signatureText ?? signature,
        fileName: fileName,
        file: file ?? apkFile,
      );

      expect(await check(), isTrue);
      expect(await check(signatureText: '$signature\n'), isTrue);
      expect(
        await ReleaseVerifier.fromBase64(base64.encode(signer.publicKey))!
            .verify(
              sums: sums,
              signature: signature,
              fileName: _apkName,
              file: apkFile,
            ),
        isTrue,
      );

      final _Signer stranger = _Signer();
      addTearDown(stranger.dispose);
      expect(await check(using: ReleaseVerifier(stranger.publicKey)), isFalse);
      expect(await check(signatureText: stranger.signatureText(sums)), isFalse);

      final List<int> alteredSums = _flipped(sums, 10);
      expect(await check(sumsBytes: alteredSums), isFalse);
      expect(verifier.sumsAreSigned(alteredSums, signature), isFalse);
      expect(await check(sumsBytes: <int>[...sums, 0x0a]), isFalse);

      final File alteredApk = File('${folder.path}/altered/$_apkName')
        ..createSync(recursive: true)
        ..writeAsBytesSync(_flipped(apk, 69999));
      expect(await check(file: alteredApk), isFalse);
      final File shortApk = File('${folder.path}/short/$_apkName')
        ..createSync(recursive: true)
        ..writeAsBytesSync(apk.sublist(0, apk.length - 1));
      expect(await check(file: shortApk), isFalse);
      expect(
        await check(file: File('${folder.path}/missing/$_apkName')),
        isFalse,
      );

      final List<int> withoutApk = utf8.encode(
        _sumsFor(<String, List<int>>{_dmgName: dmg}),
      );
      expect(
        await check(
          sumsBytes: withoutApk,
          signatureText: signer.signatureText(withoutApk),
        ),
        isFalse,
      );
      expect(await check(fileName: 'field-notes-1.2.0-android.ap'), isFalse);
      expect(
        await check(fileName: 'field-notes-1.2.0-android.apk.bak'),
        isFalse,
      );
      expect(await check(fileName: ' $_apkName'), isFalse);
      expect(
        await check(
          sumsBytes: <int>[],
          signatureText: signer.signatureText(<int>[]),
        ),
        isFalse,
      );

      final Uint8List fullSignature = signer.signatureOf(sums);
      expect(
        await check(signatureText: base64.encode(fullSignature.sublist(0, 63))),
        isFalse,
      );
      expect(
        await check(
          signatureText: signature.substring(0, signature.length - 4),
        ),
        isFalse,
      );
      expect(
        await check(signatureText: base64.encode(_flipped(fullSignature, 0))),
        isFalse,
      );
      expect(await check(signatureText: ''), isFalse);
      expect(await check(signatureText: 'not a signature!'), isFalse);
      expect(
        await check(signatureText: base64.encode(List<int>.filled(64, 0))),
        isFalse,
      );

      expect(updatePublicKeyBase64, isEmpty);
      expect(ReleaseVerifier.fromBase64(updatePublicKeyBase64), isNull);
      expect(ReleaseVerifier.fromBase64(''), isNull);
      expect(ReleaseVerifier.fromBase64('   '), isNull);
      expect(ReleaseVerifier.fromBase64('not base64 at all!'), isNull);
      expect(
        ReleaseVerifier.fromBase64(
          base64.encode(signer.publicKey.sublist(0, 31)),
        ),
        isNull,
      );
      expect(
        ReleaseVerifier.fromBase64(
          base64.encode(<int>[...signer.publicKey, 0]),
        ),
        isNull,
      );
      expect(() => ReleaseVerifier(<int>[]), throwsArgumentError);
      expect(
        () => ReleaseVerifier(signer.publicKey.sublist(0, 31)),
        throwsArgumentError,
      );
    },
  );

  test('the sums file names each file by its exact name', () async {
    final List<int> apk = _bytes(512, 11);
    final String digest = sha256.convert(apk).toString();
    final ReleaseVerifier verifier = ReleaseVerifier(signer.publicKey);
    final String sums =
        '${'0' * 64}  $_dmgName\r\n'
        '${digest.toUpperCase()} *$_apkName\r\n'
        'not a sums line\n';

    expect(verifier.expectedDigest(sums, _apkName), digest);
    expect(verifier.expectedDigest(sums, _dmgName), '0' * 64);
    expect(verifier.expectedDigest(sums, 'field-notes'), isNull);
    expect(verifier.expectedDigest('$digest $_apkName\n', _apkName), isNull);
    expect(
      verifier.expectedDigest('${digest}0  $_apkName\n', _apkName),
      isNull,
    );
    expect(
      verifier.expectedDigest(
        '$digest  $_apkName\n${'1' * 64}  $_apkName\n',
        _apkName,
      ),
      isNull,
    );

    final File file = File('${folder.path}/$_apkName')..writeAsBytesSync(apk);
    expect(await verifier.fileMatches(file, digest), isTrue);
    expect(await verifier.fileMatches(file, digest.toUpperCase()), isTrue);
    expect(await verifier.fileMatches(file, '0' * 64), isFalse);
    expect(await verifier.fileMatches(file, 'abc'), isFalse);
  });
}
