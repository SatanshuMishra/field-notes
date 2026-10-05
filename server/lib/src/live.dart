import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'auth.dart';

const Duration liveIdleLimit = Duration(seconds: 90);

const int liveClosedCode = 1000;
const int liveIdleCode = 4000;
const int liveRevokedCode = 4001;

final class _LiveSocket {
  const _LiveSocket({
    required this.accountId,
    required this.deviceId,
    required this.channel,
    required this.lastHeard,
  });

  final String accountId;
  final String deviceId;
  final WebSocketChannel channel;
  final DateTime lastHeard;

  _LiveSocket heardAt(DateTime time) => _LiveSocket(
    accountId: accountId,
    deviceId: deviceId,
    channel: channel,
    lastHeard: time,
  );
}

final class LiveHub {
  LiveHub(this._clock);

  final DateTime Function() _clock;
  final Map<int, _LiveSocket> _sockets = <int, _LiveSocket>{};
  int _nextId = 0;

  int get openCount => _sockets.length;

  Handler handler(Caller caller) => webSocketHandler(
    (WebSocketChannel channel, String? protocol) => _attach(caller, channel),
  );

  void nudge(String accountId, String exceptDeviceId, int latestSeq) {
    final String message = jsonEncode(LiveNudge(latestSeq: latestSeq).toJson());
    for (final _LiveSocket socket in _sockets.values.toList()) {
      if (socket.accountId == accountId && socket.deviceId != exceptDeviceId) {
        socket.channel.sink.add(message);
      }
    }
  }

  void sweep() {
    final DateTime cutoff = _clock().subtract(liveIdleLimit);
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
        socket.channel.sink
            .close(liveClosedCode)
            .timeout(const Duration(seconds: 2), onTimeout: () {})
            .catchError((Object _) {}),
    ]);
  }

  void _closeWhere(bool Function(_LiveSocket socket) test, int code) {
    final List<int> ids = <int>[
      for (final MapEntry<int, _LiveSocket> entry in _sockets.entries)
        if (test(entry.value)) entry.key,
    ];
    for (final int id in ids) {
      final _LiveSocket? socket = _sockets.remove(id);
      unawaited(socket?.channel.sink.close(code).catchError((Object _) {}));
    }
  }

  void _attach(Caller caller, WebSocketChannel channel) {
    final int id = _nextId++;
    _sockets[id] = _LiveSocket(
      accountId: caller.accountId,
      deviceId: caller.deviceId,
      channel: channel,
      lastHeard: _clock(),
    );
    channel.stream.listen(
      (Object? message) => _receive(id, message),
      onDone: () => _sockets.remove(id),
      onError: (Object _) => _sockets.remove(id),
      cancelOnError: true,
    );
  }

  void _receive(int id, Object? message) {
    final _LiveSocket? socket = _sockets[id];
    if (socket == null) {
      return;
    }
    _sockets[id] = socket.heardAt(_clock());
    if (message is! String) {
      return;
    }
    final LiveMessage? live = _decode(message);
    if (live is LivePing) {
      socket.channel.sink.add(jsonEncode(const LivePong().toJson()));
    }
  }

  static LiveMessage? _decode(String message) {
    try {
      return LiveMessage.fromJson(decodeJsonObject(message));
    } on FormatException {
      return null;
    }
  }
}
