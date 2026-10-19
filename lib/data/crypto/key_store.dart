import 'dart:convert';

import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/recovery_phrase.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sync_protocol/sync_protocol.dart';

class KeyAccessException implements Exception {
  const KeyAccessException(this.cause);

  final Object cause;

  @override
  String toString() => 'KeyAccessException: $cause';
}

abstract interface class SecureValues {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class PlatformSecureValues implements SecureValues {
  const PlatformSecureValues([this._storage = defaultStorage]);

  static const FlutterSecureStorage defaultStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _guarded(() => _storage.read(key: key));

  @override
  Future<void> write(String key, String value) =>
      _guarded(() => _storage.write(key: key, value: value));

  @override
  Future<void> delete(String key) => _guarded(() => _storage.delete(key: key));

  static Future<T> _guarded<T>(Future<T> Function() access) async {
    try {
      return await access();
    } on PlatformException catch (error) {
      throw KeyAccessException(error);
    }
  }
}

final class CachedSecureValues implements SecureValues {
  CachedSecureValues(this._inner);

  final SecureValues _inner;
  final Map<String, String?> _known = <String, String?>{};
  final Map<String, Future<String?>> _reading = <String, Future<String?>>{};

  @override
  Future<String?> read(String key) async {
    if (_known.containsKey(key)) {
      return _known[key];
    }
    final Future<String?> reading = _reading[key] ??= _inner
        .read(key)
        .whenComplete(() {
          _reading.remove(key);
        });
    final String? value = await reading;
    _known[key] = value;
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    await _inner.write(key, value);
    _known[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    await _inner.delete(key);
    _known[key] = null;
  }
}

final class MemorySecureValues implements SecureValues {
  MemorySecureValues([Map<String, String> initial = const <String, String>{}])
    : _values = Map<String, String>.of(initial);

  final Map<String, String> _values;

  Map<String, String> get snapshot => Map<String, String>.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

final class BundledSecureValues implements SecureValues {
  BundledSecureValues(this._inner, {required List<String> legacyKeys})
    : _legacyKeys = List<String>.unmodifiable(legacyKeys);

  static const String bundleKey = 'field_notes.sync.bundle';

  static const FormatException _unreadable = FormatException(
    'Unreadable key bundle',
  );

  final SecureValues _inner;
  final List<String> _legacyKeys;
  Future<void> _previous = Future<void>.value();

  @override
  Future<String?> read(String key) => _inTurn(() async => (await _load())[key]);

  @override
  Future<void> write(String key, String value) => _inTurn(() async {
    final Map<String, String> values = await _load();
    await _store(<String, String>{...values, key: value});
  });

  @override
  Future<void> delete(String key) => _inTurn(() async {
    final Map<String, String> values = await _load();
    await _store(<String, String>{
      for (final MapEntry<String, String> entry in values.entries)
        if (entry.key != key) entry.key: entry.value,
    });
  });

  Future<T> _inTurn<T>(Future<T> Function() operation) {
    final Future<T> result = _previous.then((_) => operation());
    _previous = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Map<String, String>> _load() async {
    final String? stored = await _inner.read(bundleKey);
    if (stored != null) {
      return _parse(stored);
    }
    final Map<String, String> found = await _readLegacy();
    if (found.isEmpty) {
      return found;
    }
    await _store(found);
    for (final String key in found.keys) {
      await _deleteLegacy(key);
    }
    return found;
  }

  Future<Map<String, String>> _readLegacy() async {
    Map<String, String> found = const <String, String>{};
    for (final String key in _legacyKeys) {
      final String? value = await _inner.read(key);
      if (value != null) {
        found = <String, String>{...found, key: value};
      }
    }
    return found;
  }

  Future<void> _deleteLegacy(String key) => _inner
      .delete(key)
      .catchError(
        (Object _) {},
        test: (Object error) => error is KeyAccessException,
      );

  Future<void> _store(Map<String, String> values) =>
      _inner.write(bundleKey, jsonEncode(values));

  static Map<String, String> _parse(String stored) {
    final Map<String, Object?> decoded;
    try {
      decoded = decodeJsonObject(stored);
    } on FormatException {
      throw _unreadable;
    }
    return Map<String, String>.unmodifiable(<String, String>{
      for (final MapEntry<String, Object?> entry in decoded.entries)
        entry.key: switch (entry.value) {
          final String text => text,
          _ => throw _unreadable,
        },
    });
  }
}

final class UploadPass {
  UploadPass({required this.token, required DateTime expiresAt})
    : expiresAt = expiresAt.toUtc();

  final String token;
  final DateTime expiresAt;

  bool isValidAt(DateTime now) => expiresAt.isAfter(now);
}

final class KeyStore {
  const KeyStore([this._values = const PlatformSecureValues()]);

  static const String journalKeysKey = 'field_notes.sync.journal_keys';
  static const String deviceKeysKey = 'field_notes.sync.device_keys';
  static const String recoveryKeysKey = 'field_notes.sync.recovery_public_keys';
  static const String accountIdKey = 'field_notes.sync.account_id';
  static const String deviceIdKey = 'field_notes.sync.device_id';
  static const String uploadPassKey = 'field_notes.sync.upload_pass';

  static const List<String> allKeys = <String>[
    journalKeysKey,
    deviceKeysKey,
    recoveryKeysKey,
    accountIdKey,
    deviceIdKey,
    uploadPassKey,
  ];

  final SecureValues _values;

  Future<JournalKeys?> readJournalKeys() async {
    final Map<String, Object?>? json = await _readJson(journalKeysKey);
    return json == null ? null : JournalKeys.fromJson(json);
  }

  Future<void> writeJournalKeys(JournalKeys keys) =>
      _writeJson(journalKeysKey, keys.toJson());

  Future<DeviceKeys?> readDeviceKeys() async {
    final Map<String, Object?>? json = await _readJson(deviceKeysKey);
    return json == null ? null : DeviceKeys.fromJson(json);
  }

  Future<void> writeDeviceKeys(DeviceKeys keys) async {
    await _writeJson(deviceKeysKey, keys.toJson());
    await _values.write(deviceIdKey, keys.deviceId);
  }

  Future<String?> readDeviceId() => _values.read(deviceIdKey);

  Future<RecoveryPublicKeys?> readRecoveryPublicKeys() async {
    final Map<String, Object?>? json = await _readJson(recoveryKeysKey);
    if (json == null) {
      return null;
    }
    return RecoveryPublicKeys(
      signPublicKey: _bytes(json, 'signPublicKey'),
      boxPublicKey: _bytes(json, 'boxPublicKey'),
    );
  }

  Future<void> writeRecoveryPublicKeys(RecoveryPublicKeys keys) =>
      _writeJson(recoveryKeysKey, <String, Object?>{
        'signPublicKey': encodeBase64Url(keys.signPublicKey),
        'boxPublicKey': encodeBase64Url(keys.boxPublicKey),
      });

  Future<String?> readAccountId() => _values.read(accountIdKey);

  Future<void> writeAccountId(String accountId) =>
      _values.write(accountIdKey, accountId);

  Future<UploadPass?> readUploadPass() async {
    final Map<String, Object?>? json = await _readJson(uploadPassKey);
    if (json == null) {
      return null;
    }
    final Object? token = json['token'];
    final Object? expiresAt = json['expiresAt'];
    final DateTime? parsed = expiresAt is String
        ? DateTime.tryParse(expiresAt)
        : null;
    if (token is! String || parsed == null) {
      throw const FormatException('Invalid upload pass');
    }
    return UploadPass(token: token, expiresAt: parsed);
  }

  Future<void> writeUploadPass(UploadPass pass) =>
      _writeJson(uploadPassKey, <String, Object?>{
        'token': pass.token,
        'expiresAt': pass.expiresAt.toIso8601String(),
      });

  Future<void> wipe() async {
    for (final String key in allKeys) {
      await _values.delete(key);
    }
  }

  Future<Map<String, Object?>?> _readJson(String key) async {
    final String? stored = await _values.read(key);
    return stored == null ? null : decodeJsonObject(stored);
  }

  Future<void> _writeJson(String key, Map<String, Object?> json) =>
      _values.write(key, jsonEncode(json));

  static List<int> _bytes(Map<String, Object?> json, String key) =>
      switch (json[key]) {
        final String encoded => decodeBase64Url(encoded),
        _ => throw FormatException('Invalid $key'),
      };
}
