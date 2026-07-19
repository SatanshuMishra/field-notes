import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/services/streak_service.dart';
import 'package:field_notes/features/streak/streak_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StreakSummary summary = ref.watch(streakSummaryProvider);
    final String dayLabel = summary.current == 1 ? 'day' : 'days';
    return StickerCard(
      key: const ValueKey<String>('streak-card'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.local_fire_department,
            size: 18,
            color: Palette.coral,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${summary.current} $dayLabel',
                  style: TypographyTokens.streakAccent,
                ),
                Text(
                  'longest streak yet: ${summary.longest}',
                  style: TypographyTokens.captionSans,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
