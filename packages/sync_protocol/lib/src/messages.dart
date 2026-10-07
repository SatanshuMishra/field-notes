import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'errors.dart';

const int syncProtocolVersion = 1;

const String protocolVersionField = 'protocolVersion';

const int syncIdByteLength = 16;

const int syncIdLength = 22;

final RegExp _base64UrlAlphabet = RegExp(r'^[A-Za-z0-9_-]*$');

String encodeBase64Url(List<int> bytes) {
  final String padded = base64Url.encode(bytes);
  final int padding = padded.indexOf('=');
  return padding < 0 ? padded : padded.substring(0, padding);
}

Uint8List decodeBase64Url(String value) {
  if (!_base64UrlAlphabet.hasMatch(value) || value.length % 4 == 1) {
    throw const FormatException('Not unpadded base64url');
  }
  final int padding = (4 - value.length % 4) % 4;
  try {
    return base64Url.decode(value.padRight(value.length + padding, '='));
  } on FormatException {
    throw const FormatException('Not canonical base64url');
  }
}

String newSyncId([Random? random]) {
  final Random source = random ?? Random.secure();
  return encodeBase64Url(
    Uint8List.fromList(
      List<int>.generate(syncIdByteLength, (_) => source.nextInt(256)),
    ),
  );
}

bool isSyncId(String value) {
  if (value.length != syncIdLength) {
    return false;
  }
  try {
    return decodeBase64Url(value).length == syncIdByteLength;
  } on FormatException {
    return false;
  }
}

int readProtocolVersion(Map<String, Object?> json) {
  final Object? version = json[protocolVersionField];
  if (version is int) {
    return version;
  }
  throw FormatException(
    version == null
        ? 'Missing $protocolVersionField'
        : 'Invalid $protocolVersionField',
  );
}

Map<String, Object?> decodeJsonObject(String source) {
  final Object? decoded = jsonDecode(source);
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  throw const FormatException('Expected a JSON object');
}

sealed class SyncValue {
  const SyncValue();

  Map<String, Object?> get _fields;

  List<Object?> get _props;

  Map<String, Object?> toJson() => _fields;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncValue &&
          other.runtimeType == runtimeType &&
          _deepEquals(_props, other._props);

  @override
  int get hashCode => _deepHash(_props);
}

sealed class SyncMessage extends SyncValue {
  const SyncMessage();

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    protocolVersionField: syncProtocolVersion,
    ..._fields,
  };
}

final class DeviceRegistration extends SyncValue {
  DeviceRegistration({
    required this.deviceId,
    required Uint8List signPublicKey,
    required Uint8List boxPublicKey,
    required Uint8List certificate,
    required Uint8List encryptedName,
  }) : signPublicKey = _frozen(signPublicKey),
       boxPublicKey = _frozen(boxPublicKey),
       certificate = _frozen(certificate),
       encryptedName = _frozen(encryptedName);

  factory DeviceRegistration.fromJson(Map<String, Object?> json) =>
      DeviceRegistration(
        deviceId: json.string('deviceId'),
        signPublicKey: json.bytes('signPublicKey'),
        boxPublicKey: json.bytes('boxPublicKey'),
        certificate: json.bytes('certificate'),
        encryptedName: json.bytes('encryptedName'),
      );

  final String deviceId;
  final Uint8List signPublicKey;
  final Uint8List boxPublicKey;
  final Uint8List certificate;
  final Uint8List encryptedName;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'deviceId': deviceId,
    'signPublicKey': encodeBase64Url(signPublicKey),
    'boxPublicKey': encodeBase64Url(boxPublicKey),
    'certificate': encodeBase64Url(certificate),
    'encryptedName': encodeBase64Url(encryptedName),
  };

  @override
  List<Object?> get _props => <Object?>[
    deviceId,
    signPublicKey,
    boxPublicKey,
    certificate,
    encryptedName,
  ];
}

final class DeviceInfo extends SyncValue {
  DeviceInfo({
    required this.deviceId,
    required Uint8List signPublicKey,
    required Uint8List boxPublicKey,
    required Uint8List certificate,
    required Uint8List encryptedName,
    required DateTime createdAt,
    required DateTime lastSeenAt,
  }) : signPublicKey = _frozen(signPublicKey),
       boxPublicKey = _frozen(boxPublicKey),
       certificate = _frozen(certificate),
       encryptedName = _frozen(encryptedName),
       createdAt = createdAt.toUtc(),
       lastSeenAt = lastSeenAt.toUtc();

  factory DeviceInfo.fromJson(Map<String, Object?> json) => DeviceInfo(
    deviceId: json.string('deviceId'),
    signPublicKey: json.bytes('signPublicKey'),
    boxPublicKey: json.bytes('boxPublicKey'),
    certificate: json.bytes('certificate'),
    encryptedName: json.bytes('encryptedName'),
    createdAt: json.time('createdAt'),
    lastSeenAt: json.time('lastSeenAt'),
  );

  final String deviceId;
  final Uint8List signPublicKey;
  final Uint8List boxPublicKey;
  final Uint8List certificate;
  final Uint8List encryptedName;
  final DateTime createdAt;
  final DateTime lastSeenAt;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'deviceId': deviceId,
    'signPublicKey': encodeBase64Url(signPublicKey),
    'boxPublicKey': encodeBase64Url(boxPublicKey),
    'certificate': encodeBase64Url(certificate),
    'encryptedName': encodeBase64Url(encryptedName),
    'createdAt': createdAt.toIso8601String(),
    'lastSeenAt': lastSeenAt.toIso8601String(),
  };

  @override
  List<Object?> get _props => <Object?>[
    deviceId,
    signPublicKey,
    boxPublicKey,
    certificate,
    encryptedName,
    createdAt,
    lastSeenAt,
  ];
}

final class DeviceListResponse extends SyncMessage {
  DeviceListResponse({required List<DeviceInfo> devices})
    : devices = List<DeviceInfo>.unmodifiable(devices);

  factory DeviceListResponse.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return DeviceListResponse(
      devices: json.objects('devices', DeviceInfo.fromJson),
    );
  }

  final List<DeviceInfo> devices;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'devices': _jsonList(devices),
  };

  @override
  List<Object?> get _props => <Object?>[devices];
}

final class EpochKeyDelivery extends SyncValue {
  EpochKeyDelivery({
    required this.recipient,
    required Uint8List sealed,
    required Uint8List signature,
  }) : sealed = _frozen(sealed),
       signature = _frozen(signature);

  factory EpochKeyDelivery.fromJson(Map<String, Object?> json) =>
      EpochKeyDelivery(
        recipient: json.string('recipient'),
        sealed: json.bytes('sealed'),
        signature: json.bytes('signature'),
      );

  static const String recoveryRecipient = 'recovery';
  static const String _devicePrefix = 'device:';

  static String deviceRecipient(String deviceId) => '$_devicePrefix$deviceId';

  final String recipient;
  final Uint8List sealed;
  final Uint8List signature;

  String? get recipientDeviceId => recipient.startsWith(_devicePrefix)
      ? recipient.substring(_devicePrefix.length)
      : null;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'recipient': recipient,
    'sealed': encodeBase64Url(sealed),
    'signature': encodeBase64Url(signature),
  };

  @override
  List<Object?> get _props => <Object?>[recipient, sealed, signature];
}

final class EpochRotation extends SyncValue {
  EpochRotation({
    required this.epoch,
    required this.signerDeviceId,
    required List<EpochKeyDelivery> deliveries,
  }) : deliveries = List<EpochKeyDelivery>.unmodifiable(deliveries);

  factory EpochRotation.fromJson(Map<String, Object?> json) => EpochRotation(
    epoch: json.integer('epoch'),
    signerDeviceId: json.string('signerDeviceId'),
    deliveries: json.objects('deliveries', EpochKeyDelivery.fromJson),
  );

  final int epoch;
  final String signerDeviceId;
  final List<EpochKeyDelivery> deliveries;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'epoch': epoch,
    'signerDeviceId': signerDeviceId,
    'deliveries': _jsonList(deliveries),
  };

  @override
  List<Object?> get _props => <Object?>[epoch, signerDeviceId, deliveries];
}

final class EpochKeysResponse extends SyncMessage {
  EpochKeysResponse({
    required this.currentEpoch,
    required List<EpochRotation> rotations,
    required Uint8List recoveryBoxPublicKey,
    required Uint8List recoveryBoxCertificate,
    required List<DeviceInfo> devices,
  }) : rotations = List<EpochRotation>.unmodifiable(rotations),
       recoveryBoxPublicKey = _frozen(recoveryBoxPublicKey),
       recoveryBoxCertificate = _frozen(recoveryBoxCertificate),
       devices = List<DeviceInfo>.unmodifiable(devices);

  factory EpochKeysResponse.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return EpochKeysResponse(
      currentEpoch: json.integer('currentEpoch'),
      rotations: json.objects('rotations', EpochRotation.fromJson),
      recoveryBoxPublicKey: json.bytes('recoveryBoxPublicKey'),
      recoveryBoxCertificate: json.bytes('recoveryBoxCertificate'),
      devices: json.objects('devices', DeviceInfo.fromJson),
    );
  }

  final int currentEpoch;
  final List<EpochRotation> rotations;
  final Uint8List recoveryBoxPublicKey;
  final Uint8List recoveryBoxCertificate;
  final List<DeviceInfo> devices;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'currentEpoch': currentEpoch,
    'rotations': _jsonList(rotations),
    'recoveryBoxPublicKey': encodeBase64Url(recoveryBoxPublicKey),
    'recoveryBoxCertificate': encodeBase64Url(recoveryBoxCertificate),
    'devices': _jsonList(devices),
  };

  @override
  List<Object?> get _props => <Object?>[
    currentEpoch,
    rotations,
    recoveryBoxPublicKey,
    recoveryBoxCertificate,
    devices,
  ];
}

final class InviteRedeemRequest extends SyncMessage {
  InviteRedeemRequest({
    required this.inviteCode,
    required this.device,
    required Uint8List recoverySignPublicKey,
    required Uint8List recoveryBoxPublicKey,
    required Uint8List recoveryBoxCertificate,
    required Uint8List recoveryEpochOneCopy,
  }) : recoverySignPublicKey = _frozen(recoverySignPublicKey),
       recoveryBoxPublicKey = _frozen(recoveryBoxPublicKey),
       recoveryBoxCertificate = _frozen(recoveryBoxCertificate),
       recoveryEpochOneCopy = _frozen(recoveryEpochOneCopy);

  factory InviteRedeemRequest.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return InviteRedeemRequest(
      inviteCode: json.string('inviteCode'),
      device: json.object('device', DeviceRegistration.fromJson),
      recoverySignPublicKey: json.bytes('recoverySignPublicKey'),
      recoveryBoxPublicKey: json.bytes('recoveryBoxPublicKey'),
      recoveryBoxCertificate: json.bytes('recoveryBoxCertificate'),
      recoveryEpochOneCopy: json.bytes('recoveryEpochOneCopy'),
    );
  }

  final String inviteCode;
  final DeviceRegistration device;
  final Uint8List recoverySignPublicKey;
  final Uint8List recoveryBoxPublicKey;
  final Uint8List recoveryBoxCertificate;
  final Uint8List recoveryEpochOneCopy;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'inviteCode': inviteCode,
    'device': device.toJson(),
    'recoverySignPublicKey': encodeBase64Url(recoverySignPublicKey),
    'recoveryBoxPublicKey': encodeBase64Url(recoveryBoxPublicKey),
    'recoveryBoxCertificate': encodeBase64Url(recoveryBoxCertificate),
    'recoveryEpochOneCopy': encodeBase64Url(recoveryEpochOneCopy),
  };

  @override
  List<Object?> get _props => <Object?>[
    inviteCode,
    device,
    recoverySignPublicKey,
    recoveryBoxPublicKey,
    recoveryBoxCertificate,
    recoveryEpochOneCopy,
  ];
}

final class InviteRedeemResponse extends SyncMessage {
  const InviteRedeemResponse({required this.accountId});

  factory InviteRedeemResponse.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return InviteRedeemResponse(accountId: json.string('accountId'));
  }

  final String accountId;

  @override
  Map<String, Object?> get _fields => <String, Object?>{'accountId': accountId};

  @override
  List<Object?> get _props => <Object?>[accountId];
}

final class ChallengeRequest extends SyncMessage {
  const ChallengeRequest({required this.deviceId});

  factory ChallengeRequest.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return ChallengeRequest(deviceId: json.string('deviceId'));
  }

  final String deviceId;

  @override
  Map<String, Object?> get _fields => <String, Object?>{'deviceId': deviceId};

  @override
  List<Object?> get _props => <Object?>[deviceId];
}

final class ChallengeResponse extends SyncMessage {
  ChallengeResponse({
    required this.challengeId,
    required this.nonce,
    required DateTime expiresAt,
  }) : expiresAt = expiresAt.toUtc();

  factory ChallengeResponse.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return ChallengeResponse(
      challengeId: json.string('challengeId'),
      nonce: json.string('nonce'),
      expiresAt: json.time('expiresAt'),
    );
  }

  final String challengeId;
  final String nonce;
  final DateTime expiresAt;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'challengeId': challengeId,
    'nonce': nonce,
    'expiresAt': expiresAt.toIso8601String(),
  };

  @override
  List<Object?> get _props => <Object?>[challengeId, nonce, expiresAt];
}

final class SessionRequest extends SyncMessage {
  SessionRequest({
    required this.challengeId,
    required this.deviceId,
    required Uint8List signature,
  }) : signature = _frozen(signature);

  factory SessionRequest.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return SessionRequest(
      challengeId: json.string('challengeId'),
      deviceId: json.string('deviceId'),
      signature: json.bytes('signature'),
    );
  }

  final String challengeId;
  final String deviceId;
  final Uint8List signature;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'challengeId': challengeId,
    'deviceId': deviceId,
    'signature': encodeBase64Url(signature),
  };

  @override
  List<Object?> get _props => <Object?>[challengeId, deviceId, signature];
}

final class SessionResponse extends SyncMessage {
  SessionResponse({
    required this.token,
    required DateTime expiresAt,
    required this.currentEpoch,
    required this.uploadPass,
    required DateTime uploadPassExpiresAt,
    required this.generation,
  }) : expiresAt = expiresAt.toUtc(),
       uploadPassExpiresAt = uploadPassExpiresAt.toUtc();

  factory SessionResponse.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return SessionResponse(
      token: json.string('token'),
      expiresAt: json.time('expiresAt'),
      currentEpoch: json.integer('currentEpoch'),
      uploadPass: json.string('uploadPass'),
      uploadPassExpiresAt: json.time('uploadPassExpiresAt'),
      generation: json.string('generation'),
    );
  }

  final String token;
  final DateTime expiresAt;
  final int currentEpoch;
  final String uploadPass;
  final DateTime uploadPassExpiresAt;
  final String generation;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'token': token,
    'expiresAt': expiresAt.toIso8601String(),
    'currentEpoch': currentEpoch,
    'uploadPass': uploadPass,
    'uploadPassExpiresAt': uploadPassExpiresAt.toIso8601String(),
    'generation': generation,
  };

  @override
  List<Object?> get _props => <Object?>[
    token,
    expiresAt,
    currentEpoch,
    uploadPass,
    uploadPassExpiresAt,
    generation,
  ];
}

final class RecordPush extends SyncValue {
  RecordPush({
    required this.recordKey,
    required this.baseSeq,
    required this.changeId,
    required this.epoch,
    required Uint8List envelope,
  }) : envelope = _frozen(envelope);

  factory RecordPush.fromJson(Map<String, Object?> json) => RecordPush(
    recordKey: json.string('recordKey'),
    baseSeq: json.integer('baseSeq'),
    changeId: json.string('changeId'),
    epoch: json.integer('epoch'),
    envelope: json.bytes('envelope'),
  );

  final String recordKey;
  final int baseSeq;
  final String changeId;
  final int epoch;
  final Uint8List envelope;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'recordKey': recordKey,
    'baseSeq': baseSeq,
    'changeId': changeId,
    'epoch': epoch,
    'envelope': encodeBase64Url(envelope),
  };

  @override
  List<Object?> get _props => <Object?>[
    recordKey,
    baseSeq,
    changeId,
    epoch,
    envelope,
  ];
}

final class PushRequest extends SyncMessage {
  PushRequest({required List<RecordPush> changes})
    : changes = List<RecordPush>.unmodifiable(changes);

  factory PushRequest.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return PushRequest(changes: json.objects('changes', RecordPush.fromJson));
  }

  final List<RecordPush> changes;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'changes': _jsonList(changes),
  };

  @override
  List<Object?> get _props => <Object?>[changes];
}

enum PushStatus {
  accepted('accepted'),
  stale('stale'),
  duplicate('duplicate'),
  staleEpoch('staleEpoch');

  const PushStatus(this.wireName);

  final String wireName;
}

final class RecordPushResult extends SyncValue {
  const RecordPushResult({
    required this.changeId,
    required this.status,
    this.seq,
    this.current,
  });

  factory RecordPushResult.fromJson(Map<String, Object?> json) =>
      RecordPushResult(
        changeId: json.string('changeId'),
        status: json.choice(
          'status',
          PushStatus.values,
          (PushStatus status) => status.wireName,
        ),
        seq: json.optionalInteger('seq'),
        current: json.optionalObject('current', RecordState.fromJson),
      );

  final String changeId;
  final PushStatus status;
  final int? seq;
  final RecordState? current;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'changeId': changeId,
    'status': status.wireName,
    'seq': seq,
    'current': current?.toJson(),
  };

  @override
  List<Object?> get _props => <Object?>[changeId, status, seq, current];
}

final class PushResponse extends SyncMessage {
  PushResponse({required List<RecordPushResult> results})
    : results = List<RecordPushResult>.unmodifiable(results);

  factory PushResponse.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return PushResponse(
      results: json.objects('results', RecordPushResult.fromJson),
    );
  }

  final List<RecordPushResult> results;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'results': _jsonList(results),
  };

  @override
  List<Object?> get _props => <Object?>[results];
}

final class RecordState extends SyncValue {
  RecordState({
    required this.recordKey,
    required this.seq,
    required this.epoch,
    required Uint8List envelope,
  }) : envelope = _frozen(envelope);

  factory RecordState.fromJson(Map<String, Object?> json) => RecordState(
    recordKey: json.string('recordKey'),
    seq: json.integer('seq'),
    epoch: json.integer('epoch'),
    envelope: json.bytes('envelope'),
  );

  final String recordKey;
  final int seq;
  final int epoch;
  final Uint8List envelope;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'recordKey': recordKey,
    'seq': seq,
    'epoch': epoch,
    'envelope': encodeBase64Url(envelope),
  };

  @override
  List<Object?> get _props => <Object?>[recordKey, seq, epoch, envelope];
}

final class PullResponse extends SyncMessage {
  PullResponse({
    required List<RecordState> states,
    required this.latestSeq,
    required this.hasMore,
    required this.remaining,
    required this.currentEpoch,
    required this.generation,
  }) : states = List<RecordState>.unmodifiable(states);

  factory PullResponse.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return PullResponse(
      states: json.objects('states', RecordState.fromJson),
      latestSeq: json.integer('latestSeq'),
      hasMore: json.boolean('hasMore'),
      remaining: json.integer('remaining'),
      currentEpoch: json.integer('currentEpoch'),
      generation: json.string('generation'),
    );
  }

  final List<RecordState> states;
  final int latestSeq;
  final bool hasMore;
  final int remaining;
  final int currentEpoch;
  final String generation;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'states': _jsonList(states),
    'latestSeq': latestSeq,
    'hasMore': hasMore,
    'remaining': remaining,
    'currentEpoch': currentEpoch,
    'generation': generation,
  };

  @override
  List<Object?> get _props => <Object?>[
    states,
    latestSeq,
    hasMore,
    remaining,
    currentEpoch,
    generation,
  ];
}

sealed class LiveMessage extends SyncMessage {
  const LiveMessage();

  factory LiveMessage.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    final String type = json.string(typeField);
    return switch (type) {
      LiveNudge.type => LiveNudge.fromJson(json),
      LivePing.type => LivePing.fromJson(json),
      LivePong.type => LivePong.fromJson(json),
      _ => throw const FormatException('Invalid type'),
    };
  }

  static const String typeField = 'type';

  String get _type;

  Map<String, Object?> get _liveFields => const <String, Object?>{};

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    typeField: _type,
    ..._liveFields,
  };
}

final class LiveNudge extends LiveMessage {
  const LiveNudge({required this.latestSeq});

  factory LiveNudge.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    json.expectType(type);
    return LiveNudge(latestSeq: json.integer('latestSeq'));
  }

  static const String type = 'nudge';

  final int latestSeq;

  @override
  String get _type => type;

  @override
  Map<String, Object?> get _liveFields => <String, Object?>{
    'latestSeq': latestSeq,
  };

  @override
  List<Object?> get _props => <Object?>[latestSeq];
}

final class LivePing extends LiveMessage {
  const LivePing();

  factory LivePing.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    json.expectType(type);
    return const LivePing();
  }

  static const String type = 'ping';

  @override
  String get _type => type;

  @override
  List<Object?> get _props => const <Object?>[];
}

final class LivePong extends LiveMessage {
  const LivePong();

  factory LivePong.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    json.expectType(type);
    return const LivePong();
  }

  static const String type = 'pong';

  @override
  String get _type => type;

  @override
  List<Object?> get _props => const <Object?>[];
}

final class UploadStatusResponse extends SyncMessage {
  UploadStatusResponse({
    required List<int> receivedParts,
    required this.assembled,
  }) : receivedParts = List<int>.unmodifiable(receivedParts);

  factory UploadStatusResponse.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return UploadStatusResponse(
      receivedParts: json.integers('receivedParts'),
      assembled: json.boolean('assembled'),
    );
  }

  final List<int> receivedParts;
  final bool assembled;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'receivedParts': receivedParts,
    'assembled': assembled,
  };

  @override
  List<Object?> get _props => <Object?>[receivedParts, assembled];
}

final class BlobNamesRequest extends SyncMessage {
  BlobNamesRequest({required List<String> names})
    : names = List<String>.unmodifiable(names);

  factory BlobNamesRequest.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return BlobNamesRequest(names: json.strings('names'));
  }

  final List<String> names;

  @override
  Map<String, Object?> get _fields => <String, Object?>{'names': names};

  @override
  List<Object?> get _props => <Object?>[names];
}

final class BlobNamesResponse extends SyncMessage {
  BlobNamesResponse({required List<String> names})
    : names = List<String>.unmodifiable(names);

  factory BlobNamesResponse.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return BlobNamesResponse(names: json.strings('names'));
  }

  final List<String> names;

  @override
  Map<String, Object?> get _fields => <String, Object?>{'names': names};

  @override
  List<Object?> get _props => <Object?>[names];
}

final class PairingOpenRequest extends SyncMessage {
  const PairingOpenRequest({required this.mailboxId, required this.tokenHash});

  factory PairingOpenRequest.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return PairingOpenRequest(
      mailboxId: json.string('mailboxId'),
      tokenHash: json.string('tokenHash'),
    );
  }

  final String mailboxId;
  final String tokenHash;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'mailboxId': mailboxId,
    'tokenHash': tokenHash,
  };

  @override
  List<Object?> get _props => <Object?>[mailboxId, tokenHash];
}

final class PairingJoinRequest extends SyncMessage {
  PairingJoinRequest({required this.device, required Uint8List authenticator})
    : authenticator = _frozen(authenticator);

  factory PairingJoinRequest.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return PairingJoinRequest(
      device: json.object('device', DeviceRegistration.fromJson),
      authenticator: json.bytes('authenticator'),
    );
  }

  final DeviceRegistration device;
  final Uint8List authenticator;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'device': device.toJson(),
    'authenticator': encodeBase64Url(authenticator),
  };

  @override
  List<Object?> get _props => <Object?>[device, authenticator];
}

final class PairingCompleteRequest extends SyncMessage {
  PairingCompleteRequest({required this.device, required Uint8List keyBundle})
    : keyBundle = _frozen(keyBundle);

  factory PairingCompleteRequest.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return PairingCompleteRequest(
      device: json.object('device', DeviceRegistration.fromJson),
      keyBundle: json.bytes('keyBundle'),
    );
  }

  final DeviceRegistration device;
  final Uint8List keyBundle;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'device': device.toJson(),
    'keyBundle': encodeBase64Url(keyBundle),
  };

  @override
  List<Object?> get _props => <Object?>[device, keyBundle];
}

enum PairingStatus {
  open('open'),
  joined('joined'),
  complete('complete');

  const PairingStatus(this.wireName);

  final String wireName;
}

final class PairingStatusResponse extends SyncMessage {
  PairingStatusResponse({
    required this.status,
    this.join,
    this.accountId,
    Uint8List? keyBundle,
    this.journalLabel,
  }) : keyBundle = keyBundle == null ? null : _frozen(keyBundle);

  factory PairingStatusResponse.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return PairingStatusResponse(
      status: json.choice(
        'status',
        PairingStatus.values,
        (PairingStatus status) => status.wireName,
      ),
      join: json.optionalObject('join', PairingJoinRequest.fromJson),
      accountId: json.optionalString('accountId'),
      keyBundle: json.optionalBytes('keyBundle'),
      journalLabel: json.optionalString('journalLabel'),
    );
  }

  final PairingStatus status;
  final PairingJoinRequest? join;
  final String? accountId;
  final Uint8List? keyBundle;
  final String? journalLabel;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'status': status.wireName,
    'join': join?.toJson(),
    'accountId': accountId,
    'keyBundle': keyBundle == null ? null : encodeBase64Url(keyBundle!),
    'journalLabel': journalLabel,
  };

  @override
  List<Object?> get _props => <Object?>[
    status,
    join,
    accountId,
    keyBundle,
    journalLabel,
  ];
}

final class RestoreChallengeRequest extends SyncMessage {
  RestoreChallengeRequest({required Uint8List recoverySignPublicKey})
    : recoverySignPublicKey = _frozen(recoverySignPublicKey);

  factory RestoreChallengeRequest.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return RestoreChallengeRequest(
      recoverySignPublicKey: json.bytes('recoverySignPublicKey'),
    );
  }

  final Uint8List recoverySignPublicKey;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'recoverySignPublicKey': encodeBase64Url(recoverySignPublicKey),
  };

  @override
  List<Object?> get _props => <Object?>[recoverySignPublicKey];
}

final class RestoreRequest extends SyncMessage {
  RestoreRequest({required this.challengeId, required Uint8List signature})
    : signature = _frozen(signature);

  factory RestoreRequest.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return RestoreRequest(
      challengeId: json.string('challengeId'),
      signature: json.bytes('signature'),
    );
  }

  final String challengeId;
  final Uint8List signature;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'challengeId': challengeId,
    'signature': encodeBase64Url(signature),
  };

  @override
  List<Object?> get _props => <Object?>[challengeId, signature];
}

final class RestoreResponse extends SyncMessage {
  RestoreResponse({
    required this.accountId,
    required this.restoreToken,
    required this.currentEpoch,
    required Uint8List recoveryEpochOneCopy,
    required List<EpochRotation> rotations,
    required List<DeviceInfo> devices,
  }) : recoveryEpochOneCopy = _frozen(recoveryEpochOneCopy),
       rotations = List<EpochRotation>.unmodifiable(rotations),
       devices = List<DeviceInfo>.unmodifiable(devices);

  factory RestoreResponse.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return RestoreResponse(
      accountId: json.string('accountId'),
      restoreToken: json.string('restoreToken'),
      currentEpoch: json.integer('currentEpoch'),
      recoveryEpochOneCopy: json.bytes('recoveryEpochOneCopy'),
      rotations: json.objects('rotations', EpochRotation.fromJson),
      devices: json.objects('devices', DeviceInfo.fromJson),
    );
  }

  final String accountId;
  final String restoreToken;
  final int currentEpoch;
  final Uint8List recoveryEpochOneCopy;
  final List<EpochRotation> rotations;
  final List<DeviceInfo> devices;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'accountId': accountId,
    'restoreToken': restoreToken,
    'currentEpoch': currentEpoch,
    'recoveryEpochOneCopy': encodeBase64Url(recoveryEpochOneCopy),
    'rotations': _jsonList(rotations),
    'devices': _jsonList(devices),
  };

  @override
  List<Object?> get _props => <Object?>[
    accountId,
    restoreToken,
    currentEpoch,
    recoveryEpochOneCopy,
    rotations,
    devices,
  ];
}

final class RestoreRegisterRequest extends SyncMessage {
  const RestoreRegisterRequest({
    required this.restoreToken,
    required this.device,
  });

  factory RestoreRegisterRequest.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return RestoreRegisterRequest(
      restoreToken: json.string('restoreToken'),
      device: json.object('device', DeviceRegistration.fromJson),
    );
  }

  final String restoreToken;
  final DeviceRegistration device;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'restoreToken': restoreToken,
    'device': device.toJson(),
  };

  @override
  List<Object?> get _props => <Object?>[restoreToken, device];
}

final class DeviceRemoveRequest extends SyncMessage {
  const DeviceRemoveRequest({required this.rotation});

  factory DeviceRemoveRequest.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return DeviceRemoveRequest(
      rotation: json.object('rotation', EpochRotation.fromJson),
    );
  }

  final EpochRotation rotation;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'rotation': rotation.toJson(),
  };

  @override
  List<Object?> get _props => <Object?>[rotation];
}

final class ErrorResponse extends SyncMessage {
  const ErrorResponse({required this.code, required this.message});

  factory ErrorResponse.fromJson(Map<String, Object?> json) {
    readProtocolVersion(json);
    return ErrorResponse(
      code: json.choice(
        'code',
        SyncErrorCode.values,
        (SyncErrorCode code) => code.wireName,
      ),
      message: json.string('message'),
    );
  }

  final SyncErrorCode code;
  final String message;

  @override
  Map<String, Object?> get _fields => <String, Object?>{
    'code': code.wireName,
    'message': message,
  };

  @override
  List<Object?> get _props => <Object?>[code, message];
}

Uint8List _frozen(Uint8List bytes) =>
    Uint8List.fromList(bytes).asUnmodifiableView();

List<Map<String, Object?>> _jsonList(List<SyncValue> values) =>
    <Map<String, Object?>>[
      for (final SyncValue value in values) value.toJson(),
    ];

bool _deepEquals(Object? a, Object? b) {
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) {
      return false;
    }
    for (int index = 0; index < a.length; index++) {
      if (!_deepEquals(a[index], b[index])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}

int _deepHash(Object? value) => value is List<Object?>
    ? Object.hashAll(value.map(_deepHash))
    : value.hashCode;

extension on Map<String, Object?> {
  T _required<T extends Object>(String key) {
    final Object? value = this[key];
    if (value is T) {
      return value;
    }
    throw FormatException(value == null ? 'Missing $key' : 'Invalid $key');
  }

  String string(String key) => _required<String>(key);

  String? optionalString(String key) => this[key] == null ? null : string(key);

  int integer(String key) => _required<int>(key);

  int? optionalInteger(String key) => this[key] == null ? null : integer(key);

  bool boolean(String key) => _required<bool>(key);

  Uint8List bytes(String key) {
    final String encoded = string(key);
    try {
      return decodeBase64Url(encoded);
    } on FormatException {
      throw FormatException('Invalid $key');
    }
  }

  Uint8List? optionalBytes(String key) => this[key] == null ? null : bytes(key);

  DateTime time(String key) {
    final DateTime? parsed = DateTime.tryParse(string(key));
    if (parsed == null) {
      throw FormatException('Invalid $key');
    }
    return parsed.toUtc();
  }

  T object<T>(String key, T Function(Map<String, Object?> json) decode) =>
      decode(_required<Map<String, Object?>>(key));

  T? optionalObject<T>(
    String key,
    T Function(Map<String, Object?> json) decode,
  ) => this[key] == null ? null : object(key, decode);

  List<T> objects<T>(
    String key,
    T Function(Map<String, Object?> json) decode,
  ) => <T>[
    for (final Object? item in _required<List<Object?>>(key))
      item is Map<String, Object?>
          ? decode(item)
          : throw FormatException('Invalid $key'),
  ];

  List<String> strings(String key) => <String>[
    for (final Object? item in _required<List<Object?>>(key))
      item is String ? item : throw FormatException('Invalid $key'),
  ];

  List<int> integers(String key) => <int>[
    for (final Object? item in _required<List<Object?>>(key))
      item is int ? item : throw FormatException('Invalid $key'),
  ];

  T choice<T>(String key, List<T> options, String Function(T option) wireName) {
    final String value = string(key);
    for (final T option in options) {
      if (wireName(option) == value) {
        return option;
      }
    }
    throw FormatException('Invalid $key');
  }

  void expectType(String type) {
    if (string(LiveMessage.typeField) != type) {
      throw FormatException('Invalid ${LiveMessage.typeField}');
    }
  }
}
