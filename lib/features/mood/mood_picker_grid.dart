import 'package:flutter/widgets.dart';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';

class MoodPickerGrid extends StatelessWidget {
  const MoodPickerGrid({
    super.key,
    required this.selected,
    required this.onMoodSelected,
    this.flowerSize = 56,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  final Mood? selected;
  final ValueChanged<Mood> onMoodSelected;
  final double flowerSize;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: spacing,
      runSpacing: runSpacing,
      children: <Widget>[
        for (final Mood mood in moodOrder)
          _MoodTile(
            mood: mood,
            isSelected: mood == selected,
            flowerSize: flowerSize,
            onTap: () => onMoodSelected(mood),
          ),
      ],
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.mood,
    required this.isSelected,
    required this.flowerSize,
    required this.onTap,
  });

  final Mood mood;
  final bool isSelected;
  final double flowerSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: mood.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected ? Palette.panelCoralTint : null,
            border: isSelected
                ? Border.all(
                    color: Palette.coral,
                    width: Shapes.outlineWidth,
                  )
                : null,
            borderRadius: BorderRadius.circular(Shapes.radiusSm),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FlowerBloom.forMood(mood, size: flowerSize),
                const SizedBox(height: 6),
                Text(mood.label, style: TypographyTokens.captionSans),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
