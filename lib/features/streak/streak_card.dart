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
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles textStyles = context.textStyles;
    return StickerCard(
      key: const ValueKey<String>('streak-card'),
      surface: colors.cardLight,
      borderRadius: const BorderRadius.all(
        Radius.circular(Shapes.radiusMd),
      ),
      shadow: context.shadows.emphasis,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 13),
      child: Row(
        children: <Widget>[
          FlameIcon(color: colors.accentInk),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${summary.current} $dayLabel',
                  style: textStyles.streakAccent,
                ),
                const SizedBox(height: 3),
                Text(
                  'longest streak yet: ${summary.longest}',
                  style: textStyles.caption10Sans,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
