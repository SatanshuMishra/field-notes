import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';

import 'model/meadow_key_provider.dart';
import 'model/meadow_random.dart';
import 'model/meadow_view_state.dart';
import 'model/meadow_year.dart';
import 'scene/meadow_stage.dart';
import 'sky/sky_location.dart';
import 'sky/sky_location_provider.dart';
import 'sky/sky_time.dart';
import 'widgets/garden_view.dart';
import 'widgets/meadow_full_screen.dart';

const String meadowErrorMessage = 'Your meadow could not be loaded right now.';

class GardenScreen extends ConsumerStatefulWidget {
  const GardenScreen({super.key, this.fullScreen});

  final MeadowFullScreenRequest? fullScreen;

  @override
  ConsumerState<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends ConsumerState<GardenScreen> {
  _MeadowYears? _years;

  _MeadowYears _yearsOf({
    required List<Day> days,
    required Map<String, int> counts,
    required DateTime today,
  }) {
    final _MeadowYears? cached = _years;
    if (cached != null && cached.holds(days, counts, today)) {
      return cached;
    }
    final _MeadowYears built = _MeadowYears.build(
      days: days,
      counts: counts,
      today: today,
    );
    _years = built;
    return built;
  }

  void _openFullScreen(
    MeadowFullScreenRequest request, {
    required MeadowYear year,
    required int seed,
  }) {
    ref.read(meadowViewStateProvider.notifier).openFullScreen(request);
    unawaited(
      openMeadowFullScreen(
        context,
        request: request,
        year: year,
        seed: seed,
        compact: meadowIsCompact(context),
      ),
    );
  }

  void _leaveFullScreen(MeadowFullScreenRequest request) {
    if (ModalRoute.isCurrentOf(context) ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime today = ref.watch(skyClockProvider)().toLocal();
    final int currentYear = today.year;
    final int? studyYear = ref.watch(meadowViewStateProvider).studyYear;
    final int shownYear = studyYear ?? currentYear;
    final AsyncValue<List<Day>> days = ref.watch(allDaysProvider);
    final AsyncValue<Map<String, int>> counts = ref.watch(
      journalEntryCountsProvider,
    );
    final AsyncValue<int> key = ref.watch(meadowKeyProvider);
    final SkyMoment moment = ref.watch(skyTimeProvider);
    final SkyLocation location =
        ref.watch(skyLocationProvider).value ??
        resolveSkyLocation(null, DateTime.now().timeZoneOffset);
    final bool study = studyYear != null;
    if (days.hasError || counts.hasError || key.hasError) {
      return MeadowPageNotice(
        year: shownYear,
        study: study,
        child: const _MeadowError(),
      );
    }
    final List<Day>? dayList = days.value;
    final Map<String, int>? countMap = counts.value;
    final int? meadowKey = key.value;
    if (dayList == null || countMap == null || meadowKey == null) {
      return MeadowPageNotice(
        year: shownYear,
        study: study,
        child: const _MeadowLoading(),
      );
    }
    final _MeadowYears years = _yearsOf(
      days: dayList,
      counts: countMap,
      today: today,
    );
    final MeadowYear shown = years.of(shownYear);
    final int seed = meadowSeed(meadowKey, shown.year);
    final MeadowFullScreenRequest? fullScreen = widget.fullScreen;
    final SkyTime sky = ref.read(skyTimeProvider.notifier);
    final MeadowViewState view = ref.read(meadowViewStateProvider.notifier);
    return MeadowPage(
      year: shown,
      years: years.listed,
      currentYear: currentYear,
      seed: seed,
      moment: moment,
      today: today,
      location: location,
      fullScreen: fullScreen,
      onNow: sky.now,
      onFastForward: sky.toggleFastForward,
      onPickYear: (int year) => view.openYear(year, currentYear: currentYear),
      onBack: view.backToThisYear,
      onFullScreen: fullScreen == null
          ? (MeadowFullScreenRequest request) =>
                _openFullScreen(request, year: shown, seed: seed)
          : _leaveFullScreen,
    );
  }
}

class _MeadowYears {
  const _MeadowYears._({
    required this.days,
    required this.counts,
    required this.today,
    required this.listed,
  });

  factory _MeadowYears.build({
    required List<Day> days,
    required Map<String, int> counts,
    required DateTime today,
  }) {
    final DateTime date = DateTime(today.year, today.month, today.day);
    return _MeadowYears._(
      days: days,
      counts: counts,
      today: date,
      listed: List<MeadowYear>.unmodifiable(<MeadowYear>[
        for (final int year in meadowYears(
          days: days,
          journaledDates: counts.keys,
          currentYear: date.year,
        ))
          MeadowYear.build(
            days: days,
            entryCounts: counts,
            year: year,
            today: date,
          ),
      ]),
    );
  }

  final List<Day> days;
  final Map<String, int> counts;
  final DateTime today;
  final List<MeadowYear> listed;

  bool holds(List<Day> days, Map<String, int> counts, DateTime today) =>
      identical(this.days, days) &&
      identical(this.counts, counts) &&
      this.today.year == today.year &&
      this.today.month == today.month &&
      this.today.day == today.day;

  MeadowYear of(int year) {
    for (final MeadowYear listedYear in listed) {
      if (listedYear.year == year) {
        return listedYear;
      }
    }
    return MeadowYear.build(
      days: days,
      entryCounts: counts,
      year: year,
      today: today,
    );
  }
}

class _MeadowLoading extends StatelessWidget {
  const _MeadowLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        meadowLoadingMessage,
        textAlign: TextAlign.center,
        style: context.textStyles.captionSans,
      ),
    );
  }
}

class _MeadowError extends StatelessWidget {
  const _MeadowError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyStatePlaceholder(
          message: meadowErrorMessage,
          messageStyle: context.textStyles.bodySerif,
        ),
      ),
    );
  }
}
