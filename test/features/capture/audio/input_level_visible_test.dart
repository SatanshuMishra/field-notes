import 'dart:async';
import 'dart:typed_data';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

const AudioInput _input = AudioInput(id: null, label: 'System default');

Uint8List _minus30Dbfs() {
  final ByteData data = ByteData(480 * 2);
  for (int index = 0; index < 480; index++) {
    data.setInt16(
      index * 2,
      (index ~/ 24).isEven ? 1037 : -1037,
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}

class _FakeRecorder extends Fake implements AudioRecorder {
  final StreamController<Uint8List> stream = StreamController<Uint8List>();

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async =>
      stream.stream;

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> dispose() async {}
}

Future<_FakeRecorder> _show(WidgetTester tester) async {
  final _FakeRecorder recorder = _FakeRecorder();
  addTearDown(recorder.stream.close);
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
            width: 300,
            child: InputLevelMeter(
              input: _input,
              volume: 100,
              recorderFactory: () => recorder,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return recorder;
}

int _segmentColor(WidgetTester tester, int index) =>
    ((tester
                .widget<DecoratedBox>(find.byKey(inputLevelSegmentKey(index)))
                .decoration)
            as BoxDecoration)
        .color!
        .toARGB32();

void main() {
  testWidgets('segments have height', (WidgetTester tester) async {
    await _show(tester);

    for (int index = 0; index < 20; index++) {
      final Size size = tester.getSize(find.byKey(inputLevelSegmentKey(index)));
      expect(size.height, 8, reason: 'segment $index height');
      expect(size.width, greaterThan(0), reason: 'segment $index width');
    }
  });

  testWidgets('speech lights its share', (WidgetTester tester) async {
    final _FakeRecorder recorder = await _show(tester);

    recorder.stream.add(_minus30Dbfs());
    await tester.pump();
    await tester.pump();

    final int ink = Palette.mediaInk.toARGB32();
    final int dim = Palette.mediaInk.withValues(alpha: 0.24).toARGB32();
    for (int index = 0; index < 20; index++) {
      expect(
        _segmentColor(tester, index),
        index < 10 ? ink : dim,
        reason: 'segment $index colour',
      );
    }
  });
}
