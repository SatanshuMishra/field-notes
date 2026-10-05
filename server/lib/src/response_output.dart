import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

import 'in_flight.dart';
import 'request_body.dart';

const Duration responseStallLimit = Duration(seconds: 30);
const Duration fileResponseStallLimit = Duration(minutes: 5);
const int responsePieceBytes = 64 * 1024;

const String stallLimitContextKey = 'relay.stall_limit';

typedef ResponseOutput = Stream<List<int>> Function(Stream<List<int>> body);

Stream<List<int>> passResponse(Stream<List<int>> body) => body;

Iterable<List<int>> _pieces(List<int> chunk) sync* {
  if (chunk.length <= responsePieceBytes) {
    yield chunk;
    return;
  }
  for (int start = 0; start < chunk.length; start += responsePieceBytes) {
    final int end = min(start + responsePieceBytes, chunk.length);
    yield chunk is Uint8List
        ? Uint8List.sublistView(chunk, start, end)
        : chunk.sublist(start, end);
  }
}

final class ResponseOutputs {
  ResponseOutputs(this._clock, {this._output = passResponse});

  final DateTime Function() _clock;
  final ResponseOutput _output;
  final Set<_WatchedResponse> _open = <_WatchedResponse>{};

  int get open => _open.length;

  Stream<List<int>> watch(
    Stream<List<int>> body,
    RequestHold hold,
    void Function()? dropConnection, {
    Duration stallLimit = responseStallLimit,
  }) {
    final _WatchedResponse watched = _WatchedResponse(
      this,
      hold,
      dropConnection,
      stallLimit,
      _clock(),
    );
    _open.add(watched);
    return _output(watched.stream(body));
  }

  void sweep() {
    final DateTime now = _clock();
    for (final _WatchedResponse watched
        in _open
            .where((_WatchedResponse candidate) => candidate.stalled(now))
            .toList()) {
      watched.cutOff();
    }
  }
}

final class _WatchedResponse {
  _WatchedResponse(
    this._outputs,
    this._hold,
    this._drop,
    this._stallLimit,
    this._progressAt,
  );

  final ResponseOutputs _outputs;
  final RequestHold _hold;
  final void Function()? _drop;
  final Duration _stallLimit;
  final ListQueue<List<int>> _waiting = ListQueue<List<int>>();
  DateTime _progressAt;
  StreamController<List<int>>? _out;
  StreamSubscription<List<int>>? _source;
  bool _sourceDone = false;
  bool _ended = false;

  bool stalled(DateTime now) =>
      !_ended && now.difference(_progressAt) > _stallLimit;

  Stream<List<int>> stream(Stream<List<int>> body) {
    final StreamController<List<int>> out = StreamController<List<int>>(
      sync: true,
    );
    _out = out;
    out
      ..onListen = () {
        _source = body.listen(
          (List<int> chunk) {
            _waiting.addAll(_pieces(chunk));
            _flush();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!out.isClosed) {
              out.addError(error, stackTrace);
            }
            _end();
          },
          onDone: () {
            _sourceDone = true;
            _flush();
          },
        );
      }
      ..onResume = () {
        scheduleMicrotask(_flush);
      }
      ..onCancel = _end;
    return out.stream;
  }

  void cutOff() {
    _drop?.call();
    _end();
  }

  void _flush() {
    final StreamController<List<int>>? out = _out;
    if (out == null || out.isClosed || _ended) {
      return;
    }
    while (!out.isPaused && _waiting.isNotEmpty) {
      _progressAt = _outputs._clock();
      out.add(_waiting.removeFirst());
    }
    if (_ended) {
      return;
    }
    final StreamSubscription<List<int>>? source = _source;
    if (_waiting.isNotEmpty) {
      if (source != null && !source.isPaused) {
        source.pause();
      }
      return;
    }
    if (_sourceDone) {
      if (!out.isPaused) {
        unawaited(out.close());
        _end();
      }
      return;
    }
    if (source != null && source.isPaused) {
      source.resume();
    }
  }

  void _end() {
    if (_ended) {
      return;
    }
    _ended = true;
    _outputs._open.remove(this);
    _waiting.clear();
    final Future<void>? cancelled = _source?.cancel();
    if (cancelled != null) {
      unawaited(cancelled);
    }
    _hold.release();
  }
}

Middleware responseGuard(ResponseOutputs outputs) =>
    (Handler inner) => (Request request) async {
      final RequestHold hold = RequestHold();
      final Response response;
      try {
        response = await inner(
          request.change(
            context: <String, Object>{requestHoldContextKey: hold},
          ),
        );
      } catch (_) {
        hold.release();
        rethrow;
      }
      return response.change(
        body: outputs.watch(
          response.read(),
          hold,
          request.context[dropConnectionContextKey] as void Function()?,
          stallLimit:
              response.context[stallLimitContextKey] as Duration? ??
              responseStallLimit,
        ),
      );
    };
