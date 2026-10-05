import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:sodium/sodium.dart';

const int fileChunkBytes = 4 * 1024 * 1024;
const String fileMagic = 'FNB1';
const int filePrefixBytes = 8;

Uint8List filePrefix(int epoch) {
  final BytesBuilder builder = BytesBuilder(copy: false)
    ..add(ascii.encode(fileMagic))
    ..add((ByteData(4)..setUint32(0, epoch, Endian.big)).buffer.asUint8List());
  return builder.takeBytes();
}

int fileHeaderBytes() =>
    filePrefixBytes + loadSodium().crypto.secretStream.headerBytes;

int fileChunkCount(int plainLength) =>
    plainLength == 0 ? 1 : (plainLength + fileChunkBytes - 1) ~/ fileChunkBytes;

int encryptedFileLength(int plainLength) =>
    fileHeaderBytes() +
    plainLength +
    fileChunkCount(plainLength) * loadSodium().crypto.secretStream.aBytes;

final class FileCipher {
  const FileCipher(this.keys);

  final JournalKeys keys;

  Future<void> encryptFile(File source, File destination, int epoch) async {
    final Uint8List subKey = keys.fileSubKey(epoch);
    final Uint8List prefix = filePrefix(epoch);
    final RandomAccessFile input = await source.open();
    RandomAccessFile? output;
    bool done = false;
    try {
      final int length = await input.length();
      final RandomAccessFile sink = await destination.open(
        mode: FileMode.write,
      );
      output = sink;
      await sink.writeFrom(prefix);
      await useSecureKeyAsync(subKey, (SecureKey key) async {
        await for (final SecretStreamCipherMessage message
            in loadSodium().crypto.secretStream.pushEx(
              messageStream: _plainChunks(input, length, prefix),
              key: key,
            )) {
          await sink.writeFrom(message.message);
        }
      });
      await sink.flush();
      done = true;
    } finally {
      await input.close();
      await output?.close();
      if (!done && await destination.exists()) {
        await destination.delete();
      }
    }
  }

  static Future<int> epochOf(File source) async {
    final RandomAccessFile input = await source.open();
    try {
      return _readEpoch(await _readExactly(input, filePrefixBytes));
    } finally {
      await input.close();
    }
  }

  static Future<void> decryptFile(
    File source,
    File destination,
    JournalKeys keys,
  ) async {
    final SecretStream secretStream = loadSodium().crypto.secretStream;
    final RandomAccessFile input = await source.open();
    RandomAccessFile? output;
    bool done = false;
    try {
      final int length = await input.length();
      if (length < fileHeaderBytes() + secretStream.aBytes) {
        throw const CryptoException('The file is too short');
      }
      final Uint8List prefix = await _readExactly(input, filePrefixBytes);
      final Uint8List subKey = keys.fileSubKey(_readEpoch(prefix));
      final Uint8List header = await _readExactly(
        input,
        secretStream.headerBytes,
      );
      final int cipherChunkBytes = fileChunkBytes + secretStream.aBytes;
      final int body = length - fileHeaderBytes();
      final int chunks = (body + cipherChunkBytes - 1) ~/ cipherChunkBytes;
      final RandomAccessFile sink = await destination.open(
        mode: FileMode.write,
      );
      output = sink;
      await useSecureKeyAsync(subKey, (SecureKey key) async {
        final StreamController<SecretStreamCipherMessage> cipher =
            StreamController<SecretStreamCipherMessage>();
        final StreamIterator<SecretStreamPlainMessage> plain =
            StreamIterator<SecretStreamPlainMessage>(
              secretStream.pullEx(cipherStream: cipher.stream, key: key),
            );
        try {
          cipher.add(SecretStreamCipherMessage(header));
          for (int index = 0; index < chunks; index++) {
            final bool last = index == chunks - 1;
            final int size = last
                ? body - index * cipherChunkBytes
                : cipherChunkBytes;
            if (size < secretStream.aBytes ||
                (size == secretStream.aBytes && index > 0)) {
              throw const CryptoException('The file ended early');
            }
            cipher.add(
              SecretStreamCipherMessage(
                await _readExactly(input, size),
                additionalData: prefix,
              ),
            );
            if (!await plain.moveNext()) {
              throw const CryptoException('The file ended early');
            }
            final SecretStreamPlainMessage message = plain.current;
            if (last != (message.tag == SecretStreamMessageTag.finalPush)) {
              throw const CryptoException('The file chunks are out of place');
            }
            await sink.writeFrom(message.message);
          }
        } on SodiumException catch (error) {
          throw CryptoException('The file could not be opened', error);
        } on StreamClosedEarlyException catch (error) {
          throw CryptoException('The file ended early', error);
        } on InvalidHeaderException catch (error) {
          throw CryptoException('The file header is invalid', error);
        } on ArgumentError catch (error) {
          throw CryptoException('The file could not be opened', error);
        } finally {
          await plain.cancel();
          await cipher.close();
        }
      });
      await sink.flush();
      done = true;
    } finally {
      await input.close();
      await output?.close();
      if (!done && await destination.exists()) {
        await destination.delete();
      }
    }
  }

  static Stream<SecretStreamPlainMessage> _plainChunks(
    RandomAccessFile input,
    int length,
    Uint8List prefix,
  ) async* {
    final int chunks = fileChunkCount(length);
    for (int index = 0; index < chunks; index++) {
      final bool last = index == chunks - 1;
      yield SecretStreamPlainMessage(
        await _readExactly(
          input,
          last ? length - index * fileChunkBytes : fileChunkBytes,
        ),
        additionalData: prefix,
        tag: last
            ? SecretStreamMessageTag.finalPush
            : SecretStreamMessageTag.message,
      );
    }
  }

  static int _readEpoch(Uint8List prefix) {
    if (ascii.decode(prefix.sublist(0, 4), allowInvalid: true) != fileMagic) {
      throw const CryptoException('Not an encrypted Field Notes file');
    }
    return ByteData.sublistView(prefix, 4, 8).getUint32(0, Endian.big);
  }

  static Future<Uint8List> _readExactly(
    RandomAccessFile input,
    int size,
  ) async {
    final BytesBuilder builder = BytesBuilder(copy: false);
    int remaining = size;
    while (remaining > 0) {
      final Uint8List chunk = await input.read(remaining);
      if (chunk.isEmpty) {
        throw const CryptoException('The file ended early');
      }
      builder.add(chunk);
      remaining -= chunk.length;
    }
    return builder.takeBytes();
  }
}
