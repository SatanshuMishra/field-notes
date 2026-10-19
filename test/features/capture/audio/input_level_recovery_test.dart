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

const AudioInput _corsair = AudioInput(id: 'b', label: 'CORSAIR HS80 MAX');

Uint8List _speech() {
  final ByteData data = ByteData(480 * 2);
  for (int index = 0; index < 480; index++) {
    data.setInt16(
      index * 2,
      (8000 * math.sin(2 * math.pi * 440 * index / 48000)).round(),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}

class _FakeRecorder extends Fake implements AudioRecorder {
  final List<StreamController<Uint8List>> streams =
      <StreamController<Uint8List>>[];
  int stops = 0;
  int disposals = 0;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
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

class _SlowHeadsetRecorder extends _FakeRecorder {
  _SlowHeadsetRecorder(this.firstChunkAfter);

  final Duration firstChunkAfter;
  final List<Timer> _beats = <Timer>[];

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    final StreamController<Uint8List> stream = StreamController<Uint8List>();
    streams.add(stream);
    _beats.add(
      Timer(firstChunkAfter, () {
        _beats.add(
          Timer.periodic(const Duration(milliseconds: 100), (Timer _) {
            if (!stream.isClosed) {
              stream.add(_speech());
            }
          }),
        );
      }),
    );
    return stream.stream;
  }

  @override
  Future<String?> stop() async {
    for (final Timer beat in _beats) {
      beat.cancel();
    }
    return super.stop();
  }
}

class _Recorders {
  final List<_FakeRecorder> made = <_FakeRecorder>[];

  AudioRecorder make() {
    final _FakeRecorder recorder = _FakeRecorder();
    made.add(recorder);
    return recorder;
  }

  AudioRecorder makeSlowHeadset(Duration firstChunkAfter) {
    final _FakeRecorder recorder = _SlowHeadsetRecorder(firstChunkAfter);
    made.add(recorder);
    return recorder;
  }

  int get startStreams => made.fold<int>(
    0,
    (int total, _FakeRecorder recorder) => total + recorder.streams.length,
  );
}

int _lit(WidgetTester tester) => <int>[
  for (int index = 0; index < inputLevelSegments; index++)
    if ((tester
                    .widget<DecoratedBox>(
                      find.byKey(inputLevelSegmentKey(index)),
                    )
                    .decoration
                as BoxDecoration)
            .color!
            .toARGB32() ==
        Palette.mediaInk.toARGB32())
      index,
].length;

Future<void> _showMeter(
  WidgetTester tester,
  AudioRecorder Function() recorderFactory,
) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: fieldNotesTheme(platform: TargetPlatform.macOS),
      home: Scaffold(
        backgroundColor: Palette.mediaGround,
        body: Center(
          child: SizedBox(
            width: 240,
            child: InputLevelMeter(
              input: _corsair,
              volume: 100,
              recorderFactory: recorderFactory,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the level meter reopens a microphone that goes quiet', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final _Recorders recorders = _Recorders();
    await tester.pumpWidget(
      MaterialApp(
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          backgroundColor: Palette.mediaGround,
          body: Center(
            child: SizedBox(
              width: 240,
              child: InputLevelMeter(
                input: _corsair,
                volume: 100,
                recorderFactory: recorders.make,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(recorders.startStreams, 1);

    recorders.made.single.streams.single.add(_speech());
    await tester.pump();
    await tester.pump();
    expect(_lit(tester), greaterThan(0));

    await tester.pump(const Duration(milliseconds: 400));
    expect(recorders.startStreams, 1);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(recorders.startStreams, greaterThanOrEqualTo(2));
    expect(recorders.made.first.stops, greaterThanOrEqualTo(1));
    expect(recorders.made.first.disposals, 1);
    expect(_lit(tester), 0);

    recorders.made.last.streams.last.add(_speech());
    await tester.pump();
    await tester.pump();
    expect(_lit(tester), greaterThan(0));

    final int opened = recorders.startStreams;
    for (int beat = 0; beat < 10; beat++) {
      recorders.made.last.streams.last.add(_speech());
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(recorders.startStreams, opened);
    expect(_lit(tester), greaterThan(0));
  });

  testWidgets(
    'a headset whose first chunk arrives 1.5 s after opening is opened once '
    'and shows its level',
    (WidgetTester tester) async {
      final _Recorders recorders = _Recorders();
      await _showMeter(
        tester,
        () => recorders.makeSlowHeadset(const Duration(milliseconds: 1500)),
      );
      for (int beat = 0; beat < 30; beat++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(recorders.startStreams, 1);
      expect(_lit(tester), greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('a microphone that never delivers is reopened after 2 s', (
    WidgetTester tester,
  ) async {
    final _Recorders recorders = _Recorders();
    await _showMeter(tester, recorders.make);
    await tester.pump();
    expect(recorders.startStreams, 1);

    await tester.pump(const Duration(milliseconds: 1900));
    expect(recorders.startStreams, 1);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(recorders.startStreams, 2);
  });
}
