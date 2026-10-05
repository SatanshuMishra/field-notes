import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'auth.dart';
import 'database.dart';
import 'live_guard.dart';
import 'timers.dart';

const Duration liveIdleLimit = Duration(seconds: 90);
const Duration liveCloseLimit = Duration(seconds: 5);
const int maxLiveSocketsPerDevice = 4;
const int maxLiveFrameBytes = 4 * 1024;

const int liveClosedCode = 1000;
const int liveTooFastCode = 1008;
const int liveTooBigCode = 1009;
const int liveIdleCode = 4000;
const int liveRevokedCode = 4001;
const int liveReplacedCode = 4002;

typedef GrantCheck = bool Function(SessionGrant grant);

final class _LiveSocket {
  const _LiveSocket({
    required this.grant,
    required this.webSocket,
    required this.socket,
    required this.ended,
    required this.lastHeard,
  });

  final SessionGrant grant;
  final WebSocket webSocket;
  final Socket socket;
  final Future<void> ended;
  final DateTime lastHeard;

  String get accountId => grant.caller.accountId;

  String get deviceId => grant.caller.deviceId;

  DateTime get expiresAt => grant.expiresAt;

  void send(String message) {
    if (webSocket.readyState == WebSocket.open) {
      webSocket.add(message);
    }
  }

  _LiveSocket heardAt(DateTime time) => _LiveSocket(
    grant: grant,
    webSocket: webSocket,
    socket: socket,
    ended: ended,
    lastHeard: time,
  );
}

bool _hasToken(String? header, String token) =>
    header != null &&
    header
        .toLowerCase()
        .split(',')
        .map((String part) => part.trim())
        .contains(token);

final class LiveHub {
  LiveHub(this._clock, this._isCurrent, {this._startTimer = Timer.new});

  final DateTime Function() _clock;
  final GrantCheck _isCurrent;
  final StartTimer _startTimer;
  final Map<int, _LiveSocket> _sockets = <int, _LiveSocket>{};
  final Map<int, ({Socket socket, Timer deadline})> _closing =
      <int, ({Socket socket, Timer deadline})>{};
  int _nextId = 0;

  int get openCount => _sockets.length;

  int get closingCount => _closing.length;

  Handler handler(SessionGrant grant) =>
      (Request request) => _upgrade(grant, request);

  void nudge(String accountId, String exceptDeviceId, int latestSeq) {
    final String message = jsonEncode(LiveNudge(latestSeq: latestSeq).toJson());
    for (final _LiveSocket socket in _sockets.values.toList()) {
      if (socket.accountId == accountId && socket.deviceId != exceptDeviceId) {
        socket.send(message);
      }
    }
  }

  void sweep() {
    final DateTime now = _clock();
    _closeWhere(
      (_LiveSocket socket) =>
          !socket.expiresAt.isAfter(now) || !_isCurrent(socket.grant),
      liveRevokedCode,
    );
    final DateTime cutoff = now.subtract(liveIdleLimit);
    _closeWhere(
      (_LiveSocket socket) => !socket.lastHeard.isAfter(cutoff),
      liveIdleCode,
    );
  }

  void closeDevice(String deviceId) => _closeWhere(
    (_LiveSocket socket) => socket.deviceId == deviceId,
    liveRevokedCode,
  );

  void closeAccount(String accountId) => _closeWhere(
    (_LiveSocket socket) => socket.accountId == accountId,
    liveRevokedCode,
  );

  Future<void> closeAll() async {
    final List<_LiveSocket> sockets = _sockets.values.toList();
    _sockets.clear();
    await Future.wait(<Future<void>>[
      for (final _LiveSocket socket in sockets)
        socket.webSocket
            .close(liveClosedCode)
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () => socket.socket.destroy(),
            )
            .catchError((Object _) {}),
    ]);
    for (final ({Socket socket, Timer deadline}) closing
        in _closing.values.toList()) {
      closing.deadline.cancel();
      closing.socket.destroy();
    }
    _closing.clear();
  }

  Response _upgrade(SessionGrant grant, Request request) {
    final String? key = request.headers['sec-websocket-key'];
    if (request.method != 'GET' ||
        !_hasToken(request.headers['connection'], 'upgrade') ||
        request.headers['upgrade']?.toLowerCase() != 'websocket') {
      throw const RelayException(SyncErrorCode.notFound);
    }
    if (request.headers['sec-websocket-version'] != '13' ||
        request.protocolVersion != '1.1' ||
        key == null) {
      throw const RelayException(SyncErrorCode.badRequest);
    }
    request.hijack((channel) {
      final Socket socket = channel.sink as Socket;
      socket.add(
        utf8.encode(
          'HTTP/1.1 101 Switching Protocols\r\n'
          'Upgrade: websocket\r\n'
          'Connection: Upgrade\r\n'
          'Sec-WebSocket-Accept: ${WebSocketChannel.signKey(key)}\r\n'
          '\r\n',
        ),
      );
      _attach(grant, socket);
    });
  }

  void _closeWhere(bool Function(_LiveSocket socket) test, int code) {
    final List<int> ids = <int>[
      for (final MapEntry<int, _LiveSocket> entry in _sockets.entries)
        if (test(entry.value)) entry.key,
    ];
    for (final int id in ids) {
      _close(id, code);
    }
  }

  void _close(int id, int code) {
    final _LiveSocket? socket = _sockets.remove(id);
    if (socket == null) {
      return;
    }
    _awaitClosed(id, socket);
    unawaited(socket.webSocket.close(code).catchError((Object _) {}));
  }

  void _ended(int id) {
    final _LiveSocket? socket = _sockets.remove(id);
    if (socket != null) {
      _awaitClosed(id, socket);
    }
  }

  void _awaitClosed(int id, _LiveSocket socket) {
    _closing[id] = (
      socket: socket.socket,
      deadline: _startTimer(liveCloseLimit, () {
        _closing.remove(id);
        socket.socket.destroy();
      }),
    );
    void finished(Object? _) {
      _closing.remove(id)?.deadline.cancel();
    }

    unawaited(
      Future.wait<void>(<Future<void>>[socket.ended, socket.webSocket.done])
          .then(finished, onError: finished),
    );
  }

  void _attach(SessionGrant grant, Socket socket) {
    final int id = _nextId++;
    final Completer<void> ended = Completer<void>();
    void end() {
      if (!ended.isCompleted) {
        ended.complete();
      }
      _ended(id);
    }

    final WebSocket webSocket = WebSocket.fromUpgradedSocket(
      GuardedSocket(
        socket,
        guardedFrames(
          socket,
          LiveFrameGuard(maxLiveFrameBytes, _clock),
          (LiveRefusal refusal) => _close(id, switch (refusal) {
            LiveRefusal.tooBig => liveTooBigCode,
            LiveRefusal.tooFast => liveTooFastCode,
          }),
        ),
      ),
      serverSide: true,
    );
    _sockets[id] = _LiveSocket(
      grant: grant,
      webSocket: webSocket,
      socket: socket,
      ended: ended.future,
      lastHeard: _clock(),
    );
    webSocket.listen(
      (Object? message) => _receive(id, message),
      onDone: end,
      onError: (Object _) => end(),
      cancelOnError: true,
    );
    final List<int> sameDevice = <int>[
      for (final MapEntry<int, _LiveSocket> entry in _sockets.entries)
        if (entry.value.deviceId == grant.caller.deviceId) entry.key,
    ];
    if (sameDevice.length > maxLiveSocketsPerDevice) {
      for (final int oldest in sameDevice.take(
        sameDevice.length - maxLiveSocketsPerDevice,
      )) {
        _close(oldest, liveReplacedCode);
      }
    }
  }

  void _receive(int id, Object? message) {
    final _LiveSocket? socket = _sockets[id];
    if (socket == null) {
      return;
    }
    if (_frameBytes(message) > maxLiveFrameBytes) {
      _close(id, liveTooBigCode);
      return;
    }
    _sockets[id] = socket.heardAt(_clock());
    if (message is! String) {
      return;
    }
    final LiveMessage? live = _decode(message);
    if (live is LivePing) {
      socket.send(jsonEncode(const LivePong().toJson()));
    }
  }

  static int _frameBytes(Object? message) => switch (message) {
    String() when message.length > maxLiveFrameBytes => message.length,
    String() => utf8.encode(message).length,
    List<int>() => message.length,
    _ => 0,
  };

  static LiveMessage? _decode(String message) {
    try {
      return LiveMessage.fromJson(decodeJsonObject(message));
    } on FormatException {
      return null;
    }
  }
}
