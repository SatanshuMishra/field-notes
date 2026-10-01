import 'dart:async';

import 'package:field_notes/features/garden/scene/meadow_pacer.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGpu {
  int clock = 0;
  final List<Completer<void>> answers = <Completer<void>>[];

  MeadowPacer pacer() => MeadowPacer(
    nowMicros: () => clock,
    marker: () {
      final Completer<void> answer = Completer<void>();
      answers.add(answer);
      return answer.future;
    },
  );

  Future<void> answer(
    int index, {
    required int at,
    required Future<void> Function() settle,
  }) {
    clock = at;
    answers[index].complete();
    return settle();
  }
}

Duration get _sixty => MeadowPacer.frameInterval(60);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

Future<Duration?> _measure(
  _FakeGpu gpu,
  MeadowPacer pacer,
  MeadowWork kind, {
  required int steps,
  required int before,
  required int after,
  Future<void> Function() settle = _settle,
}) async {
  Duration? measured;
  final int first = gpu.answers.length;
  final MeadowBatch batch = pacer.begin(kind, frame: _sixty);
  pacer.end(batch, steps: steps, answered: (Duration? cost) => measured = cost);
  await gpu.answer(first, at: before, settle: settle);
  await gpu.answer(first + 1, at: after, settle: settle);
  return measured;
}

void _scheduleFrame(WidgetTester tester) => tester.binding.scheduleFrame();

void main() {
  test('the frame interval comes from the display and the build stops at '
      'half of it', () {
    expect(MeadowPacer.frameInterval(60), const Duration(microseconds: 16667));
    expect(MeadowPacer.frameInterval(120), const Duration(microseconds: 8333));
    for (final double unknown in <double>[
      0,
      double.nan,
      -90,
      double.infinity,
    ]) {
      expect(
        MeadowPacer.frameInterval(unknown),
        const Duration(microseconds: 16667),
        reason: '$unknown Hz',
      );
    }

    final Duration frame = MeadowPacer.frameInterval(60);
    expect(
      MeadowPacer.keepBuilding(spent: Duration.zero, advanced: 0, frame: frame),
      isTrue,
    );
    expect(
      MeadowPacer.keepBuilding(
        spent: const Duration(seconds: 5),
        advanced: 0,
        frame: frame,
      ),
      isTrue,
    );
    expect(
      MeadowPacer.keepBuilding(
        spent: const Duration(microseconds: 8332),
        advanced: 3,
        frame: frame,
      ),
      isTrue,
    );
    expect(
      MeadowPacer.keepBuilding(
        spent: const Duration(microseconds: 8333),
        advanced: 1,
        frame: frame,
      ),
      isFalse,
    );
    expect(
      MeadowPacer.keepBuilding(
        spent: const Duration(milliseconds: 20),
        advanced: 1,
        frame: frame,
      ),
      isFalse,
    );

    final Duration fast = MeadowPacer.frameInterval(120);
    expect(
      MeadowPacer.keepBuilding(
        spent: const Duration(microseconds: 4165),
        advanced: 2,
        frame: fast,
      ),
      isTrue,
    );
    expect(
      MeadowPacer.keepBuilding(
        spent: const Duration(microseconds: 4166),
        advanced: 2,
        frame: fast,
      ),
      isFalse,
    );
  });

  test(
    'a batch is sized from the measured cost of its own kind of step',
    () async {
      final _FakeGpu gpu = _FakeGpu();
      final MeadowPacer pacer = gpu.pacer();
      final Duration frame = MeadowPacer.frameInterval(60);
      for (final MeadowWork kind in MeadowWork.values) {
        expect(pacer.estimateOf(kind), isNull, reason: '$kind');
        expect(pacer.allowance(kind, share: frame), 1, reason: '$kind');
        expect(pacer.allowance(kind, share: frame ~/ 2), 1, reason: '$kind');
      }

      final Duration? plants = await _measure(
        gpu,
        pacer,
        MeadowWork.plants,
        steps: 4,
        before: 1000,
        after: 5000,
      );
      expect(plants, const Duration(milliseconds: 4));
      expect(
        pacer.estimateOf(MeadowWork.plants),
        const Duration(milliseconds: 1),
      );
      expect(pacer.allowance(MeadowWork.plants, share: frame), 16);
      expect(pacer.allowance(MeadowWork.plants, share: frame ~/ 2), 8);
      expect(pacer.allowance(MeadowWork.piece, share: frame), 1);
      expect(pacer.allowance(MeadowWork.layers, share: frame), 1);
      expect(pacer.allowance(MeadowWork.finish, share: frame), 1);

      await _measure(
        gpu,
        pacer,
        MeadowWork.piece,
        steps: 1,
        before: 6000,
        after: 16000,
      );
      expect(
        pacer.estimateOf(MeadowWork.piece),
        const Duration(milliseconds: 10),
      );
      expect(pacer.allowance(MeadowWork.piece, share: frame), 1);
      expect(pacer.allowance(MeadowWork.piece, share: frame ~/ 2), 1);
      expect(pacer.allowance(MeadowWork.plants, share: frame), 16);

      final Duration? still = await _measure(
        gpu,
        pacer,
        MeadowWork.plants,
        steps: 3,
        before: 20000,
        after: 20000,
      );
      expect(still, Duration.zero);
      expect(
        pacer.estimateOf(MeadowWork.plants),
        const Duration(milliseconds: 1),
      );
      expect(pacer.allowance(MeadowWork.plants, share: frame), 16);

      await _measure(
        gpu,
        pacer,
        MeadowWork.plants,
        steps: 2,
        before: 21000,
        after: 27000,
      );
      expect(
        pacer.estimateOf(MeadowWork.plants),
        const Duration(milliseconds: 2),
      );
      expect(pacer.allowance(MeadowWork.plants, share: frame), 8);

      final _FakeGpu quick = _FakeGpu();
      final MeadowPacer fresh = quick.pacer();
      await _measure(
        quick,
        fresh,
        MeadowWork.plants,
        steps: 100,
        before: 1000,
        after: 1001,
      );
      expect(
        fresh.estimateOf(MeadowWork.plants),
        const Duration(microseconds: 1),
      );
      expect(fresh.allowance(MeadowWork.plants, share: frame), 16667);
      expect(fresh.allowance(MeadowWork.piece, share: frame), 1);
    },
  );

  test('a slower GPU gets smaller batches than a faster one', () async {
    final _FakeGpu fastGpu = _FakeGpu();
    final MeadowPacer fast = fastGpu.pacer();
    final _FakeGpu slowGpu = _FakeGpu();
    final MeadowPacer slow = slowGpu.pacer();
    final Duration frame = MeadowPacer.frameInterval(60);
    for (final int steps in <int>[1, 4, 6, 2]) {
      await _measure(
        fastGpu,
        fast,
        MeadowWork.plants,
        steps: steps,
        before: fastGpu.clock + 100,
        after: fastGpu.clock + 100 + steps * 500,
      );
      await _measure(
        slowGpu,
        slow,
        MeadowWork.plants,
        steps: steps,
        before: slowGpu.clock + 100,
        after: slowGpu.clock + 100 + steps * 4000,
      );
    }
    expect(fast.allowance(MeadowWork.plants, share: frame), 33);
    expect(slow.allowance(MeadowWork.plants, share: frame), 4);
  });

  testWidgets('the pacer pauses only while two batches are unanswered', (
    WidgetTester tester,
  ) async {
    final _FakeGpu gpu = _FakeGpu();
    final MeadowPacer pacer = gpu.pacer();
    final Duration frame = MeadowPacer.frameInterval(60);
    expect(pacer.isBehind, isFalse);

    final MeadowBatch first = pacer.begin(MeadowWork.plants, frame: frame);
    pacer.end(first, steps: 2);
    expect(pacer.isBehind, isFalse, reason: 'one ended batch unanswered');

    final MeadowBatch second = pacer.begin(MeadowWork.plants, frame: frame);
    expect(
      pacer.isBehind,
      isFalse,
      reason: 'a batch that has begun but not ended does not count',
    );
    pacer.end(second, steps: 2);
    expect(pacer.isBehind, isTrue, reason: 'two ended batches unanswered');

    await gpu.answer(0, at: 100, settle: tester.idle);
    expect(pacer.isBehind, isTrue, reason: 'only the before-marker answered');
    await gpu.answer(1, at: 900, settle: tester.idle);
    expect(pacer.isBehind, isFalse, reason: 'the first batch answered');

    final MeadowBatch third = pacer.begin(MeadowWork.plants, frame: frame);
    pacer.end(third, steps: 2);
    expect(pacer.isBehind, isTrue);

    final Object owner = Object();
    int turns = 0;
    bool turn() {
      turns++;
      return true;
    }

    pacer.waitTurn(owner, turn);
    _scheduleFrame(tester);
    await tester.pump();
    expect(turns, 0, reason: 'no turn while two batches are unanswered');

    await gpu.answer(2, at: 1000, settle: tester.idle);
    await gpu.answer(3, at: 1800, settle: tester.idle);
    expect(pacer.isBehind, isFalse);
    _scheduleFrame(tester);
    await tester.pump();
    expect(turns, 0, reason: 'the queue ends with the frame it waited in');

    pacer.waitTurn(owner, turn);
    _scheduleFrame(tester);
    await tester.pump();
    expect(turns, 1, reason: 'the turn is given once the GPU caught up');

    pacer
      ..waitTurn(owner, turn)
      ..leave(owner);
    _scheduleFrame(tester);
    await tester.pump();
    expect(turns, 1, reason: 'an owner that left gets no turn');
  });

  test('a failed or lost marker never stalls the pacer', () async {
    final Duration frame = MeadowPacer.frameInterval(60);
    final _FakeGpu gpu = _FakeGpu();
    final MeadowPacer pacer = gpu.pacer();
    await _measure(
      gpu,
      pacer,
      MeadowWork.plants,
      steps: 4,
      before: 1000,
      after: 5000,
    );
    expect(
      pacer.estimateOf(MeadowWork.plants),
      const Duration(milliseconds: 1),
    );

    final List<Duration?> heard = <Duration?>[];
    final MeadowBatch failing = pacer.begin(MeadowWork.plants, frame: frame);
    pacer.end(failing, steps: 4, answered: heard.add);
    final MeadowBatch waiting = pacer.begin(MeadowWork.plants, frame: frame);
    pacer.end(waiting, steps: 1);
    expect(pacer.isBehind, isTrue);
    await gpu.answer(2, at: 6000, settle: _settle);
    gpu.clock = 90000;
    gpu.answers[3].completeError(StateError('the GPU lost the marker'));
    await _settle();
    expect(pacer.isBehind, isFalse, reason: 'a failed marker stops counting');
    expect(heard, <Duration?>[null]);
    expect(
      pacer.estimateOf(MeadowWork.plants),
      const Duration(milliseconds: 1),
    );

    final _FakeGpu silentGpu = _FakeGpu();
    final MeadowPacer silent = silentGpu.pacer();
    for (int i = 0; i < 2; i++) {
      final MeadowBatch batch = silent.begin(MeadowWork.plants, frame: frame);
      silent.end(batch, steps: 2);
    }
    expect(silent.isBehind, isTrue);
    silentGpu.clock = 30 * frame.inMicroseconds - 1;
    expect(silent.isBehind, isTrue, reason: 'not yet 30 frame intervals');
    silentGpu.clock = 30 * frame.inMicroseconds + 1;
    expect(silent.isBehind, isFalse, reason: 'lost after 30 frame intervals');
    expect(silent.estimateOf(MeadowWork.plants), isNull);

    final _FakeGpu lateGpu = _FakeGpu();
    final MeadowPacer late = lateGpu.pacer();
    final MeadowBatch unheard = late.begin(MeadowWork.plants, frame: frame);
    lateGpu.clock = 20 * frame.inMicroseconds;
    late.end(unheard, steps: 3);
    final MeadowBatch after = late.begin(MeadowWork.plants, frame: frame);
    late.end(after, steps: 1);
    expect(late.isBehind, isTrue);
    lateGpu.clock = 30 * frame.inMicroseconds - 1;
    expect(late.isBehind, isTrue);
    lateGpu.clock = 30 * frame.inMicroseconds + 1;
    expect(
      late.isBehind,
      isFalse,
      reason:
          'the batch whose before-marker never answered stops counting '
          '30 frame intervals after it began',
    );
    await lateGpu.answer(1, at: 40 * frame.inMicroseconds, settle: _settle);
    expect(late.estimateOf(MeadowWork.plants), isNull);
    expect(late.isBehind, isFalse);
  });

  testWidgets('an error in a callback leaves the pacer usable', (
    WidgetTester tester,
  ) async {
    final _FakeGpu gpu = _FakeGpu();
    final MeadowPacer pacer = gpu.pacer();
    final Duration frame = MeadowPacer.frameInterval(60);

    final MeadowBatch throwing = pacer.begin(MeadowWork.plants, frame: frame);
    pacer.end(
      throwing,
      steps: 4,
      answered: (Duration? cost) => throw StateError('the meadow broke'),
    );
    final MeadowBatch waiting = pacer.begin(MeadowWork.plants, frame: frame);
    pacer.end(waiting, steps: 1);
    expect(pacer.isBehind, isTrue);

    await gpu.answer(0, at: 1000, settle: tester.idle);
    await gpu.answer(1, at: 5000, settle: tester.idle);
    expect(tester.takeException(), isStateError);
    expect(pacer.isBehind, isFalse);
    expect(
      pacer.estimateOf(MeadowWork.plants),
      const Duration(milliseconds: 1),
    );
    expect(pacer.allowance(MeadowWork.plants, share: frame), 16);

    await gpu.answer(2, at: 6000, settle: tester.idle);
    await gpu.answer(3, at: 7000, settle: tester.idle);
    final Duration? measured = await _measure(
      gpu,
      pacer,
      MeadowWork.plants,
      steps: 16,
      before: 8000,
      after: 24000,
      settle: tester.idle,
    );
    expect(measured, const Duration(milliseconds: 16));
    expect(pacer.allowance(MeadowWork.plants, share: frame), 16);
    expect(pacer.isBehind, isFalse);

    pacer.waitTurn(Object(), () => throw StateError('the turn broke'));
    _scheduleFrame(tester);
    await tester.pump();
    expect(tester.takeException(), isStateError);
    expect(pacer.takeFrame(), isTrue, reason: 'the next frame is free');
    expect(pacer.takeFrame(), isFalse, reason: 'one batch per frame');

    final Object second = Object();
    int ran = 0;
    bool turn() {
      ran++;
      return true;
    }

    pacer.waitTurn(second, turn);
    _scheduleFrame(tester);
    await tester.pump();
    expect(ran, 0, reason: 'that frame was used');
    pacer.waitTurn(second, turn);
    _scheduleFrame(tester);
    await tester.pump();
    expect(ran, 1, reason: 'the second owner runs in a later unused frame');
  });
}
