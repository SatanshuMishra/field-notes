import 'dart:math';

const int clientRequestBurst = 500;
const double clientRequestsPerSecond = 8;

DateTime _systemNow() => DateTime.now().toUtc();

Future<void> _delay(Duration wait) => Future<void>.delayed(wait);

final class RequestPacer {
  RequestPacer({
    this.burst = clientRequestBurst,
    this.perSecond = clientRequestsPerSecond,
    DateTime Function()? now,
    Future<void> Function(Duration wait)? sleep,
  }) : _now = now ?? _systemNow,
       _sleep = sleep ?? _delay,
       _tokens = burst.toDouble();

  final int burst;
  final double perSecond;
  final DateTime Function() _now;
  final Future<void> Function(Duration wait) _sleep;
  double _tokens;
  DateTime? _counted;

  Future<void> take() async {
    final DateTime now = _now();
    final DateTime? counted = _counted;
    final double elapsed = counted == null
        ? 0
        : max(0, now.difference(counted).inMicroseconds) /
              Duration.microsecondsPerSecond;
    _tokens = min(burst.toDouble(), _tokens + elapsed * perSecond) - 1;
    _counted = now;
    if (_tokens >= 0) {
      return;
    }
    await _sleep(
      Duration(
        microseconds: (-_tokens / perSecond * Duration.microsecondsPerSecond)
            .ceil(),
      ),
    );
  }
}
