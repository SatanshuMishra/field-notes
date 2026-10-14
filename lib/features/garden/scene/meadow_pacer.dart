import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

enum MeadowWork { layers, piece, plants, finish }

typedef MeadowGpuMarker = Future<void> Function();

const int _valveFrames = 30;
const int _forgetFrames = 300;
const double _leastEstimate = 1;
const double _fallbackRate = 60;

MeadowPacer meadowPacer = MeadowPacer();

ui.Image meadowSnapshot(ui.Picture picture, int width, int height) {
  final ui.Image image = picture.toImageSync(width, height);
  meadowPacer.countSnapshot();
  return image;
}

@immutable
class MeadowBatch {
  const MeadowBatch._(this._id);

  final int _id;
}

class MeadowPacer {
  MeadowPacer({MeadowGpuMarker? marker, int Function()? nowMicros})
    : _marker = marker ?? _readBack,
      _clock = nowMicros ?? _stopwatch();

  static const int snapshotsPerGap = 4;

  final MeadowGpuMarker _marker;
  final int Function() _clock;
  Map<MeadowWork, double> _estimates = const <MeadowWork, double>{};
  Map<int, _Begun> _begun = const <int, _Begun>{};
  Map<int, _Marked> _marked = const <int, _Marked>{};
  List<_Turn> _waiting = const <_Turn>[];
  int _nextBatch = 0;
  bool _used = false;
  bool _closing = false;
  int _gapSnapshots = 0;
  int _snapshots = 0;
  bool _watchingGaps = false;

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

  int get snapshotRoom => math.max(0, snapshotsPerGap - _gapSnapshots);

  @visibleForTesting
  int get debugSnapshots => _snapshots;

  void countSnapshot() {
    _gapSnapshots++;
    _snapshots++;
    if (_watchingGaps) {
      return;
    }
    _watchingGaps = true;
    SchedulerBinding.instance.addPersistentFrameCallback(_gapEnded);
  }

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
    _sweep(nowMicros());
    return _marked.values.any((_Marked marked) => marked.holds);
  }

  MeadowBatch begin(MeadowWork kind, {required Duration frame}) {
    final int id = _nextBatch++;
    _begun = Map<int, _Begun>.unmodifiable(<int, _Begun>{
      ..._begun,
      id: _Begun(
        kind: kind,
        began: nowMicros(),
        interval: frame.inMicroseconds,
        measured:
            SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle,
      ),
    });
    return MeadowBatch._(id);
  }

  void end(
    MeadowBatch batch, {
    required int steps,
    void Function(Duration? cost)? answered,
  }) {
    final int id = batch._id;
    final _Begun? begun = _begun[id];
    if (begun == null) {
      return;
    }
    _begun = Map<int, _Begun>.unmodifiable(<int, _Begun>{
      for (final MapEntry<int, _Begun> entry in _begun.entries)
        if (entry.key != id) entry.key: entry.value,
    });
    if (!begun.measured) {
      _tell(answered, null);
      return;
    }
    _sweep(nowMicros());
    final int? waiting = _waitingMarker;
    if (waiting != null) {
      _keep(waiting, _marked[waiting]!.carry());
      _tell(answered, null);
      return;
    }
    _keep(id, _Marked(batch: begun, steps: steps, answered: answered));
    _send(id);
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

  int? get _waitingMarker {
    for (final MapEntry<int, _Marked> entry in _marked.entries) {
      if (!entry.value.lapsed) {
        return entry.key;
      }
    }
    return null;
  }

  void _send(int id) {
    Future<void> answer;
    try {
      answer = _marker();
    } catch (error, stack) {
      answer = Future<void>.error(error, stack);
    }
    answer.then<void>(
      (_) => _settle(id, failed: false),
      onError: (Object error, StackTrace stack) => _settle(id, failed: true),
    );
  }

  void _settle(int id, {required bool failed}) {
    final int now = nowMicros();
    _sweep(now);
    final _Marked? marked = _marked[id];
    if (marked == null) {
      return;
    }
    _marked = Map<int, _Marked>.unmodifiable(<int, _Marked>{
      for (final MapEntry<int, _Marked> entry in _marked.entries)
        if (entry.key != id) entry.key: entry.value,
    });
    if (failed) {
      _tell(marked.answered, null);
      return;
    }
    final int cost = now - marked.batch.began;
    if (cost > 0 && marked.steps > 0) {
      _learn(marked.batch.kind, cost / marked.steps);
    }
    _tell(marked.answered, Duration(microseconds: cost));
  }

  void _tell(void Function(Duration? cost)? answered, Duration? cost) {
    if (answered == null) {
      return;
    }
    try {
      answered(cost);
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

  void _sweep(int now) {
    if (_begun.values.any((_Begun begun) => begun.forgottenBy(now))) {
      _begun = Map<int, _Begun>.unmodifiable(<int, _Begun>{
        for (final MapEntry<int, _Begun> entry in _begun.entries)
          if (!entry.value.forgottenBy(now)) entry.key: entry.value,
      });
    }
    if (!_marked.values.any((_Marked marked) => marked.staleBy(now))) {
      return;
    }
    _marked = Map<int, _Marked>.unmodifiable(<int, _Marked>{
      for (final MapEntry<int, _Marked> entry in _marked.entries)
        if (!entry.value.forgottenBy(now))
          entry.key: entry.value.lapsedBy(now)
              ? entry.value.lapse()
              : entry.value,
    });
  }

  void _keep(int id, _Marked marked) {
    _marked = Map<int, _Marked>.unmodifiable(<int, _Marked>{
      ..._marked,
      id: marked,
    });
  }

  void _closeFrame() {
    if (_closing) {
      return;
    }
    _closing = true;
    SchedulerBinding.instance.addPostFrameCallback(_frameEnded);
  }

  void _gapEnded(Duration timeStamp) {
    _gapSnapshots = 0;
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
      final bool took;
      try {
        took = waiter.turn();
      } catch (error, stack) {
        _claimFrame();
        _report(error, stack, 'while giving a meadow its turn');
        return;
      }
      if (took) {
        _claimFrame();
        return;
      }
    }
  }

  void _claimFrame() {
    _used = true;
    _closeFrame();
  }
}

typedef _Turn = ({Object owner, bool Function() turn});

@immutable
class _Begun {
  const _Begun({
    required this.kind,
    required this.began,
    required this.interval,
    required this.measured,
  });

  final MeadowWork kind;
  final int began;
  final int interval;
  final bool measured;

  bool forgottenBy(int now) => now - began > interval * _forgetFrames;
}

@immutable
class _Marked {
  const _Marked({
    required this.batch,
    required this.steps,
    required this.answered,
    this.lapsed = false,
    this.carried = 0,
  });

  final _Begun batch;
  final int steps;
  final void Function(Duration? cost)? answered;
  final bool lapsed;
  final int carried;

  bool get holds => !lapsed && carried > 0;

  bool lapsedBy(int now) =>
      !lapsed && now - batch.began > batch.interval * _valveFrames;

  bool forgottenBy(int now) => batch.forgottenBy(now);

  bool staleBy(int now) => lapsedBy(now) || forgottenBy(now);

  _Marked lapse() => _Marked(
    batch: batch,
    steps: steps,
    answered: answered,
    lapsed: true,
    carried: carried,
  );

  _Marked carry() => _Marked(
    batch: batch,
    steps: steps,
    answered: answered,
    lapsed: lapsed,
    carried: carried + 1,
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

ui.Image? _readBackImage;

Future<void> _readBack() async {
  final ui.Image image = _readBackImage ??= _readBackSnapshot();
  await image.toByteData();
}

ui.Image _readBackSnapshot() {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, 1, 1));
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = meadowSnapshot(picture, 1, 1);
  picture.dispose();
  return image;
}
