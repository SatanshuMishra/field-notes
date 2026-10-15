import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/voice/voice_level.dart';
import 'package:flutter/widgets.dart';
import 'package:record/record.dart';

const String inputLevelLabel = 'Input level';
const String inputLevelUnavailable = 'Microphone unavailable';
const int inputLevelSegments = 20;
const int inputLevelSampleRate = 48000;

const double _fullScale = 32768;
const double _segmentHeight = 8;
const double _segmentGap = 2;
const double _segmentRadius = 2;
const double _dimAlpha = 0.24;
const double _messageGap = 6;

typedef AudioRecorderFactory = AudioRecorder Function();

Key inputLevelSegmentKey(int index) =>
    ValueKey<String>('input-level-segment-$index');

double? inputLevelOf(Uint8List chunk, int volume) {
  if (chunk.isEmpty || chunk.lengthInBytes.isOdd) {
    return null;
  }
  final ByteData data = ByteData.sublistView(chunk);
  final int count = chunk.lengthInBytes ~/ 2;
  final double gain = volume / 100;
  double sumOfSquares = 0;
  for (int index = 0; index < count; index++) {
    final double sample = data.getInt16(index * 2, Endian.little) * gain;
    sumOfSquares += sample * sample;
  }
  final double rms = math.sqrt(sumOfSquares / count);
  if (rms == 0) {
    return 0;
  }
  return voiceLevelFromDbfs(20 * math.log(rms / _fullScale) / math.ln10);
}

StreamSubscription<Uint8List> listenInputLevel(
  Stream<Uint8List> chunks, {
  required int Function() volume,
  required void Function(double level) onLevel,
}) {
  return chunks.listen(
    (Uint8List chunk) {
      final double? level = inputLevelOf(chunk, volume());
      if (level != null) {
        onLevel(level);
      }
    },
    onError: (Object error) {},
    cancelOnError: true,
  );
}

RecordConfig inputLevelConfig(AudioInput input) {
  final String? id = input.id;
  return RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: inputLevelSampleRate,
    numChannels: 1,
    device: id == null ? null : InputDevice(id: id, label: input.label),
  );
}

class InputLevelMeter extends StatefulWidget {
  const InputLevelMeter({
    super.key,
    required this.input,
    required this.volume,
    this.recorderFactory = AudioRecorder.new,
    this.ink = Palette.mediaInk,
  });

  final AudioInput input;
  final int volume;
  final AudioRecorderFactory recorderFactory;
  final Color ink;

  @override
  State<InputLevelMeter> createState() => _InputLevelMeterState();
}

class _InputLevelMeterState extends State<InputLevelMeter> {
  late final AudioRecorder _recorder = widget.recorderFactory();
  StreamSubscription<Uint8List>? _chunks;
  int _generation = 0;
  double _level = 0;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(_listen(_generation));
  }

  @override
  void didUpdateWidget(InputLevelMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.input != widget.input) {
      unawaited(_restart());
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_chunks?.cancel());
    _chunks = null;
    unawaited(_release());
    super.dispose();
  }

  bool _current(int generation) => mounted && generation == _generation;

  Future<void> _listen(int generation) async {
    final Stream<Uint8List> chunks;
    try {
      if (!await _recorder.hasPermission()) {
        _markUnavailable(generation);
        return;
      }
      if (!_current(generation)) {
        return;
      }
      chunks = await _recorder.startStream(inputLevelConfig(widget.input));
    } catch (_) {
      _markUnavailable(generation);
      return;
    }
    if (!_current(generation)) {
      return;
    }
    _chunks = listenInputLevel(
      chunks,
      volume: () => widget.volume,
      onLevel: (double level) {
        if (_current(generation)) {
          setState(() => _level = level);
        }
      },
    );
  }

  Future<void> _restart() async {
    final int generation = ++_generation;
    unawaited(_chunks?.cancel());
    _chunks = null;
    await _quietly(_recorder.stop);
    if (!_current(generation)) {
      return;
    }
    setState(() {
      _level = 0;
      _unavailable = false;
    });
    await _listen(generation);
  }

  void _markUnavailable(int generation) {
    if (!_current(generation)) {
      return;
    }
    setState(() {
      _level = 0;
      _unavailable = true;
    });
  }

  Future<void> _release() async {
    await _quietly(_recorder.stop);
    await _quietly(_recorder.dispose);
  }

  Future<void> _quietly(Future<Object?> Function() call) async {
    try {
      await call();
    } catch (_) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int lit = (_level * inputLevelSegments).round();
    final Color dim = widget.ink.withValues(alpha: _dimAlpha);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          container: true,
          label: inputLevelLabel,
          child: SizedBox(
            height: _segmentHeight,
            child: Row(
              children: <Widget>[
                for (int index = 0; index < inputLevelSegments; index++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: index == 0 ? 0 : _segmentGap / 2,
                        end: index == inputLevelSegments - 1
                            ? 0
                            : _segmentGap / 2,
                      ),
                      child: DecoratedBox(
                        key: inputLevelSegmentKey(index),
                        decoration: BoxDecoration(
                          color: index < lit ? widget.ink : dim,
                          borderRadius: BorderRadius.circular(_segmentRadius),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_unavailable) ...<Widget>[
          const SizedBox(height: _messageGap),
          Text(
            inputLevelUnavailable,
            style: context.textStyles.captionSans.copyWith(color: widget.ink),
          ),
        ],
      ],
    );
  }
}
