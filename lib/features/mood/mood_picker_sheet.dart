import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/mood/mood.dart';

import 'mood_picker_grid.dart';

const String _subtitle = "choose today's bloom";

const double _panelBorderWidth = 2;
const double _panelPadding = 22;
const double _subtitleGap = 1;
const double _gridGap = 16;

const double _sheetPaddingTop = 10;
const double _sheetPaddingHorizontal = 16;
const double _sheetPaddingBottom = 22;
const double _sheetTitleSize = 18;
const double _sheetSubtitleSize = 12;
const double _sheetGridGap = 14;

class MoodPickerSheet extends StatelessWidget {
  const MoodPickerSheet({
    super.key,
    required this.selected,
    required this.onMoodSelected,
    this.title = 'How are you feeling?',
    this.maxWidth = 420,
    this.layout = ShellLayout.sidebar,
  });

  final Mood? selected;
  final ValueChanged<Mood> onMoodSelected;
  final String title;
  final double maxWidth;
  final ShellLayout layout;

  @override
  Widget build(BuildContext context) {
    return layout == ShellLayout.bottomBar
        ? _buildSheet(context)
        : _buildPanel();
  }

  Widget _buildPanel() {
    return Center(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final FieldNotesColors colors = context.colors;
          final FieldNotesTextStyles textStyles = context.textStyles;
          return SizedBox(
            width: math.min(maxWidth, constraints.maxWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.cardWarm,
                border: Border.fromBorderSide(
                  BorderSide(color: colors.line, width: _panelBorderWidth),
                ),
                borderRadius: const BorderRadius.all(
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
                      style: textStyles.headlineSerif,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: _subtitleGap),
                    Text(
                      _subtitle,
                      style: textStyles.subtitleAccent,
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

  Widget _buildSheet(BuildContext context) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    return PhoneSheet(
      color: context.colors.cardWarm,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _sheetPaddingHorizontal,
          _sheetPaddingTop,
          _sheetPaddingHorizontal,
          _sheetPaddingBottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              style: textStyles.headlineSerif.copyWith(
                fontSize: _sheetTitleSize,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: _subtitleGap),
            Text(
              _subtitle,
              style: textStyles.subtitleAccent.copyWith(
                fontSize: _sheetSubtitleSize,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: _sheetGridGap),
            MoodPickerGrid(
              selected: selected,
              onMoodSelected: onMoodSelected,
              layout: layout,
            ),
          ],
        ),
      ),
    );
  }
}
