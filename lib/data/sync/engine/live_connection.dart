import 'dart:async';
import 'dart:convert';

import 'package:sync_protocol/sync_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const Duration livePingInterval = Duration(seconds: 30);
const Duration liveSilenceLimit = Duration(seconds: 75);

abstract interface class SyncClock {
  DateTime now();

  Timer timer(Duration delay, void Function() callback);

  Timer periodic(Duration period, void Function() callback);
}

final class SystemSyncClock implements SyncClock {
  const SystemSyncClock();

  @override
  DateTime now() => DateTime.now().toUtc();

  @override
  Timer timer(Duration delay, void Function() callback) =>
      Timer(delay, callback);

  @override
  Timer periodic(Duration period, void Function() callback) =>
      Timer.periodic(period, (Timer _) => callback());
}

typedef LiveConnector = Future<WebSocketChannel> Function();

final class LiveConnection {
  LiveConnection({
    required this._connect,
    required this._clock,
    required this._onNudge,
    required this._onClosed,
    this._pingInterval = livePingInterval,
    this._silenceLimit = liveSilenceLimit,
  });

  final LiveConnector _connect;
  final SyncClock _clock;
  final void Function(int latestSeq) _onNudge;
  final void Function() _onClosed;
  final Duration _pingInterval;
  final Duration _silenceLimit;
  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  Timer? _pings;
  DateTime? _heard;
  bool _closing = false;

  bool get isOpen => _channel != null;

  Future<void> open() async {
    if (_channel != null) {
      return;
    }
    _closing = false;
    final WebSocketChannel channel = await _connect();
    if (_closing) {
      await channel.sink.close();
      return;
    }
    _channel = channel;
    _subscription = channel.stream.listen(
      _receive,
      onDone: () => _lost(channel),
      onError: (Object _) => _lost(channel),
      cancelOnError: true,
    );
    _heard = _clock.now();
    _pings = _clock.periodic(_pingInterval, () => _keepAlive(channel));
  }

  void _keepAlive(WebSocketChannel channel) {
    final DateTime? heard = _heard;
    if (heard != null && _clock.now().difference(heard) >= _silenceLimit) {
      _abandon(channel);
      return;
    }
    _send(const LivePing());
  }

  void _abandon(WebSocketChannel channel) {
    final StreamSubscription<Object?>? subscription = _subscription;
    _lost(channel);
    unawaited(subscription?.cancel());
    unawaited(
      channel.sink.close().timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      ),
    );
  }

  Future<void> close() async {
    _closing = true;
    final WebSocketChannel? channel = _channel;
    _release();
    await _subscription?.cancel();
    _subscription = null;
    if (channel != null) {
      await channel.sink.close().timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    }
  }

  void _send(LiveMessage message) {
    final WebSocketChannel? channel = _channel;
    if (channel == null) {
      return;
    }
    try {
      channel.sink.add(jsonEncode(message.toJson()));
    } on StateError {
      _lost(channel);
    }
  }

  void _receive(Object? message) {
    _heard = _clock.now();
    if (message is! String) {
      return;
    }
    final LiveMessage live;
    try {
      live = LiveMessage.fromJson(decodeJsonObject(message));
    } on FormatException {
      return;
    }
    if (live is LiveNudge) {
      _onNudge(live.latestSeq);
    }
  }

  void _lost(WebSocketChannel channel) {
    if (!identical(_channel, channel)) {
      return;
    }
    _release();
    _subscription = null;
    if (!_closing) {
      _onClosed();
    }
  }

  void _release() {
    _pings?.cancel();
    _pings = null;
    _heard = null;
    _channel = null;
  }
}
