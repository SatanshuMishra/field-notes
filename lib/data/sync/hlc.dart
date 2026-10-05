import 'dart:math';

enum HlcReceipt { accepted, heldBack }

int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

class Hlc implements Comparable<Hlc> {
  const Hlc({
    required this.millis,
    required this.counter,
    required this.nodeId,
  });

  factory Hlc.parse(String encoded) {
    final RegExpMatch? match = _encodedPattern.firstMatch(encoded);
    if (match == null) {
      throw FormatException('Not an encoded clock.', encoded);
    }
    return Hlc(
      millis: int.parse(match.group(1)!),
      counter: int.parse(match.group(2)!, radix: 16),
      nodeId: match.group(3)!,
    );
  }

  static const int maxCounter = 0xffff;
  static const int millisDigits = 13;
  static const int counterDigits = 4;

  static final RegExp _encodedPattern = RegExp(
    r'^(\d{13})-([0-9a-f]{4})-(.+)$',
  );

  final int millis;
  final int counter;
  final String nodeId;

  String encode() {
    final String paddedMillis = millis.toString().padLeft(millisDigits, '0');
    final String paddedCounter = counter
        .toRadixString(16)
        .padLeft(counterDigits, '0');
    return '$paddedMillis-$paddedCounter-$nodeId';
  }

  @override
  int compareTo(Hlc other) {
    final int byMillis = millis.compareTo(other.millis);
    if (byMillis != 0) {
      return byMillis;
    }
    final int byCounter = counter.compareTo(other.counter);
    if (byCounter != 0) {
      return byCounter;
    }
    return nodeId.compareTo(other.nodeId);
  }

  bool operator <(Hlc other) => compareTo(other) < 0;

  bool operator <=(Hlc other) => compareTo(other) <= 0;

  bool operator >(Hlc other) => compareTo(other) > 0;

  bool operator >=(Hlc other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hlc &&
          millis == other.millis &&
          counter == other.counter &&
          nodeId == other.nodeId;

  @override
  int get hashCode => Object.hash(millis, counter, nodeId);

  @override
  String toString() => encode();
}

class HlcClock {
  HlcClock({required String nodeId, Hlc? last, int Function()? wallClock})
    : _nodeId = nodeId,
      _wallClock = wallClock ?? _systemMillis,
      _last = last ?? Hlc(millis: 0, counter: 0, nodeId: nodeId);

  static const Duration maxAhead = Duration(minutes: 5);

  final String _nodeId;
  final int Function() _wallClock;
  Hlc _last;

  Hlc get last => _last;

  Hlc now() {
    final int wall = _wallClock();
    final Hlc next = wall > _last.millis
        ? Hlc(millis: wall, counter: 0, nodeId: _nodeId)
        : _tick(_last.millis, _last.counter + 1);
    _last = next;
    return next;
  }

  HlcReceipt receive(Hlc remote) {
    final int wall = _wallClock();
    if (remote.millis - wall > maxAhead.inMilliseconds) {
      return HlcReceipt.heldBack;
    }
    final int millis = max(wall, max(_last.millis, remote.millis));
    final bool atLast = millis == _last.millis;
    final bool atRemote = millis == remote.millis;
    final int counter = atLast && atRemote
        ? max(_last.counter, remote.counter) + 1
        : atLast
        ? _last.counter + 1
        : atRemote
        ? remote.counter + 1
        : 0;
    _last = _tick(millis, counter);
    return HlcReceipt.accepted;
  }

  Hlc _tick(int millis, int counter) {
    if (counter > Hlc.maxCounter) {
      return Hlc(millis: millis + 1, counter: 0, nodeId: _nodeId);
    }
    return Hlc(millis: millis, counter: counter, nodeId: _nodeId);
  }
}
