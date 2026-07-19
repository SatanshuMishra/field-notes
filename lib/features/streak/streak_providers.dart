import 'package:field_notes/domain/services/streak_service.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'streak_providers.g.dart';

@riverpod
DateTime Function() streakClock(Ref ref) => DateTime.now;

@riverpod
StreakSummary streakSummary(Ref ref) {
  final dates = ref.watch(journaledDatesProvider).value ?? const <String>[];
  final now = ref.watch(streakClockProvider)();
  try {
    return const StreakService().summarize(journaledDates: dates, today: now);
  } on FormatException {
    return const StreakSummary.empty();
  }
}
