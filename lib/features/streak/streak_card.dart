import 'package:field_notes/design/icons/flame_icon.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/services/streak_service.dart';
import 'package:field_notes/features/streak/streak_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StreakSummary summary = ref.watch(streakSummaryProvider);
    final String dayLabel = summary.current == 1 ? 'day' : 'days';
    return StickerCard(
      key: const ValueKey<String>('streak-card'),
      surface: Palette.cardLight,
      borderRadius: const BorderRadius.all(
        Radius.circular(Shapes.radiusMd),
      ),
      shadow: Shadows.emphasis,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 13),
      child: Row(
        children: <Widget>[
          const FlameIcon(color: Palette.coral),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${summary.current} $dayLabel',
                  style: TypographyTokens.streakAccent,
                ),
                const SizedBox(height: 3),
                Text(
                  'longest streak yet: ${summary.longest}',
                  style: TypographyTokens.caption10Sans,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
