import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

const String _asset = 'package:rnnoise/rnnoise.dart';

@Native<Pointer<Void> Function(Pointer<Void>)>(
  symbol: 'rnnoise_create',
  assetId: _asset,
  isLeaf: true,
)
external Pointer<Void> _rnnoiseCreate(Pointer<Void> model);

@Native<Void Function(Pointer<Void>)>(
  symbol: 'rnnoise_destroy',
  assetId: _asset,
  isLeaf: true,
)
external void _rnnoiseDestroy(Pointer<Void> state);

@Native<Int Function()>(
  symbol: 'rnnoise_get_frame_size',
  assetId: _asset,
  isLeaf: true,
)
external int _rnnoiseGetFrameSize();

@Native<Float Function(Pointer<Void>, Pointer<Float>, Pointer<Float>)>(
  symbol: 'rnnoise_process_frame',
  assetId: _asset,
  isLeaf: true,
)
external double _rnnoiseProcessFrame(
  Pointer<Void> state,
  Pointer<Float> out,
  Pointer<Float> input,
);

class Denoiser {
  factory Denoiser() {
    if (_rnnoiseGetFrameSize() != frameSize) {
      throw StateError('RNNoise does not take $frameSize-sample frames.');
    }
    final Pointer<Void> state = _rnnoiseCreate(nullptr);
    if (state == nullptr) {
      throw StateError('RNNoise could not create a denoiser.');
    }
    return Denoiser._(
      state,
      calloc<Float>(frameSize),
      calloc<Float>(frameSize),
    );
  }

  Denoiser._(this._state, this._input, this._output);

  static const int frameSize = 480;

  final Pointer<Void> _state;
  final Pointer<Float> _input;
  final Pointer<Float> _output;
  bool _disposed = false;

  Float32List process(Float32List frame) {
    if (frame.length != frameSize) {
      throw ArgumentError.value(
        frame.length,
        'frame',
        'A frame must hold $frameSize samples',
      );
    }
    if (_disposed) {
      throw StateError('This denoiser has been disposed.');
    }
    _input.asTypedList(frameSize).setAll(0, frame);
    _rnnoiseProcessFrame(_state, _output, _input);
    return Float32List.fromList(_output.asTypedList(frameSize));
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _rnnoiseDestroy(_state);
    calloc
      ..free(_input)
      ..free(_output);
  }
}
