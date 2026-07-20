import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/state/journal_providers.dart';

import 'model/garden_data.dart';
import 'widgets/garden_view.dart';

class GardenScreen extends ConsumerWidget {
  const GardenScreen({super.key, this.year});

  final int? year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int resolvedYear = year ?? DateTime.now().year;
    final AsyncValue<List<Day>> days = ref.watch(allDaysProvider);
    return days.when(
      data: (List<Day> list) => GardenView(
        blooms: gardenBloomsForYear(list, resolvedYear),
        tally: moodTally(list, resolvedYear),
        year: resolvedYear,
      ),
      loading: () => const _GardenLoading(),
      error: (Object error, StackTrace stackTrace) => const _GardenError(),
    );
  }
}

class _GardenLoading extends StatelessWidget {
  const _GardenLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Growing your garden…',
        style: TypographyTokens.captionSans,
      ),
    );
  }
}

class _GardenError extends StatelessWidget {
  const _GardenError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePlaceholder(
          message: 'Your garden could not be loaded right now.',
          messageStyle: TypographyTokens.bodySerif,
        ),
      ),
    );
  }
}
