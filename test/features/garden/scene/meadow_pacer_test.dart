import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/features/garden/scene/meadow_pacer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/image_count.dart';

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
  gpu.clock = before;
  final MeadowBatch batch = pacer.begin(kind, frame: _sixty);
  pacer.end(batch, steps: steps, answered: (Duration? cost) => measured = cost);
  await gpu.answer(gpu.answers.length - 1, at: after, settle: settle);
  return measured;
}

MeadowPacer _installPacer(MeadowPacer pacer) {
  final MeadowPacer original = meadowPacer;
  meadowPacer = pacer;
  addTearDown(() => meadowPacer = original);
  return pacer;
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

  test('estimates keep fractions of a microsecond', () async {
    final _FakeGpu gpu = _FakeGpu();
    final MeadowPacer pacer = gpu.pacer();
    await _measure(
      gpu,
      pacer,
      MeadowWork.plants,
      steps: 2,
      before: 1000,
      after: 1005,
    );
    expect(
      pacer.allowance(MeadowWork.plants, share: MeadowPacer.frameInterval(60)),
      6666,
      reason: '2.5 us a step',
    );
    expect(
      pacer.estimateOf(MeadowWork.plants),
      const Duration(microseconds: 3),
    );
  });

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

    await gpu.answer(0, at: 900, settle: tester.idle);
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

    await gpu.answer(1, at: 1800, settle: tester.idle);
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

  testWidgets('a turn that sends work claims the next frame', (
    WidgetTester tester,
  ) async {
    final MeadowPacer pacer = _FakeGpu().pacer();
    final Object owner = Object();
    int sent = 0;
    int idled = 0;
    bool send() {
      sent++;
      return true;
    }

    bool idle() {
      idled++;
      return false;
    }

    pacer.waitTurn(owner, send);
    _scheduleFrame(tester);
    await tester.pump();
    expect(sent, 1, reason: 'the turn ran at the end of an unused frame');

    final List<bool> claimed = <bool>[pacer.takeFrame()];
    tester.binding.scheduleFrameCallback(
      (Duration timeStamp) => claimed.add(pacer.takeFrame()),
    );
    await tester.pump();
    expect(claimed, <bool>[
      false,
      false,
    ], reason: 'the turn that sent work claimed the whole next frame');
    expect(pacer.takeFrame(), isTrue, reason: 'the frame after it is free');

    _scheduleFrame(tester);
    await tester.pump();
    pacer.waitTurn(owner, idle);
    _scheduleFrame(tester);
    await tester.pump();
    expect(idled, 1, reason: 'the turn ran at the end of an unused frame');
    expect(sent, 1);
    expect(
      pacer.takeFrame(),
      isTrue,
      reason: 'a turn that sent nothing leaves the next frame free',
    );
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
    gpu.clock = 3000;
    final MeadowBatch waiting = pacer.begin(MeadowWork.plants, frame: frame);
    pacer.end(waiting, steps: 1);
    expect(pacer.isBehind, isTrue);

    await gpu.answer(0, at: 4000, settle: tester.idle);
    await gpu.answer(1, at: 4000, settle: tester.idle);
    expect(tester.takeException(), isStateError);
    expect(pacer.isBehind, isFalse);
    expect(
      pacer.estimateOf(MeadowWork.plants),
      const Duration(milliseconds: 1),
    );
    expect(pacer.allowance(MeadowWork.plants, share: frame), 16);

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

    final Object second = Object();
    int ran = 0;
    bool turn() {
      ran++;
      return true;
    }

    pacer
      ..waitTurn(Object(), () => throw StateError('the turn broke'))
      ..waitTurn(second, turn);
    _scheduleFrame(tester);
    await tester.pump();
    expect(tester.takeException(), isStateError);
    expect(ran, 0, reason: "a turn that throws ends that frame's turns");
    expect(
      pacer.takeFrame(),
      isFalse,
      reason: 'the turn that threw claimed the next frame',
    );
    _scheduleFrame(tester);
    await tester.pump();
    expect(pacer.takeFrame(), isTrue, reason: 'the frame after it is free');
    expect(pacer.takeFrame(), isFalse, reason: 'one batch per frame');

    pacer.waitTurn(second, turn);
    _scheduleFrame(tester);
    await tester.pump();
    expect(ran, 0, reason: 'that frame was used');
    pacer.waitTurn(second, turn);
    _scheduleFrame(tester);
    await tester.pump();
    expect(ran, 1, reason: 'the second owner runs in a later unused frame');
  });

  testWidgets(
    'the snapshot room counts renders since the last frame and refills when a '
    'frame is drawn',
    (WidgetTester tester) async {
      final MeadowPacer pacer = MeadowPacer();
      expect(MeadowPacer.snapshotsPerGap, 4);
      final List<int> rooms = <int>[];
      final List<int> counted = <int>[];
      for (final int renders in <int>[0, 2, 2, 2]) {
        for (int i = 0; i < renders; i++) {
          pacer.countSnapshot();
        }
        rooms.add(pacer.snapshotRoom);
        counted.add(pacer.debugSnapshots);
      }
      expect(rooms, <int>[4, 2, 0, 0]);
      expect(counted, <int>[0, 2, 4, 6]);

      _scheduleFrame(tester);
      await tester.pump();
      expect(pacer.snapshotRoom, 4);
      expect(pacer.debugSnapshots, 6);
    },
  );

  test(
    'meadowSnapshot renders the picture at its size and counts it',
    () async {
      final MeadowPacer pacer = _installPacer(MeadowPacer());
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, 3, 2)).drawRect(
        const ui.Rect.fromLTWH(0, 0, 3, 2),
        ui.Paint()..color = const ui.Color(0xFFFF0000),
      );
      final ui.Picture picture = recorder.endRecording();
      addTearDown(picture.dispose);
      expect(meadowPacer.snapshotRoom, 4);

      final ui.Image image = meadowSnapshot(picture, 3, 2);
      addTearDown(image.dispose);

      expect(meadowPacer.snapshotRoom, 3);
      expect(meadowPacer.debugSnapshots, 1);
      expect(pacer.debugSnapshots, 1);
      expect(image.width, 3);
      expect(image.height, 2);
      final ByteData bytes = (await image.toByteData())!;
      final Uint8List rgba = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      expect(rgba, hasLength(3 * 2 * 4));
      for (int i = 0; i < rgba.length; i += 4) {
        expect(rgba.sublist(i, i + 4), <int>[
          255,
          0,
          0,
          255,
        ], reason: 'pixel $i');
      }
    },
  );

  test('a batch sends one marker, after it ends, and costs the time from its '
      'start to the answer', () async {
    final _FakeGpu gpu = _FakeGpu();
    final MeadowPacer pacer = gpu.pacer();
    final List<Duration?> heard = <Duration?>[];

    gpu.clock = 1000;
    final MeadowBatch batch = pacer.begin(MeadowWork.plants, frame: _sixty);
    expect(gpu.answers, isEmpty, reason: 'begin sends no marker');
    gpu.clock = 3000;
    pacer.end(batch, steps: 4, answered: heard.add);
    expect(gpu.answers, hasLength(1), reason: 'end sends one marker');

    await gpu.answer(0, at: 5000, settle: _settle);
    expect(gpu.answers, hasLength(1));
    expect(heard, <Duration?>[const Duration(microseconds: 4000)]);
    expect(
      pacer.estimateOf(MeadowWork.plants),
      const Duration(microseconds: 1000),
    );
    expect(
      pacer.allowance(
        MeadowWork.plants,
        share: const Duration(microseconds: 16667),
      ),
      16,
    );
  });

  test(
    'with one marker a batch, a failed or late marker never stalls the pacer',
    () async {
      final Duration frame = MeadowPacer.frameInterval(60);
      expect(frame, const Duration(microseconds: 16667));
      final _FakeGpu gpu = _FakeGpu();
      final MeadowPacer pacer = gpu.pacer();
      final List<Duration?> heardA = <Duration?>[];
      final List<Duration?> heardC = <Duration?>[];
      final List<Duration?> heardD = <Duration?>[];

      final MeadowBatch a = pacer.begin(MeadowWork.plants, frame: frame);
      pacer.end(a, steps: 2, answered: heardA.add);
      final MeadowBatch b = pacer.begin(MeadowWork.plants, frame: frame);
      pacer.end(b, steps: 2);
      expect(pacer.isBehind, isTrue, reason: 'A and B unanswered');
      gpu.answers[0].completeError(StateError('the GPU lost the marker'));
      await _settle();
      expect(pacer.isBehind, isFalse, reason: 'a failed marker stops counting');
      expect(heardA, <Duration?>[null]);
      expect(pacer.estimateOf(MeadowWork.plants), isNull);

      final MeadowBatch c = pacer.begin(MeadowWork.plants, frame: frame);
      pacer.end(c, steps: 4, answered: heardC.add);
      expect(pacer.isBehind, isTrue, reason: 'B and C unanswered');
      gpu.clock = 516677;
      expect(
        pacer.isBehind,
        isFalse,
        reason: 'past 30 frame intervals the batches stop counting',
      );
      expect(heardC, isEmpty);
      await gpu.answer(2, at: 666680, settle: _settle);
      expect(heardC, <Duration?>[const Duration(microseconds: 666680)]);
      expect(
        pacer.estimateOf(MeadowWork.plants),
        const Duration(microseconds: 166670),
      );

      gpu.clock = 1000000;
      final MeadowBatch d = pacer.begin(MeadowWork.plants, frame: frame);
      pacer.end(d, steps: 4, answered: heardD.add);
      gpu.clock = 6016767;
      expect(pacer.isBehind, isFalse);
      await gpu.answer(3, at: 6016767, settle: _settle);
      expect(heardD, isEmpty);
      expect(
        pacer.estimateOf(MeadowWork.plants),
        const Duration(microseconds: 166670),
      );
    },
  );

  testWidgets('the default marker reads back one image it renders only once', (
    WidgetTester tester,
  ) async {
    final MeadowPacer pacer = _installPacer(MeadowPacer());
    final ImageCount count = ImageCount()..start();
    addTearDown(count.stop);
    final List<Duration?> heard = <Duration?>[];

    Future<void> threeBatches() async {
      await tester.runAsync(() async {
        for (int i = 0; i < 3; i++) {
          final MeadowBatch batch = pacer.begin(
            MeadowWork.plants,
            frame: _sixty,
          );
          pacer.end(batch, steps: 1, answered: heard.add);
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
    }

    await threeBatches();
    final int first = count.created;
    await threeBatches();

    expect(heard, hasLength(6));
    expect(heard, everyElement(isNotNull));
    expect(count.created, lessThanOrEqualTo(1));
    expect(count.created, first, reason: 'the second three create none');
    expect(meadowPacer.debugSnapshots, count.created);
  });
}
