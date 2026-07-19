import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/mood/mood.dart';

import 'mood_picker_grid.dart';

class MoodPickerSheet extends StatelessWidget {
  const MoodPickerSheet({
    super.key,
    required this.selected,
    required this.onMoodSelected,
    this.title = 'How are you feeling?',
    this.maxWidth = 360,
  });

  final Mood? selected;
  final ValueChanged<Mood> onMoodSelected;
  final String title;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: StickerCard(
          surface: Palette.cardBright,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: TypographyTokens.titleSerif),
              const SizedBox(height: 16),
              MoodPickerGrid(
                selected: selected,
                onMoodSelected: onMoodSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
