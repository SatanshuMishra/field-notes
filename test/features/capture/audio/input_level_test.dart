import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

const int _minus30DbfsSineAmplitude = 1465;

const AudioInput _systemDefault = AudioInput(id: null, label: 'System default');
const AudioInput _corsair = AudioInput(id: 'b', label: 'CORSAIR HS80 MAX');

Uint8List _pcm(List<int> samples) {
  final ByteData data = ByteData(samples.length * 2);
  for (int index = 0; index < samples.length; index++) {
    data.setInt16(index * 2, samples[index], Endian.little);
  }
  return data.buffer.asUint8List();
}

Uint8List _zeros() => _pcm(List<int>.filled(480, 0));

Uint8List _sine() => _pcm(<int>[
  for (int index = 0; index < 480; index++)
    (_minus30DbfsSineAmplitude * math.sin(2 * math.pi * 1000 * index / 48000))
        .round(),
]);

Uint8List _square() => _pcm(<int>[
  for (int index = 0; index < 480; index++)
    (index ~/ 24).isEven ? 32767 : -32768,
]);

class _FakeRecorder extends Fake implements AudioRecorder {
  _FakeRecorder({this.permitted = true, this.startThrows = false});

  final bool permitted;
  final bool startThrows;
  final List<RecordConfig> started = <RecordConfig>[];
  final List<StreamController<Uint8List>> streams =
      <StreamController<Uint8List>>[];
  int permissionChecks = 0;
  int stops = 0;
  int disposals = 0;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    permissionChecks++;
    return permitted;
  }

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    started.add(config);
    if (startThrows) {
      throw StateError('no microphone');
    }
    final StreamController<Uint8List> stream = StreamController<Uint8List>();
    streams.add(stream);
    return stream.stream;
  }

  @override
  Future<String?> stop() async {
    stops++;
    return null;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class _Recorders {
  final List<_FakeRecorder> made = <_FakeRecorder>[];

  AudioRecorder make() {
    final _FakeRecorder recorder = _FakeRecorder();
    made.add(recorder);
    return recorder;
  }
}

Future<void> _show(WidgetTester tester, Widget meter) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: fieldNotesTheme(platform: TargetPlatform.macOS),
      home: Scaffold(
        backgroundColor: Palette.mediaGround,
        body: Center(child: SizedBox(width: 240, child: meter)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _setLifecycle(WidgetTester tester, AppLifecycleState state) async {
  tester.binding.handleAppLifecycleStateChanged(state);
  await tester.pump();
}

Future<void> _cover(WidgetTester tester) async {
  unawaited(
    showGeneralDialog<void>(
      context: tester.element(find.byType(InputLevelMeter)),
      barrierColor: const Color(0x00000000),
      pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) => const SizedBox(width: 120, height: 40),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _uncover(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(InputLevelMeter))).pop();
  await tester.pumpAndSettle();
}

List<bool> _segments(WidgetTester tester) => <bool>[
  for (int index = 0; index < 20; index++)
    (tester
                    .widget<DecoratedBox>(
                      find.byKey(inputLevelSegmentKey(index)),
                    )
                    .decoration
                as BoxDecoration)
            .color!
            .toARGB32() ==
        Palette.mediaInk.toARGB32(),
];

int _lit(WidgetTester tester) =>
    _segments(tester).where((bool lit) => lit).length;

void main() {
  tearDown(() {
    final TestWidgetsFlutterBinding binding =
        TestWidgetsFlutterBinding.instance;
    while (binding.lifecycleState != AppLifecycleState.resumed) {
      binding.handleAppLifecycleStateChanged(switch (binding.lifecycleState) {
        AppLifecycleState.paused => AppLifecycleState.hidden,
        AppLifecycleState.hidden => AppLifecycleState.inactive,
        _ => AppLifecycleState.resumed,
      });
    }
  });

  test('the input level follows the microphone and the volume', () {
    expect(inputLevelOf(_zeros(), 0), 0);
    expect(inputLevelOf(_zeros(), 100), 0);
    expect(inputLevelOf(_zeros(), 200), 0);
    expect(inputLevelOf(_sine(), 100), closeTo(0.5, 0.02));
    expect(inputLevelOf(_sine(), 0), 0);
    expect(inputLevelOf(_square(), 0), 0);
    expect(inputLevelOf(_sine(), 200), closeTo(0.65, 0.02));
    expect(inputLevelOf(_square(), 100), 1);
    expect(inputLevelOf(_square(), 200), 1);
  });

  test('broken chunks do not move the level', () async {
    final StreamController<Uint8List> chunks = StreamController<Uint8List>();
    double level = 0;
    listenInputLevel(
      chunks.stream,
      volume: () => 100,
      onLevel: (double next) => level = next,
    );

    chunks.add(_sine());
    await pumpEventQueue();
    expect(level, closeTo(0.5, 0.02));
    final double last = level;

    expect(inputLevelOf(Uint8List(0), 100), isNull);
    expect(inputLevelOf(Uint8List(3), 100), isNull);
    chunks.add(Uint8List(0));
    chunks.add(Uint8List(3));
    await pumpEventQueue();
    expect(level, last);

    chunks.addError(StateError('microphone lost'));
    await pumpEventQueue();
    expect(chunks.hasListener, isFalse);
    expect(level, last);
  });

  testWidgets(
    'an input level that cannot start says the microphone is unavailable',
    (WidgetTester tester) async {
      final _FakeRecorder throwing = _FakeRecorder(startThrows: true);
      await _show(
        tester,
        InputLevelMeter(
          key: const ValueKey<String>('throws'),
          input: _systemDefault,
          volume: 100,
          recorderFactory: () => throwing,
        ),
      );

      expect(throwing.started, hasLength(1));
      expect(_lit(tester), 0);
      expect(find.text('Microphone unavailable'), findsOneWidget);

      final _FakeRecorder refused = _FakeRecorder(permitted: false);
      await _show(
        tester,
        InputLevelMeter(
          key: const ValueKey<String>('refused'),
          input: _systemDefault,
          volume: 100,
          recorderFactory: () => refused,
        ),
      );

      expect(refused.permissionChecks, 1);
      expect(refused.started, isEmpty);
      expect(_lit(tester), 0);
      expect(find.text('Microphone unavailable'), findsOneWidget);
    },
  );

  testWidgets('the meter stops the microphone when it goes away', (
    WidgetTester tester,
  ) async {
    final _FakeRecorder recorder = _FakeRecorder();
    await _show(
      tester,
      InputLevelMeter(
        input: _corsair,
        volume: 100,
        recorderFactory: () => recorder,
      ),
    );

    expect(recorder.started, hasLength(1));
    expect(recorder.stops, 0);
    expect(recorder.disposals, 0);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(recorder.stops, 1);
    expect(recorder.disposals, 1);
    expect(recorder.streams.single.hasListener, isFalse);
  });

  testWidgets('the meter streams the chosen input and lights from the left', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _FakeRecorder recorder = _FakeRecorder();
    await _show(
      tester,
      InputLevelMeter(
        input: _corsair,
        volume: 100,
        recorderFactory: () => recorder,
      ),
    );

    final RecordConfig config = recorder.started.single;
    expect(config.encoder, AudioEncoder.pcm16bits);
    expect(config.sampleRate, 48000);
    expect(config.numChannels, 1);
    expect(config.device?.id, 'b');
    expect(config.device?.label, 'CORSAIR HS80 MAX');
    expect(find.byKey(inputLevelSegmentKey(19)), findsOneWidget);
    expect(find.byKey(inputLevelSegmentKey(20)), findsNothing);
    expect(find.bySemanticsLabel('Input level'), findsOneWidget);
    expect(_lit(tester), 0);

    recorder.streams.single.add(_sine());
    await tester.pump();
    await tester.pump();
    expect(_segments(tester), <bool>[
      ...List<bool>.filled(10, true),
      ...List<bool>.filled(10, false),
    ]);

    await _show(
      tester,
      InputLevelMeter(
        input: _corsair,
        volume: 200,
        recorderFactory: () => recorder,
      ),
    );
    recorder.streams.single.add(_sine());
    await tester.pump();
    await tester.pump();
    expect(_lit(tester), 13);
    expect(recorder.stops, 0);

    await _show(
      tester,
      InputLevelMeter(
        input: _systemDefault,
        volume: 200,
        recorderFactory: () => recorder,
      ),
    );
    expect(recorder.stops, 1);
    expect(recorder.started, hasLength(2));
    expect(recorder.started.last.device, isNull);
    expect(recorder.streams.first.hasListener, isFalse);
    expect(_lit(tester), 0);
    expect(find.text('Microphone unavailable'), findsNothing);
    semantics.dispose();
  });

  testWidgets('the meter lets go of the microphone while the app is hidden', (
    WidgetTester tester,
  ) async {
    final _Recorders recorders = _Recorders();
    await _show(
      tester,
      InputLevelMeter(
        input: _corsair,
        volume: 100,
        recorderFactory: recorders.make,
      ),
    );

    await _setLifecycle(tester, AppLifecycleState.inactive);
    expect(recorders.made, hasLength(1));
    final _FakeRecorder first = recorders.made.single;
    expect(first.started, hasLength(1));
    expect(first.streams.single.hasListener, isTrue);
    expect(first.stops, 0);

    await _setLifecycle(tester, AppLifecycleState.hidden);
    expect(first.stops, 1);
    expect(first.disposals, 1);
    expect(first.streams.single.hasListener, isFalse);

    await _setLifecycle(tester, AppLifecycleState.paused);
    expect(first.stops, 1);
    expect(first.disposals, 1);
    expect(recorders.made, hasLength(1));

    await _setLifecycle(tester, AppLifecycleState.hidden);
    expect(first.stops, 1);
    expect(first.disposals, 1);
    expect(recorders.made, hasLength(1));

    await _setLifecycle(tester, AppLifecycleState.inactive);
    expect(recorders.made, hasLength(2));
    final _FakeRecorder second = recorders.made.last;
    expect(second.started, hasLength(1));
    expect(second.streams.single.hasListener, isTrue);
    expect(second.started.single.toMap(), first.started.single.toMap());

    await _setLifecycle(tester, AppLifecycleState.resumed);
    expect(second.stops, 0);
    expect(recorders.made, hasLength(2));
  });

  testWidgets('a meter shown while the app is detached opens no microphone', (
    WidgetTester tester,
  ) async {
    await _setLifecycle(tester, AppLifecycleState.inactive);
    await _setLifecycle(tester, AppLifecycleState.hidden);
    await _setLifecycle(tester, AppLifecycleState.paused);
    await _setLifecycle(tester, AppLifecycleState.detached);

    final _Recorders recorders = _Recorders();
    await _show(
      tester,
      InputLevelMeter(
        input: _corsair,
        volume: 100,
        recorderFactory: recorders.make,
      ),
    );
    tester.binding.scheduleForcedFrame();
    await tester.pump();
    expect(find.byType(InputLevelMeter), findsOneWidget);
    expect(recorders.made, isEmpty);

    await _setLifecycle(tester, AppLifecycleState.resumed);
    expect(recorders.made, hasLength(1));
    expect(recorders.made.single.started, hasLength(1));
    expect(recorders.made.single.streams.single.hasListener, isTrue);
  });

  testWidgets('the meter lets go of the microphone while a route covers it', (
    WidgetTester tester,
  ) async {
    final _Recorders recorders = _Recorders();
    await _show(
      tester,
      InputLevelMeter(
        input: _corsair,
        volume: 100,
        recorderFactory: recorders.make,
      ),
    );
    expect(recorders.made, hasLength(1));
    final _FakeRecorder first = recorders.made.single;
    expect(first.streams.single.hasListener, isTrue);

    await _cover(tester);
    expect(first.stops, 1);
    expect(first.disposals, 1);
    expect(first.streams.single.hasListener, isFalse);

    await _uncover(tester);
    expect(recorders.made, hasLength(2));
    final _FakeRecorder second = recorders.made.last;
    expect(second.started, hasLength(1));
    expect(second.streams.single.hasListener, isTrue);
    expect(first.stops, 1);
  });

  testWidgets(
    'an input chosen while the meter is covered opens no microphone until it is shown',
    (WidgetTester tester) async {
      final _Recorders recorders = _Recorders();
      final ValueNotifier<AudioInput> input = ValueNotifier<AudioInput>(
        _systemDefault,
      );
      addTearDown(input.dispose);
      await _show(
        tester,
        ValueListenableBuilder<AudioInput>(
          valueListenable: input,
          builder: (BuildContext context, AudioInput value, Widget? child) =>
              InputLevelMeter(
                input: value,
                volume: 100,
                recorderFactory: recorders.make,
              ),
        ),
      );

      input.value = _corsair;
      await tester.pump();
      expect(recorders.made, hasLength(1));
      final _FakeRecorder first = recorders.made.single;
      expect(first.started, hasLength(2));
      expect(first.started.last.device?.id, 'b');

      await _cover(tester);
      expect(first.disposals, 1);
      expect(first.streams.last.hasListener, isFalse);

      input.value = _systemDefault;
      await tester.pump();
      expect(recorders.made, hasLength(1));

      await _uncover(tester);
      expect(recorders.made, hasLength(2));
      final _FakeRecorder second = recorders.made.last;
      expect(second.started, hasLength(1));
      expect(second.started.single.device, isNull);
    },
  );
}
