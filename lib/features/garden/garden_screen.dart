import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';

import 'model/garden_data.dart';
import 'sky/sky_location.dart';
import 'sky/sky_location_provider.dart';
import 'sky/sky_time.dart';
import 'widgets/garden_view.dart';

class GardenScreen extends ConsumerWidget {
  const GardenScreen({super.key, this.year});

  final int? year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int resolvedYear = year ?? ref.watch(skyClockProvider)().year;
    final AsyncValue<List<Day>> days = ref.watch(allDaysProvider);
    final List<String> journaled =
        ref.watch(journaledDatesProvider).value ?? const <String>[];
    final SkyMoment moment = ref.watch(skyTimeProvider);
    final SkyLocation location =
        ref.watch(skyLocationProvider).value ??
        resolveSkyLocation(null, DateTime.now().timeZoneOffset);
    final bool debugControls = ref.watch(skyDebugControlsProvider);
    final SkyTime sky = ref.read(skyTimeProvider.notifier);
    GardenPage page(Widget card) => GardenPage(
      moment: moment,
      location: location,
      card: card,
      debugControls: debugControls,
      onNow: sky.now,
      onFastForward: sky.toggleFastForward,
    );
    return days.when(
      data: (List<Day> list) => GardenView(
        blooms: gardenBloomsForYear(list, resolvedYear),
        tally: moodTally(list, resolvedYear),
        year: resolvedYear,
        sprouts: gardenSproutsForYear(list, journaled, resolvedYear),
        moment: moment,
        location: location,
        debugControls: debugControls,
        onNow: sky.now,
        onFastForward: sky.toggleFastForward,
      ),
      loading: () => page(const _GardenLoading()),
      error: (Object error, StackTrace stackTrace) =>
          page(const _GardenError()),
    );
  }
}

class _GardenLoading extends StatelessWidget {
  const _GardenLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Growing your garden…',
        style: context.textStyles.captionSans,
      ),
    );
  }
}

class _GardenError extends StatelessWidget {
  const _GardenError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyStatePlaceholder(
          message: 'Your garden could not be loaded right now.',
          messageStyle: context.textStyles.bodySerif,
        ),
      ),
    );
  }
}
