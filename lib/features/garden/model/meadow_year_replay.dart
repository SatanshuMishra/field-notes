import 'package:flutter/scheduler.dart';

class MeadowYearReplay {
  MeadowYearReplay({
    required TickerProvider vsync,
    required this.duration,
    required this.onGrowth,
  }) {
    _ticker = vsync.createTicker(_tick);
  }

  final Duration duration;
  final void Function(int point, bool animated) onGrowth;
  late final Ticker _ticker;
  int _limit = 0;
  int _point = 0;

  bool get playing => _ticker.isActive;

  void start({required int limit, required bool reduceMotion}) {
    _ticker.stop();
    if (reduceMotion) {
      onGrowth(limit, false);
      return;
    }
    _limit = limit;
    _point = 0;
    _ticker.start();
    onGrowth(0, true);
  }

  void stop() => _ticker.stop();

  void _tick(Duration elapsed) {
    if (elapsed >= duration) {
      _ticker.stop();
      onGrowth(_limit, true);
      return;
    }
    final int point =
        _limit * elapsed.inMicroseconds ~/ duration.inMicroseconds;
    if (point == _point) {
      return;
    }
    _point = point;
    onGrowth(point, true);
  }

  void dispose() => _ticker.dispose();
}
