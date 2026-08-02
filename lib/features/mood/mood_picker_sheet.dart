import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';

import 'mood_picker_grid.dart';

const String _subtitle = "choose today's bloom";

const double _panelBorderWidth = 2;
const double _panelPadding = 22;
const double _subtitleGap = 1;
const double _gridGap = 16;

const double _sheetPaddingTop = 18;
const double _sheetPaddingHorizontal = 16;
const double _sheetPaddingBottom = 22;
const double _sheetTitleSize = 18;
const double _sheetSubtitleSize = 12;
const double _sheetGridGap = 14;
const double _grabHandleWidth = 38;
const double _grabHandleHeight = 4;
const double _grabHandleRadius = 3;
const double _grabHandleGap = 12;

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
    return layout == ShellLayout.bottomBar ? _buildSheet() : _buildPanel();
  }

  Widget _buildPanel() {
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

  Widget _buildSheet() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Palette.cardWarm,
            border: Border(
              top: BorderSide(color: Palette.ink, width: _panelBorderWidth),
            ),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(Shapes.radiusSheet),
            ),
            boxShadow: Shadows.pickerSheetLift,
          ),
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
                const SizedBox(
                  width: _grabHandleWidth,
                  height: _grabHandleHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Palette.ink30,
                      borderRadius: BorderRadius.all(
                        Radius.circular(_grabHandleRadius),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _grabHandleGap),
                Text(
                  title,
                  style: TypographyTokens.headlineSerif.copyWith(
                    fontSize: _sheetTitleSize,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: _subtitleGap),
                Text(
                  _subtitle,
                  style: TypographyTokens.subtitleAccent.copyWith(
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
        ),
      ),
    );
  }
}
