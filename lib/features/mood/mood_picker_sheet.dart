import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';

import 'mood_picker_grid.dart';

const String _subtitle = "choose today's bloom";

const double _panelBorderWidth = 2;
const double _panelPadding = 22;
const double _subtitleGap = 1;
const double _gridGap = 16;

class MoodPickerSheet extends StatelessWidget {
  const MoodPickerSheet({
    super.key,
    required this.selected,
    required this.onMoodSelected,
    this.title = 'How are you feeling?',
    this.maxWidth = 420,
  });

  final Mood? selected;
  final ValueChanged<Mood> onMoodSelected;
  final String title;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SizedBox(
            width: math.min(maxWidth, constraints.maxWidth),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Palette.cardWarm,
                border: Border.fromBorderSide(
                  BorderSide(color: Palette.ink, width: _panelBorderWidth),
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(Shapes.radiusXl),
                ),
                boxShadow: Shadows.softLift,
              ),
              child: Padding(
                padding: const EdgeInsets.all(_panelPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: TypographyTokens.headlineSerif,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: _subtitleGap),
                    const Text(
                      _subtitle,
                      style: TypographyTokens.subtitleAccent,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: _gridGap),
                    MoodPickerGrid(
                      selected: selected,
                      onMoodSelected: onMoodSelected,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
