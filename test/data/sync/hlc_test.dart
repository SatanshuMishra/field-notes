import 'dart:math';

import 'package:field_notes/data/sync/hlc.dart';
import 'package:flutter_test/flutter_test.dart';

const int _noon = 1790000000000;
const int _oneHour = 60 * 60 * 1000;
const int _fiveMinutes = 5 * 60 * 1000;

void main() {
  test('a change after the wall clock moves back is still later', () {
    int wall = _noon;
    final HlcClock clock = HlcClock(nodeId: 'aaaa', wallClock: () => wall);

    final Hlc first = clock.now();
    wall = _noon - _oneHour;
    final Hlc second = clock.now();

    expect(second > first, isTrue);
    expect(second.encode().compareTo(first.encode()), greaterThan(0));
  });

  test('encoded clocks sort in clock order', () {
    final Random random = Random(29);
    const List<String> nodes = <String>['0a1b', '0a1c', 'ffee', '9'];
    final List<Hlc> clocks = List<Hlc>.generate(
      100,
      (int index) => Hlc(
        millis: _noon + random.nextInt(4) * random.nextInt(1 << 30),
        counter: random.nextInt(3) == 0
            ? random.nextInt(Hlc.maxCounter + 1)
            : random.nextInt(3),
        nodeId: nodes[random.nextInt(nodes.length)],
      ),
    );

    final List<Hlc> byValue = List<Hlc>.of(clocks)..sort();
    final List<Hlc> byEncoding =
        (clocks.map((Hlc clock) => clock.encode()).toList()..sort())
            .map(Hlc.parse)
            .toList();

    expect(byEncoding, byValue);
  });

  test('an encoded clock has fixed-width millis and counter', () {
    const Hlc clock = Hlc(millis: 42, counter: 10, nodeId: '0123456789abcdef');

    expect(clock.encode(), '0000000000042-000a-0123456789abcdef');
    expect(Hlc.parse(clock.encode()), clock);
    expect(() => Hlc.parse('42-a-node'), throwsFormatException);
  });

  test('the counter rises within one millisecond and resets after it', () {
    int wall = _noon;
    final HlcClock clock = HlcClock(nodeId: 'aaaa', wallClock: () => wall);

    final Hlc first = clock.now();
    final Hlc second = clock.now();
    wall = _noon + 1;
    final Hlc third = clock.now();

    expect(first, const Hlc(millis: _noon, counter: 0, nodeId: 'aaaa'));
    expect(second, const Hlc(millis: _noon, counter: 1, nodeId: 'aaaa'));
    expect(third, const Hlc(millis: _noon + 1, counter: 0, nodeId: 'aaaa'));
  });

  test('a full counter moves on to the next millisecond', () {
    final HlcClock clock = HlcClock(
      nodeId: 'aaaa',
      last: const Hlc(millis: _noon, counter: Hlc.maxCounter, nodeId: 'aaaa'),
      wallClock: () => _noon,
    );

    final Hlc next = clock.now();

    expect(next, const Hlc(millis: _noon + 1, counter: 0, nodeId: 'aaaa'));
  });

  test('a clock resumes from the last value it is given', () {
    const Hlc stored = Hlc(millis: _noon, counter: 7, nodeId: 'aaaa');
    final HlcClock clock = HlcClock(
      nodeId: 'aaaa',
      last: stored,
      wallClock: () => _noon - _oneHour,
    );

    expect(clock.last, stored);
    expect(clock.now() > stored, isTrue);
  });

  test('a received clock places the next change after it', () {
    final HlcClock clock = HlcClock(nodeId: 'aaaa', wallClock: () => _noon);
    clock.now();
    const Hlc remote = Hlc(millis: _noon + 1000, counter: 3, nodeId: 'bbbb');

    expect(clock.receive(remote), HlcReceipt.accepted);
    expect(clock.last > remote, isTrue);
    expect(clock.now() > remote, isTrue);
  });

  test('a remote clock more than five minutes ahead is held back', () {
    final HlcClock clock = HlcClock(nodeId: 'aaaa', wallClock: () => _noon);
    clock.now();
    final Hlc before = clock.last;
    const Hlc remote = Hlc(
      millis: _noon + _fiveMinutes + 1,
      counter: 0,
      nodeId: 'bbbb',
    );

    expect(clock.receive(remote), HlcReceipt.heldBack);
    expect(clock.last, before);
    expect(clock.now(), const Hlc(millis: _noon, counter: 1, nodeId: 'aaaa'));
  });

  test('a held-back clock is accepted once the wall clock catches up', () {
    int wall = _noon;
    final HlcClock clock = HlcClock(nodeId: 'aaaa', wallClock: () => wall);
    const Hlc remote = Hlc(
      millis: _noon + _fiveMinutes + 1,
      counter: 0,
      nodeId: 'bbbb',
    );
    expect(clock.receive(remote), HlcReceipt.heldBack);

    wall = _noon + 1;

    expect(clock.receive(remote), HlcReceipt.accepted);
    expect(clock.now() > remote, isTrue);
  });
}
