import 'package:flutter/widgets.dart';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';

const int _columns = 4;

const double _tileBorderWidth = 2;
const double _tilePaddingHorizontal = 6;
const double _tilePaddingVertical = 11;
const double _tileLabelGap = 5;

class MoodPickerGrid extends StatelessWidget {
  const MoodPickerGrid({
    super.key,
    required this.selected,
    required this.onMoodSelected,
    this.flowerSize = 44,
    this.spacing = 10,
    this.runSpacing = 10,
  });

  final Mood? selected;
  final ValueChanged<Mood> onMoodSelected;
  final double flowerSize;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int start = 0; start < moodOrder.length; start += _columns)
          ...<Widget>[
            if (start > 0) SizedBox(height: runSpacing),
            _buildRow(start),
          ],
      ],
    );
  }

  Widget _buildRow(int start) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int column = 0; column < _columns; column++) ...<Widget>[
          if (column > 0) SizedBox(width: spacing),
          Expanded(child: _buildCell(start + column)),
        ],
      ],
    );
  }

  Widget _buildCell(int index) {
    if (index >= moodOrder.length) {
      return const SizedBox.shrink();
    }
    final Mood mood = moodOrder[index];
    return _MoodTile(
      mood: mood,
      isSelected: mood == selected,
      flowerSize: flowerSize,
      onTap: () => onMoodSelected(mood),
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
            color: isSelected ? Palette.cardLight : Palette.cardBright,
            border: Border.all(
              color: isSelected ? Palette.coral : Palette.ink20,
              width: isSelected ? _tileBorderWidth : Shapes.outlineWidth,
            ),
            borderRadius: BorderRadius.circular(Shapes.radiusMd),
            boxShadow: isSelected ? Shadows.tileSelected : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _tilePaddingHorizontal,
              vertical: _tilePaddingVertical,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FlowerBloom.forMood(mood, size: flowerSize),
                const SizedBox(height: _tileLabelGap),
                Text(
                  mood.label,
                  style: TypographyTokens.caption11Sans.copyWith(
                    color: Palette.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  mood.flower.label,
                  style: TypographyTokens.caption9Sans,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
