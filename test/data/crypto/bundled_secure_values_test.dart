import 'dart:convert';

import 'package:field_notes/data/crypto/key_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _legacyKeys = <String>[
  'field_notes.sync.journal_keys',
  'field_notes.sync.device_keys',
  'field_notes.sync.recovery_public_keys',
  'field_notes.sync.account_id',
  'field_notes.sync.device_id',
  'field_notes.sync.upload_pass',
];

const Map<String, String> _sixOldItems = <String, String>{
  'field_notes.sync.journal_keys': 'v1',
  'field_notes.sync.device_keys': 'v2',
  'field_notes.sync.recovery_public_keys': 'v3',
  'field_notes.sync.account_id': 'v4',
  'field_notes.sync.device_id': 'v5',
  'field_notes.sync.upload_pass': 'v6',
};

KeyAccessException _refusal() => KeyAccessException(
  PlatformException(code: '-128', message: 'User canceled'),
);

bool _never(String key) => false;

bool _always(String key) => true;

final class _RefusingValues implements SecureValues {
  _RefusingValues(
    this.memory, {
    this.refusesRead = _never,
    this.refusesWrite = _never,
    this.refusesDelete = _never,
  });

  final MemorySecureValues memory;
  final bool Function(String key) refusesRead;
  final bool Function(String key) refusesWrite;
  final bool Function(String key) refusesDelete;
  bool refusing = true;

  @override
  Future<String?> read(String key) async {
    if (refusing && refusesRead(key)) {
      throw _refusal();
    }
    return memory.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (refusing && refusesWrite(key)) {
      throw _refusal();
    }
    await memory.write(key, value);
  }

  @override
  Future<void> delete(String key) async {
    if (refusing && refusesDelete(key)) {
      throw _refusal();
    }
    await memory.delete(key);
  }
}

final class _CountingValues implements SecureValues {
  _CountingValues(this.memory);

  final MemorySecureValues memory;
  Map<String, int> reads = const <String, int>{};

  @override
  Future<String?> read(String key) {
    reads = <String, int>{...reads, key: (reads[key] ?? 0) + 1};
    return memory.read(key);
  }

  @override
  Future<void> write(String key, String value) => memory.write(key, value);

  @override
  Future<void> delete(String key) => memory.delete(key);
}

final class _SlowWritingValues implements SecureValues {
  _SlowWritingValues(this.memory);

  final MemorySecureValues memory;

  @override
  Future<String?> read(String key) => memory.read(key);

  @override
  Future<void> write(String key, String value) async {
    await Future<void>.delayed(Duration.zero);
    await memory.write(key, value);
  }

  @override
  Future<void> delete(String key) => memory.delete(key);
}

Object? _bundleJson(MemorySecureValues memory) =>
    jsonDecode(memory.snapshot['field_notes.sync.bundle']!);

void main() {
  test('every key lives in the one bundle item', () async {
    final MemorySecureValues inner = MemorySecureValues();
    final BundledSecureValues values = BundledSecureValues(
      inner,
      legacyKeys: _legacyKeys,
    );

    await values.write('field_notes.sync.account_id', 'account-1');
    await values.write('field_notes.sync.upload_pass', '{"token":"p"}');
    await values.delete('field_notes.sync.upload_pass');

    expect(await values.read('field_notes.sync.account_id'), 'account-1');
    expect(await values.read('field_notes.sync.upload_pass'), isNull);
    expect(inner.snapshot.keys, <String>['field_notes.sync.bundle']);
    expect(_bundleJson(inner), <String, String>{
      'field_notes.sync.account_id': 'account-1',
    });
  });

  test('the six old items move into the bundle on first read', () async {
    final MemorySecureValues inner = MemorySecureValues(_sixOldItems);
    final BundledSecureValues values = BundledSecureValues(
      inner,
      legacyKeys: _legacyKeys,
    );

    expect(await values.read('field_notes.sync.journal_keys'), 'v1');

    expect(inner.snapshot.keys, <String>['field_notes.sync.bundle']);
    expect(_bundleJson(inner), <String, String>{
      'field_notes.sync.journal_keys': 'v1',
      'field_notes.sync.device_keys': 'v2',
      'field_notes.sync.recovery_public_keys': 'v3',
      'field_notes.sync.account_id': 'v4',
      'field_notes.sync.device_id': 'v5',
      'field_notes.sync.upload_pass': 'v6',
    });
  });

  test('a first write moves the old items before changing one', () async {
    final MemorySecureValues inner = MemorySecureValues(_sixOldItems);
    final BundledSecureValues values = BundledSecureValues(
      inner,
      legacyKeys: _legacyKeys,
    );

    await values.write('field_notes.sync.account_id', 'new');

    expect(inner.snapshot.keys, <String>['field_notes.sync.bundle']);
    expect(_bundleJson(inner), <String, String>{
      'field_notes.sync.journal_keys': 'v1',
      'field_notes.sync.device_keys': 'v2',
      'field_notes.sync.recovery_public_keys': 'v3',
      'field_notes.sync.account_id': 'new',
      'field_notes.sync.device_id': 'v5',
      'field_notes.sync.upload_pass': 'v6',
    });
  });

  test('a refused bundle read changes nothing', () async {
    final MemorySecureValues memory = MemorySecureValues(<String, String>{
      'field_notes.sync.bundle': '{"field_notes.sync.account_id":"a"}',
    });
    final BundledSecureValues values = BundledSecureValues(
      _RefusingValues(memory, refusesRead: _always),
      legacyKeys: _legacyKeys,
    );

    await expectLater(
      values.read('field_notes.sync.account_id'),
      throwsA(isA<KeyAccessException>()),
    );
    await expectLater(
      values.write('field_notes.sync.account_id', 'b'),
      throwsA(isA<KeyAccessException>()),
    );

    expect(memory.snapshot, <String, String>{
      'field_notes.sync.bundle': '{"field_notes.sync.account_id":"a"}',
    });
  });

  test('a refused old item read moves nothing', () async {
    final MemorySecureValues memory = MemorySecureValues(_sixOldItems);
    final _RefusingValues inner = _RefusingValues(
      memory,
      refusesRead: (String key) => key == 'field_notes.sync.device_id',
    );
    final BundledSecureValues values = BundledSecureValues(
      inner,
      legacyKeys: _legacyKeys,
    );

    await expectLater(
      values.read('field_notes.sync.journal_keys'),
      throwsA(isA<KeyAccessException>()),
    );
    expect(memory.snapshot, <String, String>{
      'field_notes.sync.journal_keys': 'v1',
      'field_notes.sync.device_keys': 'v2',
      'field_notes.sync.recovery_public_keys': 'v3',
      'field_notes.sync.account_id': 'v4',
      'field_notes.sync.device_id': 'v5',
      'field_notes.sync.upload_pass': 'v6',
    });

    inner.refusing = false;

    expect(await values.read('field_notes.sync.journal_keys'), 'v1');
    expect(memory.snapshot.keys, <String>['field_notes.sync.bundle']);
    expect(_bundleJson(memory), <String, String>{
      'field_notes.sync.journal_keys': 'v1',
      'field_notes.sync.device_keys': 'v2',
      'field_notes.sync.recovery_public_keys': 'v3',
      'field_notes.sync.account_id': 'v4',
      'field_notes.sync.device_id': 'v5',
      'field_notes.sync.upload_pass': 'v6',
    });
  });

  test('a refused bundle write keeps the old items', () async {
    final MemorySecureValues memory = MemorySecureValues(_sixOldItems);
    final BundledSecureValues values = BundledSecureValues(
      _RefusingValues(memory, refusesWrite: _always),
      legacyKeys: _legacyKeys,
    );

    await expectLater(
      values.read('field_notes.sync.journal_keys'),
      throwsA(isA<KeyAccessException>()),
    );

    expect(memory.snapshot, <String, String>{
      'field_notes.sync.journal_keys': 'v1',
      'field_notes.sync.device_keys': 'v2',
      'field_notes.sync.recovery_public_keys': 'v3',
      'field_notes.sync.account_id': 'v4',
      'field_notes.sync.device_id': 'v5',
      'field_notes.sync.upload_pass': 'v6',
    });
  });

  test('a refused old item delete still answers from the bundle', () async {
    final MemorySecureValues memory = MemorySecureValues(_sixOldItems);
    final BundledSecureValues values = BundledSecureValues(
      _RefusingValues(memory, refusesDelete: _always),
      legacyKeys: _legacyKeys,
    );

    expect(await values.read('field_notes.sync.journal_keys'), 'v1');

    expect(_bundleJson(memory), <String, String>{
      'field_notes.sync.journal_keys': 'v1',
      'field_notes.sync.device_keys': 'v2',
      'field_notes.sync.recovery_public_keys': 'v3',
      'field_notes.sync.account_id': 'v4',
      'field_notes.sync.device_id': 'v5',
      'field_notes.sync.upload_pass': 'v6',
    });
    expect(
      memory.snapshot,
      containsPair('field_notes.sync.journal_keys', 'v1'),
    );
    expect(memory.snapshot, containsPair('field_notes.sync.device_keys', 'v2'));
    expect(
      memory.snapshot,
      containsPair('field_notes.sync.recovery_public_keys', 'v3'),
    );
    expect(memory.snapshot, containsPair('field_notes.sync.account_id', 'v4'));
    expect(memory.snapshot, containsPair('field_notes.sync.device_id', 'v5'));
    expect(memory.snapshot, containsPair('field_notes.sync.upload_pass', 'v6'));
  });

  test('a wiped store stays wiped', () async {
    final MemorySecureValues memory = MemorySecureValues(_sixOldItems);
    final _RefusingValues inner = _RefusingValues(
      memory,
      refusesDelete: _sixOldItems.containsKey,
    );
    final BundledSecureValues values = BundledSecureValues(
      inner,
      legacyKeys: _legacyKeys,
    );

    expect(await values.read('field_notes.sync.journal_keys'), 'v1');
    await values.delete('field_notes.sync.journal_keys');
    await values.delete('field_notes.sync.device_keys');
    await values.delete('field_notes.sync.recovery_public_keys');
    await values.delete('field_notes.sync.account_id');
    await values.delete('field_notes.sync.device_id');
    await values.delete('field_notes.sync.upload_pass');

    expect(await values.read('field_notes.sync.journal_keys'), isNull);
    expect(await values.read('field_notes.sync.device_keys'), isNull);
    expect(await values.read('field_notes.sync.recovery_public_keys'), isNull);
    expect(await values.read('field_notes.sync.account_id'), isNull);
    expect(await values.read('field_notes.sync.device_id'), isNull);
    expect(await values.read('field_notes.sync.upload_pass'), isNull);
    expect(memory.snapshot['field_notes.sync.bundle'], '{}');

    final BundledSecureValues reopened = BundledSecureValues(
      inner,
      legacyKeys: _legacyKeys,
    );

    expect(await reopened.read('field_notes.sync.journal_keys'), isNull);
  });

  test('changes made together all land', () async {
    final MemorySecureValues memory = MemorySecureValues();
    final _SlowWritingValues inner = _SlowWritingValues(memory);
    final BundledSecureValues values = BundledSecureValues(
      inner,
      legacyKeys: _legacyKeys,
    );

    await Future.wait(<Future<void>>[
      values.write('field_notes.sync.account_id', 'a'),
      values.write('field_notes.sync.device_id', 'b'),
      values.write('field_notes.sync.upload_pass', 'c'),
    ]);

    final BundledSecureValues reopened = BundledSecureValues(
      inner,
      legacyKeys: _legacyKeys,
    );
    expect(await reopened.read('field_notes.sync.account_id'), 'a');
    expect(await reopened.read('field_notes.sync.device_id'), 'b');
    expect(await reopened.read('field_notes.sync.upload_pass'), 'c');
  });

  test('an unreadable bundle is reported and kept', () async {
    final MemorySecureValues inner = MemorySecureValues(<String, String>{
      'field_notes.sync.bundle': '[1,2]',
    });
    final BundledSecureValues values = BundledSecureValues(
      inner,
      legacyKeys: _legacyKeys,
    );

    await expectLater(
      values.read('field_notes.sync.account_id'),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      values.write('field_notes.sync.account_id', 'a'),
      throwsA(isA<FormatException>()),
    );

    expect(inner.snapshot['field_notes.sync.bundle'], '[1,2]');
  });

  test(
    'a bundle with a non-text value is reported without its contents',
    () async {
      final BundledSecureValues nonText = BundledSecureValues(
        MemorySecureValues(<String, String>{
          'field_notes.sync.bundle': '{"field_notes.sync.account_id":"secret-value","field_notes.sync.device_id":5}',
        }),
        legacyKeys: _legacyKeys,
      );
      final BundledSecureValues invalidJson = BundledSecureValues(
        MemorySecureValues(<String, String>{
          'field_notes.sync.bundle': '{"secret-value',
        }),
        legacyKeys: _legacyKeys,
      );
      final Matcher namesNoStoredText = throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.toString(),
          'toString',
          isNot(contains('secret-value')),
        ),
      );

      await expectLater(
        nonText.read('field_notes.sync.account_id'),
        namesNoStoredText,
      );
      await expectLater(
        invalidJson.read('field_notes.sync.account_id'),
        namesNoStoredText,
      );
    },
  );

  test('one keychain read per run', () async {
    final _CountingValues counting = _CountingValues(
      MemorySecureValues(<String, String>{
        'field_notes.sync.bundle': jsonEncode(_sixOldItems),
      }),
    );
    final BundledSecureValues values = BundledSecureValues(
      CachedSecureValues(counting),
      legacyKeys: _legacyKeys,
    );

    for (int round = 0; round < 2; round += 1) {
      for (final String key in _legacyKeys) {
        await values.read(key);
      }
    }

    expect(counting.reads, <String, int>{'field_notes.sync.bundle': 1});
  });
}
