import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/data/device/stay_awake.dart';

final Provider<StayAwake> stayAwakeProvider = Provider<StayAwake>(
  (Ref ref) => const PlatformStayAwake(),
);

class RecordingWakeHold {
  RecordingWakeHold(this._stayAwake);

  final StayAwake _stayAwake;
  bool _held = false;

  void update({required bool live}) {
    if (live == _held) {
      return;
    }
    _held = live;
    unawaited(live ? _stayAwake.hold() : _stayAwake.release());
  }

  void dispose() => update(live: false);
}
