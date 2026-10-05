import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sodium/sodium.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'accounts.dart';
import 'auth.dart';
import 'blobs.dart';
import 'change_log.dart';
import 'config.dart';
import 'database.dart';
import 'devices.dart';
import 'live.dart';
import 'logging.dart';
import 'migrations.dart';
import 'pairing.dart';
import 'probes.dart';
import 'trash.dart';

const Duration purgeInterval = Duration(hours: 24);

DateTime systemClock() => DateTime.now().toUtc();

Stream<List<int>> guardedRead(File file) async* {
  try {
    await for (final List<int> chunk in file.openRead()) {
      yield chunk;
    }
  } on FileSystemException {
    return;
  }
}

final class RelayApp {
  RelayApp._({
    required this.config,
    required this.clock,
    required this.database,
    required this.accounts,
    required this.sessions,
    required this.changeLog,
    required this.live,
    required this.blobs,
    required this.devices,
    required this.pairing,
    required this.restores,
    required this._logSink,
  }) : _lastPurge = clock();

  static Future<RelayApp> open({
    required RelayConfig config,
    String? migrationsDirectory,
    DateTime Function()? clock,
    LogSink logSink = stdoutLogSink,
    AssemblyHook? beforeAssembly,
    FreeSpaceProbe freeSpace = dfFreeBytes,
  }) async {
    final DateTime Function() now = clock ?? systemClock;
    migrate(
      databasePath: config.databasePath,
      migrationsDirectory: migrationsDirectory ?? defaultMigrationsDirectory(),
      now: now(),
    );
    await Directory(config.mediaDirectory).create(recursive: true);
    final RelayDatabase database = RelayDatabase.open(config.databasePath);
    final Sodium sodium = await SodiumInit.init();
    final Challenges challenges = Challenges(database, now);
    await clearLeftovers(database, config.mediaDirectory);
    final BlobStore blobs = BlobStore(
      database: database,
      mediaDirectory: config.mediaDirectory,
      clock: now,
      freeSpace: CachedProbe<int?>(
        probe: () => freeSpace(config.mediaDirectory),
        clock: now,
      ),
      minFreeBytes: config.minFreeBytes,
      beforeAssembly: beforeAssembly,
    )..prepare();
    final Sessions sessions = Sessions(
      database: database,
      clock: now,
      sodium: sodium,
      challenges: challenges,
    );
    final RelayApp app = RelayApp._(
      config: config,
      clock: now,
      database: database,
      accounts: Accounts(database, now),
      sessions: sessions,
      changeLog: ChangeLog(database, now),
      live: LiveHub(now, sessions.isCurrent),
      blobs: blobs,
      devices: Devices(database, config.mediaDirectory, now),
      pairing: Pairing(database, now),
      restores: Restores(
        database: database,
        clock: now,
        sodium: sodium,
        challenges: challenges,
      ),
      logSink: logSink,
    );
    await app.purge();
    return app;
  }

  final RelayConfig config;
  final DateTime Function() clock;
  final RelayDatabase database;
  final Accounts accounts;
  final Sessions sessions;
  final ChangeLog changeLog;
  final LiveHub live;
  final BlobStore blobs;
  final Devices devices;
  final Pairing pairing;
  final Restores restores;
  final LogSink _logSink;
  final Set<Future<void>> _deletions = <Future<void>>{};
  late final CachedProbe<bool> _health = CachedProbe<bool>(
    probe: _probeHealth,
    clock: clock,
  );
  DateTime _lastPurge;
  Future<void>? _purging;

  late final Handler handler = const Pipeline()
      .addMiddleware(requestLogger(_logSink, clock))
      .addHandler(_router().call);

  Future<void> tick() async {
    live.sweep();
    if (!clock().isBefore(_lastPurge.add(purgeInterval))) {
      await purge();
    }
  }

  Future<void> purge() => _purging ??= _runPurge().whenComplete(() {
    _purging = null;
  });

  Future<void> _runPurge() async {
    _lastPurge = clock();
    await blobs.purge();
    sessions.purgeExpired();
    pairing.purgeExpired();
  }

  void reportInternalError(Object error, StackTrace stackTrace) =>
      _logSink(internalErrorLine(clock()));

  Future<void> close() async {
    await live.closeAll();
    await _purging;
    await Future.wait(_deletions.toList());
    database.close();
  }

  void _deleteLater(Directory directory) {
    final Future<void> deletion = deleteQuietly(directory);
    _deletions.add(deletion);
    unawaited(deletion.whenComplete(() => _deletions.remove(deletion)));
  }

  Router _router() {
    final Router router = Router(notFoundHandler: _notFound);
    void add(SyncRoute route, Access access, Handler handler) {
      Pipeline pipeline = const Pipeline();
      if (route != SyncRoutes.health) {
        pipeline = pipeline.addMiddleware(protocolGate());
      }
      final Handler guarded = pipeline
          .addMiddleware(authorization(sessions, route, access))
          .addHandler(handler);
      router.add(
        route.method,
        route.pattern,
        (Request request) => _guard(route, guarded, request),
      );
    }

    add(SyncRoutes.redeemInvite, Access.open, _redeem);
    add(SyncRoutes.sessionChallenge, Access.open, _sessionChallenge);
    add(SyncRoutes.session, Access.open, _session);
    add(SyncRoutes.pushRecords, Access.sessionOrUploadPass, _push);
    add(SyncRoutes.pullRecords, Access.session, _pull);
    add(SyncRoutes.live, Access.session, _live);
    add(SyncRoutes.blobExists, Access.session, _blobExists);
    add(SyncRoutes.downloadBlob, Access.session, _downloadBlob);
    add(SyncRoutes.uploadStatus, Access.session, _uploadStatus);
    add(SyncRoutes.uploadPart, Access.sessionOrUploadPass, _uploadPart);
    add(SyncRoutes.reportUnusedBlobs, Access.session, _reportUnused);
    add(SyncRoutes.reportReferencedBlobs, Access.session, _reportReferenced);
    add(SyncRoutes.keys, Access.session, _keys);
    add(SyncRoutes.openPairing, Access.session, _openPairing);
    add(SyncRoutes.joinPairing, Access.mailbox, _joinPairing);
    add(SyncRoutes.pairingStatus, Access.sessionOrMailbox, _pairingStatus);
    add(SyncRoutes.completePairing, Access.session, _completePairing);
    add(SyncRoutes.restoreChallenge, Access.open, _restoreChallenge);
    add(SyncRoutes.restore, Access.open, _restore);
    add(SyncRoutes.registerRestoredDevice, Access.open, _registerRestored);
    add(SyncRoutes.devices, Access.session, _devices);
    add(SyncRoutes.removeDevice, Access.session, _removeDevice);
    add(SyncRoutes.eraseJournal, Access.session, _eraseJournal);
    add(SyncRoutes.health, Access.open, _healthCheck);
    return router;
  }

  Future<Response> _guard(
    SyncRoute route,
    Handler handler,
    Request request,
  ) async {
    final Map<String, Object> attribution = <String, Object>{
      LogContext.route: route.pattern,
    };
    Response response;
    try {
      response = await handler(request);
    } on AttributedHijack catch (hijack) {
      throw AttributedHijack(<String, Object>{
        ...hijack.attributes,
        ...attribution,
      });
    } on HijackException {
      throw AttributedHijack(attribution);
    } catch (error) {
      response = knownErrorResponse(error) ?? Response.internalServerError();
    }
    final Response attributed = response.change(context: attribution);
    return request.method == 'HEAD' ? _withoutBody(attributed) : attributed;
  }

  static Response _withoutBody(Response response) => response.change(
    headers: <String, String>{
      if (response.headers.containsKey('content-length')) 'content-length': '0',
    },
    body: const <int>[],
  );

  Response _notFound(Request request) => errorResponse(SyncErrorCode.notFound);

  Future<Response> _redeem(Request request) async => jsonResponse(
    accounts.redeem(
      InviteRedeemRequest.fromJson(
        await readJson(request, maxBytes: smallJsonLimit),
      ),
    ),
  );

  Future<Response> _sessionChallenge(Request request) async => jsonResponse(
    sessions.challenge(
      ChallengeRequest.fromJson(
        await readJson(request, maxBytes: smallJsonLimit),
      ),
    ),
  );

  Future<Response> _session(Request request) async => jsonResponse(
    sessions.signIn(
      SessionRequest.fromJson(
        await readJson(request, maxBytes: smallJsonLimit),
      ),
    ),
  );

  Future<Response> _push(Request request) async {
    final Caller caller = callerOf(request);
    final PushOutcome outcome = changeLog.push(
      caller,
      PushRequest.fromJson(await readJson(request, maxBytes: pushJsonLimit)),
    );
    final int? acceptedSeq = outcome.acceptedSeq;
    if (acceptedSeq != null) {
      live.nudge(caller.accountId, caller.deviceId, acceptedSeq);
    }
    return jsonResponse(outcome.response);
  }

  Response _pull(Request request) => jsonResponse(
    changeLog.pull(
      callerOf(request).accountId,
      PullQuery.parse(request.url.queryParameters),
    ),
  );

  FutureOr<Response> _live(Request request) =>
      live.handler(grantOf(request))(request);

  Response _blobExists(Request request) =>
      blobs.exists(callerOf(request).accountId, _param(request, 'name'))
      ? Response.ok(null)
      : Response.notFound(null);

  Response _downloadBlob(Request request) {
    final File? file = blobs.download(
      callerOf(request).accountId,
      _param(request, SyncRoutes.nameParameter),
    );
    if (file == null) {
      return errorResponse(SyncErrorCode.notFound);
    }
    return Response.ok(
      guardedRead(file),
      headers: <String, String>{
        'content-type': 'application/octet-stream',
        'content-length': '${file.lengthSync()}',
      },
    );
  }

  Future<Response> _uploadStatus(Request request) async => jsonResponse(
    await blobs.status(
      callerOf(request).accountId,
      _param(request, SyncRoutes.nameParameter),
      _param(request, SyncRoutes.uploadIdParameter),
    ),
  );

  Future<Response> _uploadPart(Request request) async {
    final PartUpload part = PartUpload.parse(
      name: _param(request, SyncRoutes.nameParameter),
      uploadId: _param(request, SyncRoutes.uploadIdParameter),
      index: _param(request, SyncRoutes.indexParameter),
      blobSize: request.headers[SyncHeaders.blobSize],
      partSize: request.headers[SyncHeaders.partSize],
    );
    return jsonResponse(
      await blobs.putPart(
        callerOf(request).accountId,
        part,
        request.read(),
        contentLength: request.contentLength,
      ),
    );
  }

  Future<Response> _reportUnused(Request request) async {
    blobs.markUnused(
      callerOf(request).accountId,
      BlobNamesRequest.fromJson(
        await readJson(request, maxBytes: largeJsonLimit),
      ),
    );
    return Response(HttpStatus.noContent);
  }

  Future<Response> _reportReferenced(Request request) async => jsonResponse(
    blobs.markReferenced(
      callerOf(request).accountId,
      BlobNamesRequest.fromJson(
        await readJson(request, maxBytes: largeJsonLimit),
      ),
    ),
  );

  Response _keys(Request request) =>
      jsonResponse(devices.keys(callerOf(request)));

  Future<Response> _openPairing(Request request) async => jsonResponse(
    pairing.open(
      callerOf(request),
      PairingOpenRequest.fromJson(
        await readJson(request, maxBytes: smallJsonLimit),
      ),
    ),
  );

  Future<Response> _joinPairing(Request request) async {
    final String mailboxId = _param(request, SyncRoutes.mailboxIdParameter);
    final String token = credentialOf(request)!.token;
    pairing.verifyToken(mailboxId, token);
    return jsonResponse(
      pairing.join(
        mailboxId,
        token,
        PairingJoinRequest.fromJson(
          await readJson(request, maxBytes: smallJsonLimit),
        ),
      ),
    );
  }

  Response _pairingStatus(Request request) {
    final String mailboxId = _param(request, SyncRoutes.mailboxIdParameter);
    final AuthCredential? credential = credentialOf(request);
    return jsonResponse(
      credential != null && credential.scheme == AuthScheme.mailbox
          ? pairing.statusForToken(mailboxId, credential.token)
          : pairing.statusForCaller(callerOf(request), mailboxId),
    );
  }

  Future<Response> _completePairing(Request request) async => jsonResponse(
    pairing.complete(
      callerOf(request),
      _param(request, SyncRoutes.mailboxIdParameter),
      PairingCompleteRequest.fromJson(
        await readJson(request, maxBytes: largeJsonLimit),
      ),
    ),
  );

  Future<Response> _restoreChallenge(Request request) async => jsonResponse(
    restores.challenge(
      RestoreChallengeRequest.fromJson(
        await readJson(request, maxBytes: smallJsonLimit),
      ),
    ),
  );

  Future<Response> _restore(Request request) async => jsonResponse(
    restores.restore(
      RestoreRequest.fromJson(
        await readJson(request, maxBytes: smallJsonLimit),
      ),
    ),
  );

  Future<Response> _registerRestored(Request request) async {
    restores.register(
      RestoreRegisterRequest.fromJson(
        await readJson(request, maxBytes: smallJsonLimit),
      ),
    );
    return Response(HttpStatus.noContent);
  }

  Response _devices(Request request) =>
      jsonResponse(devices.list(callerOf(request)));

  Future<Response> _removeDevice(Request request) async {
    final String deviceId = _param(request, SyncRoutes.deviceIdParameter);
    devices.remove(
      callerOf(request),
      deviceId,
      DeviceRemoveRequest.fromJson(
        await readJson(request, maxBytes: smallJsonLimit),
      ),
    );
    live.closeDevice(deviceId);
    return Response(HttpStatus.noContent);
  }

  Response _eraseJournal(Request request) {
    final Caller caller = callerOf(request);
    final List<Directory> trashed = devices.eraseJournal(caller);
    live.closeAccount(caller.accountId);
    trashed.forEach(_deleteLater);
    return Response(HttpStatus.noContent);
  }

  Future<Response> _healthCheck(Request request) async => await _health.read()
      ? Response.ok('ok')
      : Response(HttpStatus.serviceUnavailable, body: 'unavailable');

  Future<bool> _probeHealth() async {
    try {
      database.select('SELECT 1');
      final File probe = File(
        p.join(config.mediaDirectory, '.health-${newSecret()}'),
      );
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } on Object {
      return false;
    }
  }

  static String _param(Request request, String name) {
    final String? value = request.params[name];
    if (value == null) {
      throw const RelayException(SyncErrorCode.badRequest);
    }
    return value;
  }
}

final class RelayServer {
  RelayServer._(this.app, this._server, this._timer);

  static Future<RelayServer> serve(
    RelayApp app, {
    Object? address,
    int? port,
    Duration? tickInterval = const Duration(seconds: 5),
  }) async {
    final HttpServer server = await HttpServer.bind(
      address ?? InternetAddress.anyIPv4,
      port ?? app.config.port,
    );
    final Timer? timer = runZonedGuarded<Timer?>(() {
      shelf_io.serveRequests(server, app.handler);
      return tickInterval == null
          ? null
          : Timer.periodic(tickInterval, (_) => unawaited(app.tick()));
    }, app.reportInternalError);
    return RelayServer._(app, server, timer);
  }

  final RelayApp app;
  final HttpServer _server;
  final Timer? _timer;

  int get port => _server.port;

  Future<void> close() async {
    _timer?.cancel();
    await app.live.closeAll();
    await _server.close(force: true);
    await app.close();
  }
}
