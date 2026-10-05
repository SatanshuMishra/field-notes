import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/accounts.dart';
import 'package:relay_server/src/database.dart';
import 'package:sodium/sodium.dart';
import 'package:sync_protocol/sync_protocol.dart';

final DateTime harnessStart = DateTime.utc(2026, 10, 4, 12);

final class TestKeys {
  const TestKeys({required this.publicKey, required this.secretKey});

  final Uint8List publicKey;
  final SecureKey secretKey;
}

final class TestDevice {
  const TestDevice({
    required this.deviceId,
    required this.signKeys,
    required this.boxPublicKey,
    required this.registration,
  });

  final String deviceId;
  final TestKeys signKeys;
  final Uint8List boxPublicKey;
  final DeviceRegistration registration;

  String get recipient => EpochKeyDelivery.deviceRecipient(deviceId);
}

final class TestAccount {
  const TestAccount({
    required this.accountId,
    required this.certifyingKeys,
    required this.recoverySignKeys,
    required this.recoveryBoxPublicKey,
    required this.recoveryBoxCertificate,
    required this.recoveryEpochOneCopy,
    required this.firstDevice,
  });

  final String accountId;
  final TestKeys certifyingKeys;
  final TestKeys recoverySignKeys;
  final Uint8List recoveryBoxPublicKey;
  final Uint8List recoveryBoxCertificate;
  final Uint8List recoveryEpochOneCopy;
  final TestDevice firstDevice;
}

final class SignedIn {
  const SignedIn({required this.device, required this.response});

  final TestDevice device;
  final SessionResponse response;

  String get token => response.token;

  String get uploadPass => response.uploadPass;

  AuthCredential get session =>
      AuthCredential(AuthScheme.session, response.token);

  AuthCredential get pass =>
      AuthCredential(AuthScheme.uploadPass, response.uploadPass);
}

final class LiveClient {
  LiveClient._(this._socket) {
    _socket.listen(
      (Object? message) {
        _buffer.add('$message');
        _signal();
      },
      onDone: () {
        if (!_closed.isCompleted) {
          _closed.complete();
        }
        _signal();
      },
      onError: (Object _) {},
      cancelOnError: false,
    );
  }

  final WebSocket _socket;
  final List<String> _buffer = <String>[];
  final Completer<void> _closed = Completer<void>();
  Completer<void>? _waiting;

  Future<void> get closed => _closed.future;

  bool get isClosed => _closed.isCompleted;

  int? get closeCode => _socket.closeCode;

  void send(LiveMessage message) => _socket.add(jsonEncode(message.toJson()));

  Future<LiveMessage> next({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (_buffer.isEmpty) {
      if (_closed.isCompleted) {
        throw StateError('The live socket closed');
      }
      final Duration left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) {
        throw TimeoutException('No live message', timeout);
      }
      final Completer<void> waiting = Completer<void>();
      _waiting = waiting;
      await waiting.future.timeout(left, onTimeout: () {});
    }
    return LiveMessage.fromJson(decodeJsonObject(_buffer.removeAt(0)));
  }

  Future<void> close() => _socket.close();

  void _signal() {
    final Completer<void>? waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) {
      waiting.complete();
    }
  }
}

final class RelayHarness {
  RelayHarness._({
    required this.root,
    required this.config,
    required this.migrationsDirectory,
    required this.sodium,
    required this.beforeAssembly,
    required this._now,
  });

  static Future<RelayHarness> start({
    String? dataDirectory,
    String? migrationsDirectory,
    AssemblyHook? beforeAssembly,
  }) async {
    final Directory root = await Directory.systemTemp.createTemp(
      'relay_harness_',
    );
    final String data = dataDirectory ?? p.join(root.path, 'data');
    final RelayHarness harness = RelayHarness._(
      root: root,
      config: RelayConfig(
        databasePath: p.join(data, 'relay.sqlite3'),
        mediaDirectory: p.join(data, 'media'),
        port: 0,
      ),
      migrationsDirectory: migrationsDirectory ?? defaultMigrationsDirectory(),
      sodium: await SodiumInit.init(),
      beforeAssembly: beforeAssembly,
      now: harnessStart,
    );
    await harness.boot();
    return harness;
  }

  final Directory root;
  final RelayConfig config;
  final String migrationsDirectory;
  final Sodium sodium;
  final AssemblyHook? beforeAssembly;
  final List<String> logLines = <String>[];
  final http.Client client = http.Client();
  DateTime _now;
  RelayServer? _server;

  DateTime get now => _now;

  DateTime clock() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  RelayApp get app => _server!.app;

  RelayDatabase get database => app.database;

  String get databasePath => config.databasePath;

  String get mediaDirectory => config.mediaDirectory;

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server!.port}');

  bool get running => _server != null;

  Future<void> boot() async {
    final RelayApp app = await RelayApp.open(
      config: config,
      migrationsDirectory: migrationsDirectory,
      clock: clock,
      logSink: logLines.add,
      beforeAssembly: beforeAssembly,
    );
    _server = await RelayServer.serve(
      app,
      address: InternetAddress.loopbackIPv4,
      port: 0,
      tickInterval: null,
    );
  }

  Future<void> stop() async {
    final RelayServer? server = _server;
    _server = null;
    await server?.close();
  }

  Future<void> restart() async {
    await stop();
    await boot();
  }

  Future<void> tick() => app.tick();

  Future<void> dispose() async {
    await stop();
    client.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }

  TestKeys signKeys() {
    final KeyPair pair = sodium.crypto.sign.keyPair();
    return TestKeys(publicKey: pair.publicKey, secretKey: pair.secretKey);
  }

  Uint8List sign(TestKeys keys, Uint8List message) =>
      sodium.crypto.sign.detached(message: message, secretKey: keys.secretKey);

  Uint8List randomOpaque(int length) => sodium.randombytes.buf(length);

  TestDevice newDevice(TestKeys certifyingKeys) {
    final String deviceId = newSyncId();
    final TestKeys keys = signKeys();
    final Uint8List boxPublicKey = sodium.crypto.box.keyPair().publicKey;
    return TestDevice(
      deviceId: deviceId,
      signKeys: keys,
      boxPublicKey: boxPublicKey,
      registration: DeviceRegistration(
        deviceId: deviceId,
        signPublicKey: keys.publicKey,
        boxPublicKey: boxPublicKey,
        certificate: sign(
          certifyingKeys,
          deviceCertificateBytes(
            deviceId: deviceId,
            signPublicKey: keys.publicKey,
            boxPublicKey: boxPublicKey,
          ),
        ),
        encryptedName: randomOpaque(48),
      ),
    );
  }

  CreatedInvite createInvite([String note = 'Test journal']) =>
      app.accounts.createInvite(note);

  InviteRedeemRequest redeemRequest(
    String code, {
    required TestKeys certifyingKeys,
    required TestDevice device,
    required TestKeys recoverySignKeys,
    required Uint8List recoveryBoxPublicKey,
    required Uint8List recoveryEpochOneCopy,
  }) => InviteRedeemRequest(
    inviteCode: code,
    device: device.registration,
    recoverySignPublicKey: recoverySignKeys.publicKey,
    recoveryBoxPublicKey: recoveryBoxPublicKey,
    recoveryBoxCertificate: sign(
      certifyingKeys,
      recoveryCertificateBytes(recoveryBoxPublicKey),
    ),
    recoveryEpochOneCopy: recoveryEpochOneCopy,
  );

  Future<TestAccount> enrol({String note = 'Test journal'}) async {
    final CreatedInvite invite = createInvite(note);
    final TestKeys certifyingKeys = signKeys();
    final TestKeys recoverySignKeys = signKeys();
    final Uint8List recoveryBoxPublicKey = sodium.crypto.box
        .keyPair()
        .publicKey;
    final Uint8List epochOneCopy = randomOpaque(72);
    final TestDevice device = newDevice(certifyingKeys);
    final InviteRedeemRequest request = redeemRequest(
      invite.code,
      certifyingKeys: certifyingKeys,
      device: device,
      recoverySignKeys: recoverySignKeys,
      recoveryBoxPublicKey: recoveryBoxPublicKey,
      recoveryEpochOneCopy: epochOneCopy,
    );
    final http.Response response = await send(
      SyncRoutes.redeemInvite,
      body: request,
    );
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('Enrolment failed: ${response.statusCode}');
    }
    return TestAccount(
      accountId: InviteRedeemResponse.fromJson(decodeJsonObject(response.body))
          .accountId,
      certifyingKeys: certifyingKeys,
      recoverySignKeys: recoverySignKeys,
      recoveryBoxPublicKey: recoveryBoxPublicKey,
      recoveryBoxCertificate: request.recoveryBoxCertificate,
      recoveryEpochOneCopy: epochOneCopy,
      firstDevice: device,
    );
  }

  TestDevice addDevice(TestAccount account) {
    final TestDevice device = newDevice(account.certifyingKeys);
    insertDevice(
      database,
      accountId: account.accountId,
      device: device.registration,
      now: _now,
    );
    return device;
  }

  Future<ChallengeResponse> challenge(TestDevice device) async {
    final http.Response response = await send(
      SyncRoutes.sessionChallenge,
      body: ChallengeRequest(deviceId: device.deviceId),
    );
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('Challenge failed: ${response.statusCode}');
    }
    return ChallengeResponse.fromJson(decodeJsonObject(response.body));
  }

  SessionRequest sessionRequest(
    TestDevice device,
    ChallengeResponse challenge, {
    TestKeys? signer,
  }) => SessionRequest(
    challengeId: challenge.challengeId,
    deviceId: device.deviceId,
    signature: sign(
      signer ?? device.signKeys,
      sessionChallengeBytes(
        challengeId: challenge.challengeId,
        nonce: challenge.nonce,
        deviceId: device.deviceId,
      ),
    ),
  );

  Future<SignedIn> signIn(TestDevice device) async {
    final http.Response response = await send(
      SyncRoutes.session,
      body: sessionRequest(device, await challenge(device)),
    );
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('Sign-in failed: ${response.statusCode}');
    }
    return SignedIn(
      device: device,
      response: SessionResponse.fromJson(decodeJsonObject(response.body)),
    );
  }

  EpochRotation rotation({
    required TestDevice signer,
    required int epoch,
    required List<String> recipients,
  }) => EpochRotation(
    epoch: epoch,
    signerDeviceId: signer.deviceId,
    deliveries: <EpochKeyDelivery>[
      for (final String recipient in recipients)
        _delivery(signer, epoch, recipient),
    ],
  );

  EpochKeyDelivery _delivery(TestDevice signer, int epoch, String recipient) {
    final Uint8List sealed = randomOpaque(80);
    return EpochKeyDelivery(
      recipient: recipient,
      sealed: sealed,
      signature: sign(
        signer.signKeys,
        epochDeliveryBytes(
          epoch: epoch,
          recipient: recipient,
          sealed: sealed,
          signerDeviceId: signer.deviceId,
        ),
      ),
    );
  }

  Future<http.Response> removeDevice(
    SignedIn remover,
    String deviceId,
    EpochRotation rotation,
  ) => send(
    SyncRoutes.removeDevice,
    parameters: <String, Object>{SyncRoutes.deviceIdParameter: deviceId},
    credential: remover.session,
    body: DeviceRemoveRequest(rotation: rotation),
  );

  RecordPush record(
    String recordKey, {
    int baseSeq = 0,
    int epoch = 1,
    String? changeId,
    List<int>? envelope,
  }) => RecordPush(
    recordKey: recordKey,
    baseSeq: baseSeq,
    changeId: changeId ?? newSyncId(),
    epoch: epoch,
    envelope: Uint8List.fromList(envelope ?? randomOpaque(64)),
  );

  Future<PushResponse> push(
    AuthCredential credential,
    List<RecordPush> changes,
  ) async {
    final http.Response response = await send(
      SyncRoutes.pushRecords,
      credential: credential,
      body: PushRequest(changes: changes),
    );
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('Push failed: ${response.statusCode}');
    }
    return PushResponse.fromJson(decodeJsonObject(response.body));
  }

  Future<PullResponse> pull(
    AuthCredential credential, {
    int after = 0,
    int? limit,
  }) async {
    final http.Response response = await send(
      SyncRoutes.pullRecords,
      credential: credential,
      query: <String, String>{
        SyncRoutes.afterQuery: '$after',
        if (limit != null) SyncRoutes.limitQuery: '$limit',
      },
    );
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('Pull failed: ${response.statusCode}');
    }
    return PullResponse.fromJson(decodeJsonObject(response.body));
  }

  Future<http.Response> putPart(
    AuthCredential credential, {
    required String name,
    required String uploadId,
    required int index,
    required int blobSize,
    required int partSize,
    required List<int> bytes,
  }) => send(
    SyncRoutes.uploadPart,
    parameters: <String, Object>{
      SyncRoutes.nameParameter: name,
      SyncRoutes.uploadIdParameter: uploadId,
      SyncRoutes.indexParameter: index,
    },
    credential: credential,
    headers: <String, String>{
      SyncHeaders.blobSize: '$blobSize',
      SyncHeaders.partSize: '$partSize',
    },
    bytes: bytes,
  );

  Future<void> uploadBlob(
    AuthCredential credential,
    String name,
    List<int> ciphertext, {
    int partSize = 1024,
  }) async {
    final String uploadId = newSyncId();
    final int parts = (ciphertext.length + partSize - 1) ~/ partSize;
    for (int index = 0; index < parts; index++) {
      final int start = index * partSize;
      final int end = start + partSize > ciphertext.length
          ? ciphertext.length
          : start + partSize;
      final http.Response response = await putPart(
        credential,
        name: name,
        uploadId: uploadId,
        index: index,
        blobSize: ciphertext.length,
        partSize: partSize,
        bytes: ciphertext.sublist(start, end),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('Upload failed: ${response.statusCode}');
      }
    }
  }

  String blobName() => encodeBase64Url(randomOpaque(32));

  Future<LiveClient> openLive(String token) async {
    final WebSocket socket = await WebSocket.connect(
      SyncRoutes.live.uri(baseUrl).replace(scheme: 'ws').toString(),
      headers: <String, Object>{
        SyncHeaders.protocol: '$syncProtocolVersion',
        SyncHeaders.authorization: AuthScheme.session.authorization(token),
      },
    );
    return LiveClient._(socket);
  }

  Uri uri(
    SyncRoute route, {
    Map<String, Object> parameters = const <String, Object>{},
    Map<String, String> query = const <String, String>{},
  }) => route.uri(baseUrl, parameters: parameters, query: query);

  Future<http.Response> send(
    SyncRoute route, {
    Map<String, Object> parameters = const <String, Object>{},
    Map<String, String> query = const <String, String>{},
    AuthCredential? credential,
    SyncMessage? body,
    List<int>? bytes,
    Map<String, String> headers = const <String, String>{},
    bool protocol = true,
  }) async {
    final http.Request request =
        http.Request(
            route.method,
            uri(route, parameters: parameters, query: query),
          )
          ..headers.addAll(<String, String>{
            if (protocol) SyncHeaders.protocol: '$syncProtocolVersion',
            if (credential != null)
              SyncHeaders.authorization: credential.authorization,
            if (body != null) 'content-type': 'application/json',
            ...headers,
          });
    if (body != null) {
      request.body = jsonEncode(body.toJson());
    } else if (bytes != null) {
      request.bodyBytes = bytes;
    }
    return http.Response.fromStream(await client.send(request));
  }
}

ErrorResponse errorOf(http.Response response) =>
    ErrorResponse.fromJson(decodeJsonObject(response.body));
