import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

enum MeadowWork { layers, piece, plants, finish }

typedef MeadowGpuMarker = Future<void> Function();

const int _valveFrames = 30;
const double _leastEstimate = 1;
const double _fallbackRate = 60;

@visibleForTesting
MeadowPacer meadowPacer = MeadowPacer();

@immutable
class MeadowBatch {
  const MeadowBatch._(this._id);

  final int _id;
}

class MeadowPacer {
  MeadowPacer({MeadowGpuMarker? marker, int Function()? nowMicros})
    : _marker = marker ?? _drawMarker,
      _clock = nowMicros ?? _stopwatch();

  final MeadowGpuMarker _marker;
  final int Function() _clock;
  Map<MeadowWork, double> _estimates = const <MeadowWork, double>{};
  Map<int, _Pending> _pending = const <int, _Pending>{};
  List<_Turn> _waiting = const <_Turn>[];
  int _nextBatch = 0;
  bool _used = false;
  bool _closing = false;

  static Duration frameInterval(double refreshRate) {
    final double rate = refreshRate.isFinite && refreshRate > 0
        ? refreshRate
        : _fallbackRate;
    return Duration(
      microseconds: (Duration.microsecondsPerSecond / rate).round(),
    );
  }

  static bool keepBuilding({
    required Duration spent,
    required int advanced,
    required Duration frame,
  }) => advanced == 0 || spent < frame ~/ 2;

  int nowMicros() => _clock();

  int allowance(MeadowWork kind, {required Duration share}) {
    final double? estimate = _estimates[kind];
    if (estimate == null) {
      return 1;
    }
    return math.max(1, (share.inMicroseconds / estimate).floor());
  }

  Duration? estimateOf(MeadowWork kind) {
    final double? estimate = _estimates[kind];
    if (estimate == null) {
      return null;
    }
    return Duration(microseconds: math.max(1, estimate.round()));
  }

  bool get isBehind {
    final int now = nowMicros();
    final Map<int, _Pending> kept = <int, _Pending>{
      for (final MapEntry<int, _Pending> entry in _pending.entries)
        if (!entry.value.lostBy(now)) entry.key: entry.value,
    };
    if (kept.length != _pending.length) {
      _pending = Map<int, _Pending>.unmodifiable(kept);
    }
    return kept.values.where((_Pending pending) => pending.waiting).length >= 2;
  }

  MeadowBatch begin(MeadowWork kind, {required Duration frame}) {
    final int id = _nextBatch++;
    _store(
      id,
      _Pending(
        kind: kind,
        began: nowMicros(),
        valve: frame.inMicroseconds * _valveFrames,
      ),
    );
    _send(id, after: false);
    return MeadowBatch._(id);
  }

  void end(
    MeadowBatch batch, {
    required int steps,
    void Function(Duration? cost)? answered,
  }) {
    final int id = batch._id;
    final _Pending? pending = _pending[id];
    if (pending == null || pending.ended) {
      return;
    }
    final _Pending ended = pending.end(steps: steps, answered: answered);
    if (ended.failed) {
      _close(id, ended);
      return;
    }
    _store(id, ended);
    _send(id, after: true);
  }

  bool takeFrame() {
    _closeFrame();
    if (_used) {
      return false;
    }
    _used = true;
    return true;
  }

  void waitTurn(Object owner, bool Function() turn) {
    if (!_waiting.any((_Turn waiting) => identical(waiting.owner, owner))) {
      _waiting = List<_Turn>.unmodifiable(<_Turn>[
        ..._waiting,
        (owner: owner, turn: turn),
      ]);
    }
    _closeFrame();
  }

  void leave(Object owner) {
    if (!_waiting.any((_Turn waiting) => identical(waiting.owner, owner))) {
      return;
    }
    _waiting = List<_Turn>.unmodifiable(<_Turn>[
      for (final _Turn waiting in _waiting)
        if (!identical(waiting.owner, owner)) waiting,
    ]);
  }

  void _send(int id, {required bool after}) {
    Future<void> answer;
    try {
      answer = _marker();
    } catch (error, stack) {
      answer = Future<void>.error(error, stack);
    }
    answer.then<void>(
      (_) => _settle(id, after: after, at: nowMicros()),
      onError: (Object error, StackTrace stack) =>
          _settle(id, after: after, at: null),
    );
  }

  void _settle(int id, {required bool after, required int? at}) {
    final _Pending? pending = _pending[id];
    if (pending == null) {
      return;
    }
    final _Pending next = pending.settle(after: after, at: at);
    if (next.failed && !next.ended) {
      _store(id, next);
      return;
    }
    if (!next.failed && next.cost == null) {
      _store(id, next);
      return;
    }
    _close(id, next);
  }

  void _close(int id, _Pending done) {
    _pending = Map<int, _Pending>.unmodifiable(<int, _Pending>{
      for (final MapEntry<int, _Pending> entry in _pending.entries)
        if (entry.key != id) entry.key: entry.value,
    });
    final int? cost = done.failed ? null : done.cost;
    if (cost != null && cost > 0 && done.steps > 0) {
      _learn(done.kind, cost / done.steps);
    }
    final void Function(Duration? cost)? answered = done.answered;
    if (answered == null) {
      return;
    }
    try {
      answered(cost == null ? null : Duration(microseconds: cost));
    } catch (error, stack) {
      _report(error, stack, 'while reporting the cost of a meadow batch');
    }
  }

  void _learn(MeadowWork kind, double perStep) {
    final double? previous = _estimates[kind];
    final double next = previous == null
        ? perStep
        : previous + (perStep - previous) / 2;
    _estimates = Map<MeadowWork, double>.unmodifiable(<MeadowWork, double>{
      ..._estimates,
      kind: math.max(_leastEstimate, next),
    });
  }

  void _store(int id, _Pending pending) {
    _pending = Map<int, _Pending>.unmodifiable(<int, _Pending>{
      ..._pending,
      id: pending,
    });
  }

  void _closeFrame() {
    if (_closing) {
      return;
    }
    _closing = true;
    SchedulerBinding.instance.addPostFrameCallback(_frameEnded);
  }

  void _frameEnded(Duration timeStamp) {
    final List<_Turn> waiting = _waiting;
    final bool used = _used;
    _used = false;
    _waiting = const <_Turn>[];
    _closing = false;
    if (used || isBehind) {
      return;
    }
    for (final _Turn waiter in waiting) {
      bool took = false;
      try {
        took = waiter.turn();
      } catch (error, stack) {
        _report(error, stack, 'while giving a meadow its turn');
      }
      if (took) {
        return;
      }
    }
  }
}

typedef _Turn = ({Object owner, bool Function() turn});

@immutable
class _Pending {
  const _Pending({
    required this.kind,
    required this.began,
    required this.valve,
    this.ended = false,
    this.steps = 0,
    this.answered,
    this.beforeAt,
    this.afterAt,
    this.failed = false,
  });

  final MeadowWork kind;
  final int began;
  final int valve;
  final bool ended;
  final int steps;
  final void Function(Duration? cost)? answered;
  final int? beforeAt;
  final int? afterAt;
  final bool failed;

  bool get waiting => ended && !failed && afterAt == null;

  int? get cost {
    final int? before = beforeAt;
    final int? after = afterAt;
    if (before == null || after == null) {
      return null;
    }
    return after - before;
  }

  bool lostBy(int now) => ended && now - began > valve;

  _Pending end({
    required int steps,
    required void Function(Duration? cost)? answered,
  }) => _Pending(
    kind: kind,
    began: began,
    valve: valve,
    ended: true,
    steps: steps,
    answered: answered,
    beforeAt: beforeAt,
    afterAt: afterAt,
    failed: failed,
  );

  _Pending settle({required bool after, required int? at}) => _Pending(
    kind: kind,
    began: began,
    valve: valve,
    ended: ended,
    steps: steps,
    answered: answered,
    beforeAt: after ? beforeAt : at,
    afterAt: after ? at : afterAt,
    failed: failed || at == null,
  );
}

void _report(Object error, StackTrace stack, String context) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'meadow pacer',
      context: ErrorDescription(context),
    ),
  );
}

int Function() _stopwatch() {
  final Stopwatch watch = Stopwatch()..start();
  return () => watch.elapsedMicroseconds;
}

Future<void> _drawMarker() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, 1, 1));
  final ui.Picture picture = recorder.endRecording();
  try {
    final ui.Image image = await picture.toImage(1, 1);
    image.dispose();
  } finally {
    picture.dispose();
  }
}
