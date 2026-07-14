import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/data/media/content_hash.dart';

void main() {
  group('sha256Hex', () {
    test('matches known SHA-256 vectors', () {
      expect(
        sha256Hex(utf8.encode('')),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('is 64 lowercase hex characters', () {
      final digest = sha256Hex([1, 2, 3, 4]);
      expect(digest.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(digest), isTrue);
    });
  });

  group('sha256HexOfStream', () {
    test('agrees with sha256Hex over the same content', () async {
      final bytes = List<int>.generate(5000, (i) => i % 256);
      final streamed = await sha256HexOfStream(Stream.value(bytes));
      expect(streamed, sha256Hex(bytes));
    });

    test('folds multiple chunks into one digest', () async {
      final whole = List<int>.generate(300, (i) => i % 256);
      final chunked = Stream<List<int>>.fromIterable([
        whole.sublist(0, 100),
        whole.sublist(100, 250),
        whole.sublist(250),
      ]);
      expect(await sha256HexOfStream(chunked), sha256Hex(whole));
    });
  });
}
