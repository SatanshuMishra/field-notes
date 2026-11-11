import 'dart:async';

import 'package:field_notes/domain/services/streak_service.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'streak_providers.g.dart';

@riverpod
DateTime Function() streakClock(Ref ref) => DateTime.now;

@riverpod
DateTime streakNow(Ref ref) {
  final DateTime now = ref.watch(streakClockProvider)();
  final Timer boundary = Timer(
    nextStreakBoundary(now).difference(now),
    ref.invalidateSelf,
  );
  final AppLifecycleListener lifecycle = AppLifecycleListener(
    onResume: ref.invalidateSelf,
  );
  ref.onDispose(() {
    boundary.cancel();
    lifecycle.dispose();
  });
  return now;
}

@riverpod
StreakSummary streakSummary(Ref ref) {
  final List<StreakDay> days =
      ref.watch(streakDaysProvider).value ?? const <StreakDay>[];
  final DateTime now = ref.watch(streakNowProvider);
  try {
    return const StreakService().summarize(days: days, now: now);
  } on FormatException {
    return const StreakSummary.empty();
  }
}
