import 'dart:io';
import 'dart:typed_data';

import 'package:field_notes/data/crypto/file_cipher.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('file_cipher_test_');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  File file(String name) => File(p.join(root.path, name));

  Future<File> writeFile(String name, List<int> bytes) async {
    final File target = file(name);
    await target.writeAsBytes(bytes, flush: true);
    return target;
  }

  Future<void> expectRefused(File source, JournalKeys keys) async {
    final File destination = file('refused.out');
    await expectLater(
      FileCipher.decryptFile(source, destination, keys),
      throwsA(isA<CryptoException>()),
    );
    expect(await destination.exists(), isFalse);
  }

  test('a truncated or reordered file is refused', () async {
    final JournalKeys keys = JournalKeys.generate();
    final Uint8List plain = randomBytes(2 * fileChunkBytes + 12345);
    final File source = await writeFile('video.mp4', plain);
    final File sealed = file('video.fnb');

    await FileCipher(keys).encryptFile(source, sealed, 1);
    final Uint8List cipherBytes = await sealed.readAsBytes();
    final int header = fileHeaderBytes();
    final int chunk = fileChunkBytes + 17;

    expect(cipherBytes.length, encryptedFileLength(plain.length));
    expect(String.fromCharCodes(cipherBytes.sublist(0, 4)), 'FNB1');
    expect(cipherBytes.sublist(4, 8), <int>[0, 0, 0, 1]);
    expect(await FileCipher.epochOf(sealed), 1);

    final File opened = file('video.out');
    await FileCipher.decryptFile(sealed, opened, keys);
    expect(await opened.readAsBytes(), plain);

    await expectRefused(
      await writeFile(
        'cut-mid-chunk.fnb',
        cipherBytes.sublist(0, cipherBytes.length - 100),
      ),
      keys,
    );
    await expectRefused(
      await writeFile(
        'cut-at-boundary.fnb',
        cipherBytes.sublist(0, header + 2 * chunk),
      ),
      keys,
    );
    await expectRefused(
      await writeFile('reordered.fnb', <int>[
        ...cipherBytes.sublist(0, header),
        ...cipherBytes.sublist(header + chunk, header + 2 * chunk),
        ...cipherBytes.sublist(header, header + chunk),
        ...cipherBytes.sublist(header + 2 * chunk),
      ]),
      keys,
    );
    await expectRefused(
      await writeFile(
        'altered.fnb',
        Uint8List.fromList(cipherBytes)..[header + chunk + 99] ^= 0x01,
      ),
      keys,
    );
    await expectRefused(
      await writeFile('appended.fnb', <int>[
        ...cipherBytes,
        ...cipherBytes.sublist(header, header + chunk),
      ]),
      keys,
    );

    final JournalKeys rotated = keys.withEpoch(2, JournalKeys.newEpochKey());
    final File afterRotation = file('after-rotation.out');
    await FileCipher.decryptFile(sealed, afterRotation, rotated);
    expect(await afterRotation.readAsBytes(), plain);
  });

  test('a file sealed under a later epoch needs that epoch', () async {
    final JournalKeys keys = JournalKeys.generate();
    final JournalKeys rotated = keys.withEpoch(2, JournalKeys.newEpochKey());
    final Uint8List plain = randomBytes(4096);
    final File source = await writeFile('voice.m4a', plain);
    final File sealed = file('voice.fnb');

    await FileCipher(rotated).encryptFile(source, sealed, 2);

    expect(await FileCipher.epochOf(sealed), 2);
    await expectLater(
      FileCipher.decryptFile(sealed, file('voice.out'), keys),
      throwsA(isA<UnknownEpochException>()),
    );
    final File opened = file('voice.out');
    await FileCipher.decryptFile(sealed, opened, rotated);
    expect(await opened.readAsBytes(), plain);

    final Uint8List relabelled = Uint8List.fromList(await sealed.readAsBytes())
      ..[7] = 1;
    await expectRefused(await writeFile('relabelled.fnb', relabelled), rotated);
  });

  test('an empty file and an exact chunk round-trip', () async {
    final JournalKeys keys = JournalKeys.generate();
    for (final int length in <int>[0, fileChunkBytes]) {
      final Uint8List plain = length == 0 ? Uint8List(0) : randomBytes(length);
      final File source = await writeFile('plain-$length', plain);
      final File sealed = file('sealed-$length');
      final File opened = file('opened-$length');

      await FileCipher(keys).encryptFile(source, sealed, 1);
      await FileCipher.decryptFile(sealed, opened, keys);

      expect(await sealed.length(), encryptedFileLength(length));
      expect(await opened.readAsBytes(), plain);
    }
  });
}
