import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';

const int _columns = 4;

const double _tileBorderWidth = 2;
const double _tilePaddingHorizontal = 6;
const double _tilePaddingVertical = 11;
const double _tileLabelGap = 5;
const double _panelFlowerSize = 44;
const double _panelGap = 10;

const double _sheetTilePaddingHorizontal = 4;
const double _sheetTilePaddingVertical = 8;
const double _sheetTileLabelGap = 4;
const double _sheetFlowerSize = 34;
const double _sheetGap = 8;

const BorderRadius _tileRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);

class MoodPickerGrid extends StatelessWidget {
  const MoodPickerGrid({
    super.key,
    required this.selected,
    required this.onMoodSelected,
    this.layout = ShellLayout.sidebar,
    this.flowerSize,
    this.spacing,
    this.runSpacing,
  });

  final Mood? selected;
  final ValueChanged<Mood> onMoodSelected;
  final ShellLayout layout;
  final double? flowerSize;
  final double? spacing;
  final double? runSpacing;

  bool get _isSheet => layout == ShellLayout.bottomBar;

  double get _flowerSize =>
      flowerSize ?? (_isSheet ? _sheetFlowerSize : _panelFlowerSize);

  double get _spacing => spacing ?? (_isSheet ? _sheetGap : _panelGap);

  double get _runSpacing => runSpacing ?? (_isSheet ? _sheetGap : _panelGap);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int start = 0; start < moodOrder.length; start += _columns)
          ...<Widget>[
            if (start > 0) SizedBox(height: _runSpacing),
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
          if (column > 0) SizedBox(width: _spacing),
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
      flowerSize: _flowerSize,
      layout: layout,
      onTap: () => onMoodSelected(mood),
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.mood,
    required this.isSelected,
    required this.flowerSize,
    required this.layout,
    required this.onTap,
  });

  final Mood mood;
  final bool isSelected;
  final double flowerSize;
  final ShellLayout layout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isSheet = layout == ShellLayout.bottomBar;
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Semantics(
      button: true,
      selected: isSelected,
      label: mood.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FocusRing(
          onPressed: onTap,
          borderRadius: _tileRadius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isSelected ? colors.cardLight : colors.cardBright,
              border: Border.all(
                color: isSelected ? Palette.coral : colors.ink20,
                width: isSelected ? _tileBorderWidth : Shapes.outlineWidth,
              ),
              borderRadius: _tileRadius,
              boxShadow: isSelected ? Shadows.tileSelected : null,
            ),
            child: ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSheet
                      ? _sheetTilePaddingHorizontal
                      : _tilePaddingHorizontal,
                  vertical: isSheet
                      ? _sheetTilePaddingVertical
                      : _tilePaddingVertical,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FlowerBloom.forMood(mood, size: flowerSize),
                    SizedBox(
                      height: isSheet ? _sheetTileLabelGap : _tileLabelGap,
                    ),
                    Text(
                      mood.label,
                      style: isSheet
                          ? textStyles.caption9Sans.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.ink,
                            )
                          : textStyles.caption11Sans.copyWith(
                              color: colors.ink,
                            ),
                      textAlign: TextAlign.center,
                    ),
                    if (!isSheet)
                      Text(
                        mood.flower.label,
                        style: textStyles.caption9Sans,
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
