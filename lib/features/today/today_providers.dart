import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver_provider.dart';
import 'package:field_notes/state/state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'today_date.dart';
import 'today_memory.dart';
import 'today_week.dart';

part 'today_providers.g.dart';

@riverpod
DateTime Function() todayClock(Ref ref) => DateTime.now;

@riverpod
String todayDate(Ref ref) => captureDateKey(ref.watch(todayClockProvider)());

@riverpod
List<TodayWeekCell> thisWeekCells(Ref ref) {
  final DateTime today = ref.watch(todayClockProvider)();
  final WeekStart weekStart = ref.watch(weekStartProvider);
  final List<Day> days = ref.watch(allDaysProvider).value ?? const <Day>[];
  return buildWeekCells(today: today, weekStart: weekStart, days: days);
}

@riverpod
Future<MediaResolver> todayMediaResolver(Ref ref) =>
    ref.watch(mediaResolverProvider.future);

@riverpod
EntryAudioPlayerFactory todayAudioPlayerFactory(Ref ref) =>
    JustAudioEntryPlayer.new;

@riverpod
EntryVideoPlayerFactory todayVideoPlayerFactory(Ref ref) =>
    VideoPlayerEntryPlayer.new;

@riverpod
Future<OnThisDayMemory?> onThisDayMemory(Ref ref) async {
  final DateTime today = ref.watch(todayClockProvider)();
  final List<Day>? days = ref.watch(allDaysProvider).value;
  final List<Day> candidates = days == null
      ? await ref
            .watch(journalRepositoryProvider)
            .onThisDay(month: today.month, day: today.day)
      : <Day>[
          for (final Day day in days)
            if (_onMonthDay(day, today)) day,
        ];
  return selectOnThisDay(candidates: candidates, today: today);
}

bool _onMonthDay(Day day, DateTime today) {
  final DateTime? date = parseDateKey(day.date);
  return date != null && date.month == today.month && date.day == today.day;
}
