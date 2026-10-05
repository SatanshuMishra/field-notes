import 'dart:convert';

import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/recovery_phrase.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sync_protocol/sync_protocol.dart';

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
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
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
