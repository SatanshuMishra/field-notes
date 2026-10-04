import 'package:field_notes/design/icons/flame_icon.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/services/streak_service.dart';
import 'package:field_notes/features/streak/streak_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StreakPillForm { header, headerOverScene, sidebar, rail }

String streakPillLabel(int days) => days == 1 ? '1 day' : '$days days';

String streakPillAnnouncement(int days) => '${streakPillLabel(days)} in a row';

const double streakPillHeaderHeight = 30;

const EdgeInsets _headerPadding = EdgeInsets.fromLTRB(9, 0, 11, 0);
const EdgeInsets _sidebarPadding = EdgeInsets.symmetric(
  vertical: 10,
  horizontal: 12,
);
const EdgeInsets _railPadding = EdgeInsets.symmetric(vertical: 10);

const BorderRadius _headerRadius = BorderRadius.all(
  Radius.circular(streakPillHeaderHeight / 2),
);
const BorderRadius _stickerRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);

const double _headerFlame = 14;
const double _stickerFlame = 17;
const double _headerGap = 5;
const double _sidebarGap = 6;
const double _railGap = 2;
const double _headerText = 19;
const double _sidebarText = 23;
const double _railText = 18;
const double _sceneEdgeWidth = 1;
const double _ringSpread = 4;

const Color _sceneFill = Color.fromRGBO(255, 250, 240, 0.14);
const Color _sceneEdge = Color.fromRGBO(255, 250, 240, 0.28);
const Color _ring = Color.fromRGBO(184, 86, 106, 0.25);

typedef _PillLook = ({
  Color fill,
  Border border,
  Color ink,
  Color flame,
  List<BoxShadow> shadows,
});

class StreakPill extends ConsumerWidget {
  const StreakPill({
    super.key,
    this.form = StreakPillForm.header,
    this.count,
    this.numberOnly = false,
    this.highlighted = false,
  });

  final StreakPillForm form;
  final int? count;
  final bool numberOnly;
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int days =
        count ??
        ref.watch(
          streakSummaryProvider.select(
            (StreakSummary summary) => summary.current,
          ),
        );
    final String announcement = streakPillAnnouncement(days);
    return Tooltip(
      message: announcement,
      excludeFromSemantics: true,
      child: Semantics(
        container: true,
        label: announcement,
        excludeSemantics: true,
        child: _pill(context, days),
      ),
    );
  }

  bool get _sticker =>
      form == StreakPillForm.sidebar || form == StreakPillForm.rail;

  _PillLook _look(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final List<BoxShadow> base = _sticker
        ? context.shadows.emphasis
        : const <BoxShadow>[];
    if (highlighted) {
      return (
        fill: Palette.coral,
        border: context.shadows.outline,
        ink: Palette.onAccent,
        flame: Palette.onAccent,
        shadows: <BoxShadow>[
          const BoxShadow(color: _ring, spreadRadius: _ringSpread),
          ...base,
        ],
      );
    }
    return switch (form) {
      StreakPillForm.header => (
        fill: colors.cardLight,
        border: Border.all(color: colors.ink22, width: Shapes.outlineWidth),
        ink: colors.accentInk,
        flame: colors.accentInk,
        shadows: base,
      ),
      StreakPillForm.headerOverScene => (
        fill: _sceneFill,
        border: Border.all(color: _sceneEdge, width: _sceneEdgeWidth),
        ink: colors.accentTint,
        flame: colors.accentInk,
        shadows: base,
      ),
      StreakPillForm.sidebar || StreakPillForm.rail => (
        fill: colors.cardLight,
        border: context.shadows.outline,
        ink: colors.accentInk,
        flame: colors.accentInk,
        shadows: base,
      ),
    };
  }

  Widget _pill(BuildContext context, int days) {
    final _PillLook look = _look(context);
    final bool bareNumber = numberOnly || form == StreakPillForm.rail;
    final String label = bareNumber ? '$days' : streakPillLabel(days);
    final double textSize = switch (form) {
      StreakPillForm.header || StreakPillForm.headerOverScene => _headerText,
      StreakPillForm.sidebar => _sidebarText,
      StreakPillForm.rail => _railText,
    };
    final Widget text = Text(
      label,
      maxLines: 1,
      softWrap: false,
      style: context.textStyles.streakAccent.copyWith(
        fontSize: textSize,
        color: look.ink,
      ),
    );
    final BoxDecoration decoration = BoxDecoration(
      color: look.fill,
      border: look.border,
      borderRadius: _sticker ? _stickerRadius : _headerRadius,
      boxShadow: look.shadows,
    );
    return switch (form) {
      StreakPillForm.header || StreakPillForm.headerOverScene => SizedBox(
        height: streakPillHeaderHeight,
        child: DecoratedBox(
          decoration: decoration,
          child: Padding(
            padding: _headerPadding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FlameIcon(color: look.flame, size: _headerFlame),
                const SizedBox(width: _headerGap),
                text,
              ],
            ),
          ),
        ),
      ),
      StreakPillForm.sidebar => DecoratedBox(
        decoration: decoration,
        child: Padding(
          padding: _sidebarPadding,
          child: Row(
            children: <Widget>[
              FlameIcon(color: look.flame, size: _stickerFlame),
              const SizedBox(width: _sidebarGap),
              Flexible(child: text),
            ],
          ),
        ),
      ),
      StreakPillForm.rail => DecoratedBox(
        decoration: decoration,
        child: Padding(
          padding: _railPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FlameIcon(color: look.flame, size: _stickerFlame),
              const SizedBox(height: _railGap),
              text,
            ],
          ),
        ),
      ),
    };
  }
}
