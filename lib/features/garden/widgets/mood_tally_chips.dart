import 'package:flutter/widgets.dart';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import '../model/garden_data.dart';

class MoodTallyChips extends StatelessWidget {
  const MoodTallyChips({super.key, required this.entries});

  final List<MoodTallyEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final MoodTallyEntry entry in entries)
          _MoodTallyChip(entry: entry),
      ],
    );
  }
}

class _MoodTallyChip extends StatelessWidget {
  const _MoodTallyChip({required this.entry});

  final MoodTallyEntry entry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.cardBright,
        borderRadius: Shapes.buttonBorderRadius,
        border: Border.fromBorderSide(
          BorderSide(color: Palette.ink, width: Shapes.outlineWidth),
        ),
        boxShadow: Shadows.button,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FlowerBloom.forMood(entry.mood, size: 18),
            const SizedBox(width: 6),
            Text('${entry.count}', style: TypographyTokens.labelSans),
            const SizedBox(width: 4),
            Text(entry.mood.label, style: TypographyTokens.captionSans),
          ],
        ),
      ),
    );
  }
}
