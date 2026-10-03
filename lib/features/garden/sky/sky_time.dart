import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:field_notes/features/garden/sky/sky_location_provider.dart';

part 'sky_time.g.dart';

const Duration skyRefreshInterval = Duration(seconds: 60);
const Duration skyFastForwardTick = Duration(milliseconds: 150);
const Duration skyFastForwardStep = Duration(milliseconds: 270000);

@riverpod
DateTime Function() skyClock(Ref ref) => DateTime.now;

@immutable
class SkyMoment {
  const SkyMoment({
    required this.instant,
    this.offset = Duration.zero,
    this.fastForwarding = false,
  });

  final DateTime instant;
  final Duration offset;
  final bool fastForwarding;

  bool get shifted => offset != Duration.zero;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkyMoment &&
          instant == other.instant &&
          offset == other.offset &&
          fastForwarding == other.fastForwarding;

  @override
  int get hashCode => Object.hash(instant, offset, fastForwarding);

  @override
  String toString() =>
      'SkyMoment(instant: $instant, offset: $offset, '
      'fastForwarding: $fastForwarding)';
}

@riverpod
class SkyTime extends _$SkyTime {
  Timer? _minuteTimer;
  Timer? _fastForwardTimer;

  @override
  SkyMoment build() {
    final DateTime Function() clock = ref.watch(skyClockProvider);
    final AppLifecycleListener lifecycle = AppLifecycleListener(
      onStateChange: _onLifecycle,
    );
    ref.onCancel(_cancelTimers);
    ref.onResume(() => scheduleMicrotask(_catchUp));
    ref.onDispose(() {
      _cancelTimers();
      lifecycle.dispose();
    });
    _startMinuteTimer();
    return SkyMoment(instant: clock());
  }

  DateTime _clockNow() => ref.read(skyClockProvider)();

  void _publish(Duration offset, {required bool fastForwarding}) {
    state = SkyMoment(
      instant: _clockNow().add(offset),
      offset: offset,
      fastForwarding: fastForwarding,
    );
  }

  void _startMinuteTimer() {
    _minuteTimer?.cancel();
    _minuteTimer = Timer.periodic(
      skyRefreshInterval,
      (Timer _) => _publish(state.offset, fastForwarding: state.fastForwarding),
    );
  }

  void _cancelFastForward() {
    _fastForwardTimer?.cancel();
    _fastForwardTimer = null;
  }

  void _cancelTimers() {
    _minuteTimer?.cancel();
    _minuteTimer = null;
    _cancelFastForward();
  }

  void _catchUp() {
    if (!ref.mounted || ref.isPaused) {
      return;
    }
    _startMinuteTimer();
    _publish(state.offset, fastForwarding: _fastForwardTimer != null);
  }

  void _onLifecycle(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.resumed:
        ref.invalidate(localUtcOffsetProvider);
        ref.invalidate(localTimezoneIdentifierProvider);
        ref.invalidate(skyLocationProvider);
        _catchUp();
      case AppLifecycleState.inactive:
        if (_minuteTimer == null && !ref.isPaused) {
          _startMinuteTimer();
        }
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _cancelTimers();
        if (state.fastForwarding) {
          state = SkyMoment(instant: state.instant, offset: state.offset);
        }
    }
  }

  void toggleFastForward() {
    if (state.fastForwarding) {
      _cancelFastForward();
      state = SkyMoment(instant: state.instant, offset: state.offset);
      return;
    }
    _fastForwardTimer = Timer.periodic(
      skyFastForwardTick,
      (Timer _) =>
          _publish(state.offset + skyFastForwardStep, fastForwarding: true),
    );
    state = SkyMoment(
      instant: state.instant,
      offset: state.offset,
      fastForwarding: true,
    );
  }

  void now() {
    _cancelFastForward();
    _publish(Duration.zero, fastForwarding: false);
  }
}
