import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart';

const Duration defaultRetryAfter = Duration(seconds: 30);
const Duration relayRequestTimeout = Duration(seconds: 30);
const String retryAfterHeader = 'retry-after';

sealed class RelayException implements Exception {
  const RelayException();

  String get message;

  @override
  String toString() => '$runtimeType: $message';
}

final class RelayRejected extends RelayException {
  const RelayRejected({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  final SyncErrorCode code;
  @override
  final String message;
  final int statusCode;
}

final class RelayRateLimited extends RelayException {
  const RelayRateLimited(this.retryAfter);

  final Duration retryAfter;

  @override
  String get message => 'Rate limited for ${retryAfter.inSeconds} seconds';
}

final class RelayUnreachable extends RelayException {
  const RelayUnreachable(this.cause);

  final Object cause;

  @override
  String get message => 'The relay could not be reached ($cause)';
}

final class RelayBadResponse extends RelayException {
  const RelayBadResponse(this.statusCode, this.message);

  final int statusCode;
  @override
  final String message;
}

Duration retryAfterOf(Map<String, String> headers) {
  final int? seconds = int.tryParse(headers[retryAfterHeader]?.trim() ?? '');
  return seconds == null || seconds < 0
      ? defaultRetryAfter
      : Duration(seconds: seconds);
}

RelayException relayExceptionFor(
  int statusCode,
  Map<String, String> headers,
  String body,
) {
  if (statusCode == HttpStatus.tooManyRequests) {
    return RelayRateLimited(retryAfterOf(headers));
  }
  try {
    final ErrorResponse error = ErrorResponse.fromJson(decodeJsonObject(body));
    return RelayRejected(
      code: error.code,
      message: error.message,
      statusCode: statusCode,
    );
  } on FormatException {
    return RelayBadResponse(statusCode, 'Unexpected answer $statusCode');
  }
}

final class RelayClient {
  RelayClient({
    required this.baseUrl,
    http.Client? client,
    this.device,
    this.onSession,
    this.timeout = relayRequestTimeout,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _clock = clock ?? _utcNow;

  final Uri baseUrl;
  final DeviceKeys? device;
  final void Function(SessionResponse session)? onSession;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _clock;
  SessionResponse? _session;
  Future<SessionResponse>? _signingIn;

  static DateTime _utcNow() => DateTime.now().toUtc();

  SessionResponse? get session => _session;

  Future<InviteRedeemResponse> redeemInvite(
    InviteRedeemRequest request,
  ) async => InviteRedeemResponse.fromJson(
    await _json(SyncRoutes.redeemInvite, body: request),
  );

  Future<ChallengeResponse> sessionChallenge(String deviceId) async =>
      ChallengeResponse.fromJson(
        await _json(
          SyncRoutes.sessionChallenge,
          body: ChallengeRequest(deviceId: deviceId),
        ),
      );

  Future<SessionResponse> signIn() =>
      _signingIn ??= _signIn().whenComplete(() => _signingIn = null);

  Future<EpochKeysResponse> keys() async =>
      EpochKeysResponse.fromJson(await _authorizedJson(SyncRoutes.keys));

  Future<ChallengeResponse> restoreChallenge(
    Uint8List recoverySignPublicKey,
  ) async => ChallengeResponse.fromJson(
    await _json(
      SyncRoutes.restoreChallenge,
      body: RestoreChallengeRequest(
        recoverySignPublicKey: recoverySignPublicKey,
      ),
    ),
  );

  Future<RestoreResponse> restore(RestoreRequest request) async =>
      RestoreResponse.fromJson(await _json(SyncRoutes.restore, body: request));

  Future<void> registerRestoredDevice(RestoreRegisterRequest request) async {
    await _send(SyncRoutes.registerRestoredDevice, body: request);
  }

  Future<PairingStatusResponse> openPairing(PairingOpenRequest request) async =>
      PairingStatusResponse.fromJson(
        await _authorizedJson(SyncRoutes.openPairing, body: request),
      );

  Future<PairingStatusResponse> pairingStatus(String mailboxId) async =>
      PairingStatusResponse.fromJson(
        await _authorizedJson(
          SyncRoutes.pairingStatus,
          parameters: _mailbox(mailboxId),
        ),
      );

  Future<PairingStatusResponse> completePairing(
    String mailboxId,
    PairingCompleteRequest request,
  ) async => PairingStatusResponse.fromJson(
    await _authorizedJson(
      SyncRoutes.completePairing,
      parameters: _mailbox(mailboxId),
      body: request,
    ),
  );

  Future<PairingStatusResponse> joinPairing(
    String mailboxId,
    String token,
    PairingJoinRequest request,
  ) async => PairingStatusResponse.fromJson(
    await _json(
      SyncRoutes.joinPairing,
      parameters: _mailbox(mailboxId),
      body: request,
      credential: AuthCredential(AuthScheme.mailbox, token),
    ),
  );

  Future<PairingStatusResponse> mailboxStatus(
    String mailboxId,
    String token,
  ) async => PairingStatusResponse.fromJson(
    await _json(
      SyncRoutes.pairingStatus,
      parameters: _mailbox(mailboxId),
      credential: AuthCredential(AuthScheme.mailbox, token),
    ),
  );

  Future<DeviceListResponse> devices() async =>
      DeviceListResponse.fromJson(await _authorizedJson(SyncRoutes.devices));

  Future<void> removeDevice(
    String deviceId,
    DeviceRemoveRequest request,
  ) async {
    await _authorized(
      SyncRoutes.removeDevice,
      parameters: <String, Object>{SyncRoutes.deviceIdParameter: deviceId},
      body: request,
    );
  }

  Future<PushResponse> push(PushRequest request) async => PushResponse.fromJson(
    await _authorizedJson(SyncRoutes.pushRecords, body: request),
  );

  Future<PullResponse> pull({int after = 0, int? limit}) async =>
      PullResponse.fromJson(
        await _authorizedJson(
          SyncRoutes.pullRecords,
          query: <String, String>{
            SyncRoutes.afterQuery: '$after',
            if (limit != null) SyncRoutes.limitQuery: '$limit',
          },
        ),
      );

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  static Map<String, Object> _mailbox(String mailboxId) => <String, Object>{
    SyncRoutes.mailboxIdParameter: mailboxId,
  };

  Future<SessionResponse> _signIn() async {
    final DeviceKeys? keys = device;
    if (keys == null) {
      throw StateError('A relay session needs this device\'s keys');
    }
    final ChallengeResponse challenge = await sessionChallenge(keys.deviceId);
    final SessionResponse session = SessionResponse.fromJson(
      await _json(
        SyncRoutes.session,
        body: SessionRequest(
          challengeId: challenge.challengeId,
          deviceId: keys.deviceId,
          signature: keys.sign(
            sessionChallengeBytes(
              challengeId: challenge.challengeId,
              nonce: challenge.nonce,
              deviceId: keys.deviceId,
            ),
          ),
        ),
      ),
    );
    _session = session;
    onSession?.call(session);
    return session;
  }

  Future<String> _sessionToken() async {
    final SessionResponse? current = _session;
    if (current != null && current.expiresAt.isAfter(_clock())) {
      return current.token;
    }
    return (await signIn()).token;
  }

  Future<Map<String, Object?>> _authorizedJson(
    SyncRoute route, {
    Map<String, Object> parameters = const <String, Object>{},
    Map<String, String> query = const <String, String>{},
    SyncMessage? body,
  }) async => decodeJsonObject(
    (await _authorized(
      route,
      parameters: parameters,
      query: query,
      body: body,
    )).body,
  );

  Future<http.Response> _authorized(
    SyncRoute route, {
    Map<String, Object> parameters = const <String, Object>{},
    Map<String, String> query = const <String, String>{},
    SyncMessage? body,
  }) async {
    final String token = await _sessionToken();
    try {
      return await _send(
        route,
        parameters: parameters,
        query: query,
        body: body,
        credential: AuthCredential(AuthScheme.session, token),
      );
    } on RelayRejected catch (error) {
      if (error.code != SyncErrorCode.unauthorized) {
        rethrow;
      }
      _session = null;
      final SessionResponse renewed = await signIn();
      return _send(
        route,
        parameters: parameters,
        query: query,
        body: body,
        credential: AuthCredential(AuthScheme.session, renewed.token),
      );
    }
  }

  Future<Map<String, Object?>> _json(
    SyncRoute route, {
    Map<String, Object> parameters = const <String, Object>{},
    Map<String, String> query = const <String, String>{},
    SyncMessage? body,
    AuthCredential? credential,
  }) async {
    final http.Response response = await _send(
      route,
      parameters: parameters,
      query: query,
      body: body,
      credential: credential,
    );
    try {
      return decodeJsonObject(response.body);
    } on FormatException {
      throw RelayBadResponse(response.statusCode, 'The relay sent no JSON');
    }
  }

  Future<http.Response> _send(
    SyncRoute route, {
    Map<String, Object> parameters = const <String, Object>{},
    Map<String, String> query = const <String, String>{},
    SyncMessage? body,
    AuthCredential? credential,
  }) async {
    final http.Request request =
        http.Request(
            route.method,
            route.uri(baseUrl, parameters: parameters, query: query),
          )
          ..headers.addAll(<String, String>{
            SyncHeaders.protocol: '$syncProtocolVersion',
            if (credential != null)
              SyncHeaders.authorization: credential.authorization,
            if (body != null) 'content-type': 'application/json',
          });
    if (body != null) {
      request.body = jsonEncode(body.toJson());
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException catch (error) {
      throw RelayUnreachable(error);
    } on SocketException catch (error) {
      throw RelayUnreachable(error);
    } on HandshakeException catch (error) {
      throw RelayUnreachable(error);
    } on http.ClientException catch (error) {
      throw RelayUnreachable(error);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    throw relayExceptionFor(
      response.statusCode,
      response.headers,
      response.body,
    );
  }
}
