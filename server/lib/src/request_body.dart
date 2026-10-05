import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'auth.dart';
import 'database.dart';
import 'in_flight.dart';
import 'timers.dart';

const Duration bodyReadLimit = Duration(seconds: 30);
const Duration bodyPaceWindow = Duration(seconds: 30);
const int bodyPaceFloorBytes = 256 * 1024;
const Duration bodyAbortCloseLimit = Duration(seconds: 5);
const int maxDrainBytes = maxPushBodyBytes + 1024 * 1024;
const Duration _paceMergeSpan = Duration(seconds: 1);

const String bodyContextKey = 'relay.body';
const String dropConnectionContextKey = 'relay.drop_connection';

const RelayException bodyTooSlow = RelayException(
  SyncErrorCode.badRequest,
  'Body too slow',
);

enum BodyPace { whole, steady }

final class PaceWindow {
  PaceWindow(this.start);

  final DateTime start;
  final ListQueue<({DateTime at, int bytes})> _recent =
      ListQueue<({DateTime at, int bytes})>();
  int _recentBytes = 0;

  DateTime get deadline => _recentBytes >= bodyPaceFloorBytes
      ? _recent.first.at.add(bodyPaceWindow)
      : start.add(bodyPaceWindow);

  void arrived(DateTime at, int bytes) {
    final ({DateTime at, int bytes})? last = _recent.isEmpty
        ? null
        : _recent.last;
    if (last != null && at.difference(last.at) < _paceMergeSpan) {
      _recent
        ..removeLast()
        ..addLast((at: last.at, bytes: last.bytes + bytes));
    } else {
      _recent.addLast((at: at, bytes: bytes));
    }
    _recentBytes += bytes;
    while (_recent.length > 1 &&
        _recentBytes - _recent.first.bytes >= bodyPaceFloorBytes) {
      _recentBytes -= _recent.removeFirst().bytes;
    }
  }
}

Duration _until(DateTime deadline, DateTime now, Duration longest) {
  final Duration wait = deadline.difference(now);
  if (wait < Duration.zero) {
    return Duration.zero;
  }
  return wait > longest ? longest : wait;
}

final class RequestBody {
  RequestBody(this._request, {required this._startTimer, required this._clock});

  final Request _request;
  final StartTimer _startTimer;
  final DateTime Function() _clock;
  StreamSubscription<List<int>>? _source;
  Timer? _deadline;
  DateTime? _deadlineAt;
  bool _started = false;
  bool _draining = false;
  bool _finished = false;
  bool _aborted = false;
  bool _abandoned = false;

  bool get started => _started;

  bool get aborted => _aborted;

  bool get abandoned => _abandoned;

  bool get empty {
    final int? length = _request.contentLength;
    return length == 0 ||
        (length == null &&
            !_request.headers.containsKey(HttpHeaders.transferEncodingHeader));
  }

  Stream<List<int>> read(BodyPace pace) {
    if (_started) {
      throw StateError('The body is already being read');
    }
    _started = true;
    final StreamController<List<int>> out = StreamController<List<int>>();
    PaceWindow? window;
    void arm(DateTime at, Duration longest) {
      if (_deadlineAt == at) {
        return;
      }
      _deadline?.cancel();
      _deadlineAt = at;
      _deadline = _startTimer(_until(at, _clock(), longest), () {
        if (_finished || _aborted || _abandoned) {
          return;
        }
        _aborted = true;
        _source?.pause();
        if (!out.isClosed) {
          out.addError(bodyTooSlow);
          unawaited(out.close());
        }
      });
    }

    out
      ..onListen = () {
        final DateTime start = _clock();
        if (pace == BodyPace.steady) {
          final PaceWindow pacing = PaceWindow(start);
          window = pacing;
          arm(pacing.deadline, bodyPaceWindow);
        } else {
          arm(start.add(bodyReadLimit), bodyReadLimit);
        }
        _source = _request.read().listen(
          (List<int> chunk) {
            if (out.isClosed) {
              return;
            }
            final PaceWindow? pacing = window;
            if (pacing != null) {
              pacing.arrived(_clock(), chunk.length);
              arm(pacing.deadline, bodyPaceWindow);
            }
            out.add(chunk);
          },
          onError: (Object error, StackTrace stackTrace) {
            _disarm();
            if (!out.isClosed) {
              out.addError(error, stackTrace);
            }
          },
          onDone: () {
            _finished = true;
            _disarm();
            if (!out.isClosed) {
              unawaited(out.close());
            }
          },
        );
      }
      ..onPause = () {
        _source?.pause();
      }
      ..onResume = () {
        if (!_aborted && !_abandoned) {
          _source?.resume();
        }
      }
      ..onCancel = () {
        if (!_finished) {
          _stop();
        }
      };
    return out.stream;
  }

  Future<void> drain() async {
    if (_started) {
      return;
    }
    _draining = true;
    int seen = 0;
    try {
      await for (final List<int> chunk in read(BodyPace.steady)) {
        seen += chunk.length;
        if (seen > maxDrainBytes) {
          return;
        }
      }
    } on Object {
      return;
    }
  }

  void abandon() {
    if (_finished) {
      return;
    }
    if (!_started) {
      _started = true;
      _source = _request.read().listen(null)..pause();
    }
    _stop();
  }

  Future<Response> settle(
    Response response,
    void Function()? dropConnection, {
    bool Function()? mayDrain,
  }) async {
    if (!_started && !empty) {
      if (mayDrain?.call() ?? true) {
        await drain();
      } else {
        abandon();
      }
    }
    if (!_aborted && !_abandoned) {
      return response;
    }
    if (dropConnection != null) {
      _startTimer(bodyAbortCloseLimit, dropConnection);
    }
    final Response answer = _aborted && !_draining
        ? errorResponse(
            bodyTooSlow.code,
            bodyTooSlow.message,
          ).change(context: response.context)
        : response;
    return answer.change(
      headers: const <String, String>{'connection': 'close'},
    );
  }

  void _stop() {
    if (!_aborted) {
      _abandoned = true;
    }
    _disarm();
    _source?.pause();
  }

  void _disarm() {
    _deadline?.cancel();
    _deadline = null;
  }
}

RequestBody bodyOf(Request request) =>
    request.context[bodyContextKey] as RequestBody? ??
    RequestBody(
      request,
      startTimer: Timer.new,
      clock: () => DateTime.now().toUtc(),
    );

Middleware bodyGuard({
  required StartTimer startTimer,
  required DateTime Function() clock,
  RequestsInFlight? addresses,
  String Function(Request request)? addressOf,
}) =>
    (Handler inner) => (Request request) async {
      final RequestBody body = RequestBody(
        request,
        startTimer: startTimer,
        clock: clock,
      );
      final RequestHold? hold = holdOf(request);
      bool mayDrain() =>
          hold == null ||
          addresses == null ||
          addressOf == null ||
          hold.enter(addresses, addressOf(request));
      Response response;
      try {
        response = await inner(
          request.change(context: <String, Object>{bodyContextKey: body}),
        );
      } on HijackException {
        rethrow;
      } catch (_) {
        response = Response.internalServerError();
      }
      return body.settle(
        response,
        request.context[dropConnectionContextKey] as void Function()?,
        mayDrain: mayDrain,
      );
    };
