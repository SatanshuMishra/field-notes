import 'dart:convert';
import 'dart:typed_data';

import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

final DateTime instant = DateTime.utc(2026, 10, 4, 9, 30, 15, 123, 456);

const List<String> wireWords = <String>[
  'accepted',
  'stale',
  'duplicate',
  'staleEpoch',
  'open',
  'joined',
  'complete',
  'not_found',
  'forbidden',
];

Uint8List bytes(int seed, [int length = 32]) => Uint8List.fromList(<int>[
  for (int index = 0; index < length; index++) (seed * 37 + index * 11) % 256,
]);

String blobName(int seed) => encodeBase64Url(bytes(seed));

DeviceRegistration registration(int seed) => DeviceRegistration(
  deviceId: newSyncId(),
  signPublicKey: bytes(seed),
  boxPublicKey: bytes(seed + 1),
  certificate: bytes(seed + 2, 64),
  encryptedName: bytes(seed + 3, 40),
);

DeviceInfo deviceInfo(int seed) => DeviceInfo(
  deviceId: newSyncId(),
  signPublicKey: bytes(seed),
  boxPublicKey: bytes(seed + 1),
  certificate: bytes(seed + 2, 64),
  encryptedName: bytes(seed + 3, 40),
  createdAt: instant,
  lastSeenAt: instant.add(const Duration(days: 3)),
);

EpochKeyDelivery delivery(String recipient, int seed) => EpochKeyDelivery(
  recipient: recipient,
  sealed: bytes(seed, 80),
  signature: bytes(seed + 1, 64),
);

EpochRotation rotation(int epoch) => EpochRotation(
  epoch: epoch,
  signerDeviceId: newSyncId(),
  deliveries: <EpochKeyDelivery>[
    delivery(EpochKeyDelivery.deviceRecipient(newSyncId()), epoch),
    delivery(EpochKeyDelivery.recoveryRecipient, epoch + 10),
  ],
);

RecordPush push(int seed) => RecordPush(
  recordKey: blobName(seed),
  baseSeq: seed,
  changeId: newSyncId(),
  epoch: 2,
  envelope: bytes(seed + 1, 512),
);

RecordState state(int seq) => RecordState(
  recordKey: blobName(seq),
  seq: seq,
  epoch: 2,
  envelope: bytes(seq + 5, 256),
);

List<SyncValue> everyMessage() {
  final PairingJoinRequest join = PairingJoinRequest(
    device: registration(40),
    authenticator: bytes(44),
  );
  return <SyncValue>[
    registration(1),
    deviceInfo(5),
    DeviceListResponse(devices: <DeviceInfo>[deviceInfo(9), deviceInfo(13)]),
    delivery(EpochKeyDelivery.recoveryRecipient, 17),
    rotation(2),
    EpochKeysResponse(
      currentEpoch: 3,
      rotations: <EpochRotation>[rotation(2), rotation(3)],
      recoveryBoxPublicKey: bytes(21),
      recoveryBoxCertificate: bytes(22, 64),
      devices: <DeviceInfo>[deviceInfo(23)],
    ),
    InviteRedeemRequest(
      inviteCode: 'FN-7Q2K-9XWD',
      device: registration(27),
      recoverySignPublicKey: bytes(31),
      recoveryBoxPublicKey: bytes(32),
      recoveryBoxCertificate: bytes(33, 64),
      recoveryEpochOneCopy: bytes(34, 72),
    ),
    InviteRedeemResponse(accountId: newSyncId()),
    ChallengeRequest(deviceId: newSyncId()),
    ChallengeResponse(
      challengeId: newSyncId(),
      nonce: blobName(35),
      expiresAt: DateTime(2026, 10, 4, 9, 31),
    ),
    SessionRequest(
      challengeId: newSyncId(),
      deviceId: newSyncId(),
      signature: bytes(36, 64),
    ),
    SessionResponse(
      token: blobName(37),
      expiresAt: instant.add(const Duration(hours: 24)),
      currentEpoch: 3,
      uploadPass: blobName(38),
      uploadPassExpiresAt: instant.add(const Duration(days: 7)),
      generation: newSyncId(),
    ),
    push(39),
    PushRequest(changes: <RecordPush>[push(41), push(42)]),
    RecordPushResult(
      changeId: newSyncId(),
      status: PushStatus.stale,
      seq: 12,
      current: state(12),
    ),
    PushResponse(
      results: <RecordPushResult>[
        RecordPushResult(
          changeId: newSyncId(),
          status: PushStatus.accepted,
          seq: 13,
        ),
        RecordPushResult(
          changeId: newSyncId(),
          status: PushStatus.duplicate,
          seq: 9,
        ),
        RecordPushResult(changeId: newSyncId(), status: PushStatus.staleEpoch),
        RecordPushResult(
          changeId: newSyncId(),
          status: PushStatus.stale,
          seq: 11,
          current: state(11),
        ),
      ],
    ),
    state(14),
    PullResponse(
      states: <RecordState>[state(15), state(16)],
      latestSeq: 40,
      hasMore: true,
      remaining: 24,
      currentEpoch: 3,
      generation: newSyncId(),
    ),
    const LiveNudge(latestSeq: 40),
    const LivePing(),
    const LivePong(),
    UploadStatusResponse(receivedParts: <int>[0, 1, 3], assembled: false),
    BlobNamesRequest(names: <String>[blobName(1), blobName(2)]),
    BlobNamesResponse(names: <String>[blobName(3)]),
    PairingOpenRequest(
      mailboxId: newSyncId(),
      tokenHash: mailboxTokenHash(blobName(43)),
    ),
    join,
    PairingCompleteRequest(device: registration(45), keyBundle: bytes(49, 200)),
    PairingStatusResponse(
      status: PairingStatus.complete,
      join: join,
      accountId: newSyncId(),
      keyBundle: bytes(50, 200),
      journalLabel: 'Satanshu',
    ),
    RestoreChallengeRequest(recoverySignPublicKey: bytes(51)),
    RestoreRequest(challengeId: newSyncId(), signature: bytes(52, 64)),
    RestoreResponse(
      accountId: newSyncId(),
      restoreToken: blobName(53),
      currentEpoch: 3,
      recoveryEpochOneCopy: bytes(54, 72),
      rotations: <EpochRotation>[rotation(2), rotation(3)],
      devices: <DeviceInfo>[deviceInfo(55)],
    ),
    RestoreRegisterRequest(
      restoreToken: blobName(56),
      device: registration(57),
    ),
    DeviceRemoveRequest(rotation: rotation(4)),
    const ErrorResponse(
      code: SyncErrorCode.staleEpoch,
      message: 'Fetch the new key epoch and push again.',
    ),
  ];
}

List<SyncValue> sparseMessages() => <SyncValue>[
  RecordPushResult(changeId: newSyncId(), status: PushStatus.staleEpoch),
  PairingStatusResponse(status: PairingStatus.open),
  PullResponse(
    states: const <RecordState>[],
    latestSeq: 0,
    hasMore: false,
    remaining: 0,
    currentEpoch: 1,
    generation: newSyncId(),
  ),
  UploadStatusResponse(receivedParts: const <int>[], assembled: true),
];

SyncValue decode(SyncValue sample, Map<String, Object?> json) =>
    switch (sample) {
      DeviceRegistration() => DeviceRegistration.fromJson(json),
      DeviceInfo() => DeviceInfo.fromJson(json),
      EpochKeyDelivery() => EpochKeyDelivery.fromJson(json),
      EpochRotation() => EpochRotation.fromJson(json),
      RecordPush() => RecordPush.fromJson(json),
      RecordPushResult() => RecordPushResult.fromJson(json),
      RecordState() => RecordState.fromJson(json),
      DeviceListResponse() => DeviceListResponse.fromJson(json),
      EpochKeysResponse() => EpochKeysResponse.fromJson(json),
      InviteRedeemRequest() => InviteRedeemRequest.fromJson(json),
      InviteRedeemResponse() => InviteRedeemResponse.fromJson(json),
      ChallengeRequest() => ChallengeRequest.fromJson(json),
      ChallengeResponse() => ChallengeResponse.fromJson(json),
      SessionRequest() => SessionRequest.fromJson(json),
      SessionResponse() => SessionResponse.fromJson(json),
      PushRequest() => PushRequest.fromJson(json),
      PushResponse() => PushResponse.fromJson(json),
      PullResponse() => PullResponse.fromJson(json),
      LiveNudge() => LiveNudge.fromJson(json),
      LivePing() => LivePing.fromJson(json),
      LivePong() => LivePong.fromJson(json),
      UploadStatusResponse() => UploadStatusResponse.fromJson(json),
      BlobNamesRequest() => BlobNamesRequest.fromJson(json),
      BlobNamesResponse() => BlobNamesResponse.fromJson(json),
      PairingOpenRequest() => PairingOpenRequest.fromJson(json),
      PairingJoinRequest() => PairingJoinRequest.fromJson(json),
      PairingCompleteRequest() => PairingCompleteRequest.fromJson(json),
      PairingStatusResponse() => PairingStatusResponse.fromJson(json),
      RestoreChallengeRequest() => RestoreChallengeRequest.fromJson(json),
      RestoreRequest() => RestoreRequest.fromJson(json),
      RestoreResponse() => RestoreResponse.fromJson(json),
      RestoreRegisterRequest() => RestoreRegisterRequest.fromJson(json),
      DeviceRemoveRequest() => DeviceRemoveRequest.fromJson(json),
      ErrorResponse() => ErrorResponse.fromJson(json),
    };

Map<String, Object?> throughJson(SyncValue value) =>
    jsonDecode(jsonEncode(value.toJson())) as Map<String, Object?>;

Map<String, Object?> without(Map<String, Object?> json, String key) =>
    <String, Object?>{
      for (final MapEntry<String, Object?> entry in json.entries)
        if (entry.key != key) entry.key: entry.value,
    };

String? flippedBase64Url(String text) {
  try {
    final Uint8List decoded = decodeBase64Url(text);
    return decoded.isEmpty
        ? null
        : encodeBase64Url(<int>[decoded.first ^ 1, ...decoded.skip(1)]);
  } on FormatException {
    return null;
  }
}

List<Object?> textAlternatives(String text) {
  final DateTime? time = DateTime.tryParse(text);
  return <Object?>[
    if (time != null) time.add(const Duration(seconds: 1)).toIso8601String(),
    ?flippedBase64Url(text),
    '${text}x',
    for (final String word in wireWords)
      if (word != text) word,
  ];
}

List<Object?> alternatives(Object? value) => switch (value) {
  int number => <Object?>[number + 1],
  bool flag => <Object?>[!flag],
  String text => textAlternatives(text),
  List<Object?> items =>
    items.isEmpty ? <Object?>[] : <Object?>[items.sublist(1)],
  Map<String, Object?> fields => <Object?>[
    for (final MapEntry<String, Object?> entry in fields.entries)
      if (entry.key != 'protocolVersion')
        for (final Object? alternative in alternatives(entry.value))
          <String, Object?>{...fields, entry.key: alternative},
  ],
  _ => <Object?>[],
};

SyncValue? withChangedField(
  SyncValue sample,
  Map<String, Object?> json,
  String key,
) {
  for (final Object? alternative in alternatives(json[key])) {
    try {
      return decode(sample, <String, Object?>{...json, key: alternative});
    } on FormatException {
      continue;
    }
  }
  return null;
}

String signedText(Uint8List signed) => utf8.decode(signed);

void main() {
  test('every message type round-trips through JSON', () {
    final List<SyncValue> values = everyMessage();
    expect(
      values.map((SyncValue value) => value.runtimeType).toSet(),
      hasLength(values.length),
    );
    for (final SyncValue value in <SyncValue>[...values, ...sparseMessages()]) {
      final String encoded = jsonEncode(value.toJson());
      final Map<String, Object?> json =
          jsonDecode(encoded) as Map<String, Object?>;
      final SyncValue decoded = decode(value, json);
      expect(decoded, equals(value), reason: '${value.runtimeType}');
      expect(decoded.hashCode, value.hashCode, reason: '${value.runtimeType}');
      expect(
        jsonEncode(decoded.toJson()),
        encoded,
        reason: '${value.runtimeType}',
      );
      if (value is LiveMessage) {
        expect(LiveMessage.fromJson(json), equals(value));
      }
    }
    for (final SyncErrorCode code in SyncErrorCode.values) {
      final ErrorResponse error = ErrorResponse(
        code: code,
        message: code.wireName,
      );
      final Map<String, Object?> json = throughJson(error);
      expect(json['code'], code.wireName, reason: '$code');
      expect(ErrorResponse.fromJson(json), equals(error), reason: '$code');
    }
    const ErrorResponse tooMany = ErrorResponse(
      code: SyncErrorCode.tooManyRequests,
      message: 'Too many tries. Wait a minute and try again.',
    );
    expect(throughJson(tooMany)['code'], 'too_many_requests');
    expect(ErrorResponse.fromJson(throughJson(tooMany)), equals(tooMany));
    expect(SyncErrorCode.tooManyRequests.httpStatus, 429);
  });

  test('a message differing in any one field is not equal', () {
    for (final SyncValue value in everyMessage()) {
      final Map<String, Object?> json = throughJson(value);
      for (final String key in json.keys) {
        if (key == 'protocolVersion' || key == LiveMessage.typeField) {
          continue;
        }
        final SyncValue? changed = withChangedField(value, json, key);
        expect(changed, isNotNull, reason: '${value.runtimeType}.$key');
        expect(
          changed,
          isNot(equals(value)),
          reason: '${value.runtimeType}.$key',
        );
      }
    }
  });

  test('a message without a protocol version is rejected', () {
    final PushRequest request = PushRequest(
      changes: <RecordPush>[push(61), push(62)],
    );
    final Map<String, Object?> json = throughJson(request);
    expect(json['protocolVersion'], syncProtocolVersion);
    expect(PushRequest.fromJson(json), equals(request));
    expect(
      () => PushRequest.fromJson(without(json, 'protocolVersion')),
      throwsFormatException,
    );
    expect(
      () => PushRequest.fromJson(<String, Object?>{
        ...json,
        'protocolVersion': '1',
      }),
      throwsFormatException,
    );
    for (final SyncMessage message in everyMessage().whereType<SyncMessage>()) {
      expect(
        () => decode(message, without(throughJson(message), 'protocolVersion')),
        throwsFormatException,
        reason: '${message.runtimeType}',
      );
    }
  });

  test('a message with a missing or mistyped field is rejected', () {
    final Map<String, Object?> json = throughJson(state(70));
    expect(
      () => RecordState.fromJson(without(json, 'seq')),
      throwsFormatException,
    );
    expect(
      () => RecordState.fromJson(<String, Object?>{...json, 'seq': '70'}),
      throwsFormatException,
    );
    expect(
      () =>
          RecordState.fromJson(<String, Object?>{...json, 'envelope': 'YQ=='}),
      throwsFormatException,
    );
    expect(
      () => ErrorResponse.fromJson(<String, Object?>{
        'protocolVersion': syncProtocolVersion,
        'code': 'teapot',
        'message': 'no',
      }),
      throwsFormatException,
    );
    expect(
      () => LiveMessage.fromJson(<String, Object?>{
        'protocolVersion': syncProtocolVersion,
        'type': 'shout',
      }),
      throwsFormatException,
    );
  });

  test('ids and binary fields are unpadded base64url', () {
    final String id = newSyncId();
    expect(id, hasLength(22));
    expect(isSyncId(id), isTrue);
    expect(decodeBase64Url(id), hasLength(16));
    expect(newSyncId(), isNot(id));
    expect(isSyncId('AAAAAAAAAAAAAAAAAAAAAB'), isFalse);
    expect(encodeBase64Url(<int>[1, 2, 3]), 'AQID');
    expect(encodeBase64Url(<int>[4, 5]), 'BAU');
    expect(decodeBase64Url('BAU'), <int>[4, 5]);
    for (final String invalid in <String>['BAU=', '+/8', 'YR', 'Y']) {
      expect(
        () => decodeBase64Url(invalid),
        throwsFormatException,
        reason: invalid,
      );
    }
    final DeviceRegistration device = registration(80);
    expect(
      device.toJson()['signPublicKey'],
      encodeBase64Url(device.signPublicKey),
    );
  });

  test('signed bytes are a prefix and fields joined by line breaks', () {
    final Uint8List three = Uint8List.fromList(<int>[1, 2, 3]);
    final Uint8List two = Uint8List.fromList(<int>[4, 5]);
    expect(
      signedText(
        sessionChallengeBytes(challengeId: 'c', nonce: 'n', deviceId: 'd'),
      ),
      'field-notes-session-v1\nc\nn\nd',
    );
    expect(
      signedText(
        restoreChallengeBytes(
          challengeId: 'c',
          nonce: 'n',
          recoverySignPublicKey: three,
        ),
      ),
      'field-notes-restore-v1\nc\nn\nAQID',
    );
    expect(
      signedText(
        deviceCertificateBytes(
          deviceId: 'd',
          signPublicKey: three,
          boxPublicKey: two,
        ),
      ),
      'field-notes-device-v1\nd\nAQID\nBAU',
    );
    expect(
      signedText(recoveryCertificateBytes(two)),
      'field-notes-recovery-v1\nBAU',
    );
    expect(
      signedText(
        epochDeliveryBytes(
          epoch: 2,
          recipient: EpochKeyDelivery.deviceRecipient('d'),
          sealed: Uint8List.fromList(<int>[255, 254]),
          signerDeviceId: 's',
        ),
      ),
      'field-notes-epoch-v1\n2\ndevice:d\n__4\ns',
    );
    expect(
      signedText(
        pairingJoinBytes(
          mailboxId: 'm',
          device: DeviceRegistration(
            deviceId: 'd',
            signPublicKey: three,
            boxPublicKey: two,
            certificate: Uint8List(0),
            encryptedName: Uint8List.fromList(<int>[6]),
          ),
        ),
      ),
      'field-notes-pairing-v1\nm\nd\nAQID\nBAU\n\nBg',
    );
    expect(
      mailboxTokenHash('abc'),
      'ungWv48Bz-pBQUDeXa4iI7ADYaOWF3qctBD_YfIAFa0',
    );
    expect(
      () =>
          sessionChallengeBytes(challengeId: 'c\nn', nonce: 'n', deviceId: 'd'),
      throwsFormatException,
    );
  });

  test('routes fill their parameters and authorization headers parse', () {
    expect(
      SyncRoutes.uploadPart.path(<String, Object>{
        SyncRoutes.nameParameter: 'b',
        SyncRoutes.uploadIdParameter: 'u',
        SyncRoutes.indexParameter: 0,
      }),
      '/v1/blobs/b/uploads/u/parts/0',
    );
    expect(
      SyncRoutes.pullRecords
          .uri(
            Uri.parse('https://relay.example/'),
            query: <String, String>{
              SyncRoutes.afterQuery: '5',
              SyncRoutes.limitQuery: '500',
            },
          )
          .toString(),
      'https://relay.example/v1/records?after=5&limit=500',
    );
    expect(
      SyncRoutes.keys.uri(Uri.parse('http://127.0.0.1:8080/relay')).toString(),
      'http://127.0.0.1:8080/relay/v1/keys',
    );
    expect(() => SyncRoutes.removeDevice.path(), throwsArgumentError);
    expect(
      () => SyncRoutes.health.path(<String, Object>{'deviceId': 'd'}),
      throwsArgumentError,
    );
    expect(AuthScheme.mailbox.authorization('t'), 'Mailbox t');
    expect(
      AuthCredential.parse('Bearer abc'),
      const AuthCredential(AuthScheme.session, 'abc'),
    );
    expect(AuthCredential.parse('upload xyz')?.scheme, AuthScheme.uploadPass);
    expect(AuthCredential.parse('Basic abc'), isNull);
    expect(AuthCredential.parse('Bearer'), isNull);
    expect(AuthCredential.parse(null), isNull);
  });
}
