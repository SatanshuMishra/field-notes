import 'dart:async';

import 'package:flutter/services.dart';

const MethodChannel _streamClockChannel = MethodChannel(
  'com.llfbandit.record/streamClock',
);
const String _capturedMethod = 'captured';

class CapturedAudio {
  const CapturedAudio({
    required this.recorderId,
    required this.firstSample,
    required this.samples,
    required this.capturedAtNs,
  });

  static CapturedAudio? fromArguments(Object? arguments) {
    if (arguments is! Map) {
      return null;
    }
    final Object? recorderId = arguments['recorderId'];
    final Object? firstSample = arguments['firstFrame'];
    final Object? samples = arguments['frames'];
    final Object? capturedAtNs = arguments['capturedAtNs'];
    if (recorderId is! String ||
        firstSample is! int ||
        samples is! int ||
        capturedAtNs is! int) {
      return null;
    }
    return CapturedAudio(
      recorderId: recorderId,
      firstSample: firstSample,
      samples: samples,
      capturedAtNs: capturedAtNs,
    );
  }

  final String recorderId;
  final int firstSample;
  final int samples;
  final int capturedAtNs;

  int get endSample => firstSample + samples;
}

final StreamController<CapturedAudio> _captured =
    StreamController<CapturedAudio>.broadcast(
      onListen: () =>
          _streamClockChannel.setMethodCallHandler(_receiveCapturedAudio),
      onCancel: () => _streamClockChannel.setMethodCallHandler(null),
    );

Stream<CapturedAudio> get macMicrophoneCaptureTimes => _captured.stream;

Future<void> _receiveCapturedAudio(MethodCall call) async {
  if (call.method != _capturedMethod) {
    return;
  }
  final CapturedAudio? captured = CapturedAudio.fromArguments(call.arguments);
  if (captured != null) {
    _captured.add(captured);
  }
}
