import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/format/plural.dart';
import 'package:field_notes/design/tokens/typography.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/widgets/garden_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:flutter/material.dart';

const String meadowBackLabel = 'Your meadow this year';
const String meadowBackCompactLabel = 'This year';
const String meadowFullScreenLabel = 'Full screen';
const String meadowExitFullScreenLabel = 'Exit full screen';
const String meadowDetailsLabel = 'The year, day by day';
const String meadowTimeButtonLabel = 'Time of day';
const ValueKey<String> meadowTitleKey = ValueKey<String>('meadow-title');
const ValueKey<String> meadowTitleBlockKey = ValueKey<String>(
  'meadow-title-block',
);
const ValueKey<String> meadowDockKey = ValueKey<String>('meadow-dock');
const ValueKey<String> meadowTimeButtonKey = ValueKey<String>(
  'meadow-time-button',
);
const ValueKey<String> meadowDetailsButtonKey = ValueKey<String>(
  'meadow-details-button',
);
const ValueKey<String> meadowFullScreenButtonKey = ValueKey<String>(
  'meadow-full-screen-button',
);
const ValueKey<String> meadowThisYearButtonKey = ValueKey<String>(
  'meadow-this-year-button',
);

const Color _kickerShadow = Color.fromRGBO(0, 0, 0, 0.4);
const Color _titleShadow = Color.fromRGBO(0, 0, 0, 0.45);
const Color _summaryShadow = Color.fromRGBO(0, 0, 0, 0.5);
const BorderRadius _linkRadius = BorderRadius.all(Radius.circular(6));

final Path meadowBackChevron = Path()
  ..moveTo(15, 5)
  ..lineTo(8, 12)
  ..lineTo(15, 19);

final Path meadowNextChevron = Path()
  ..moveTo(9, 5)
  ..lineTo(16, 12)
  ..lineTo(9, 19);

final Path meadowExpandCorners = Path()
  ..moveTo(4, 9)
  ..lineTo(4, 4)
  ..lineTo(9, 4)
  ..moveTo(20, 9)
  ..lineTo(20, 4)
  ..lineTo(15, 4)
  ..moveTo(4, 15)
  ..lineTo(4, 20)
  ..lineTo(9, 20)
  ..moveTo(20, 15)
  ..lineTo(20, 20)
  ..lineTo(15, 20);

final Path meadowCollapseCorners = Path()
  ..moveTo(9, 4)
  ..lineTo(9, 9)
  ..lineTo(4, 9)
  ..moveTo(15, 4)
  ..lineTo(15, 9)
  ..lineTo(20, 9)
  ..moveTo(9, 20)
  ..lineTo(9, 15)
  ..lineTo(4, 15)
  ..moveTo(15, 20)
  ..lineTo(15, 15)
  ..lineTo(20, 15);

final Path meadowFourSquares = Path()
  ..addRRect(RRect.fromLTRBR(3.5, 4, 10.5, 11, const Radius.circular(1.5)))
  ..addRRect(RRect.fromLTRBR(13.5, 4, 20.5, 11, const Radius.circular(1.5)))
  ..addRRect(RRect.fromLTRBR(3.5, 14, 10.5, 21, const Radius.circular(1.5)))
  ..addRRect(RRect.fromLTRBR(13.5, 14, 20.5, 21, const Radius.circular(1.5)));

final Path meadowCross = Path()
  ..moveTo(6, 6)
  ..lineTo(18, 18)
  ..moveTo(18, 6)
  ..lineTo(6, 18);

class MeadowGlyph extends StatelessWidget {
  const MeadowGlyph({
    super.key,
    required this.path,
    required this.size,
    this.color = meadowCream,
    this.stroke = 2,
  });

  final Path path;
  final double size;
  final Color color;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: MeadowStrokePainter(path: path, color: color, stroke: stroke),
    );
  }
}

String meadowKickerOf({required bool study}) =>
    study ? 'meadow study' : 'your meadow';

String meadowTitleOf({required bool study, required int year}) =>
    study ? 'Your meadow, $year' : 'Every day, a bloom';

String meadowSummaryOf({
  required bool study,
  required bool compact,
  required int year,
  required int blooms,
  required int sprouts,
  required String weather,
}) {
  final String counts = meadowCountPhrase(blooms, sprouts);
  if (compact) {
    return study
        ? '$weather · ${pluralize(blooms, 'bloom')}'
        : '$counts so far in $year';
  }
  return study
      ? '$weather · $counts across $year'
      : '$counts so far in $year · quietly filling in as the year goes';
}

class MeadowHeader extends StatelessWidget {
  const MeadowHeader({
    super.key,
    required this.compact,
    required this.mode,
    required this.year,
    required this.blooms,
    required this.sprouts,
    required this.weather,
    this.onBack,
  });

  final bool compact;
  final MeadowSceneMode mode;
  final int year;
  final int blooms;
  final int sprouts;
  final String weather;
  final VoidCallback? onBack;

  bool get _study => mode == MeadowSceneMode.study;

  @override
  Widget build(BuildContext context) {
    final bool study = _study;
    final VoidCallback? back = onBack;
    final String summary = meadowSummaryOf(
      study: study,
      compact: compact,
      year: year,
      blooms: blooms,
      sprouts: sprouts,
      weather: weather,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!compact && study && back != null) ...<Widget>[
          MeadowBackLink(onPressed: back),
          const SizedBox(height: 6),
        ],
        IgnorePointer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              MeadowTitle(compact: compact, study: study, year: year),
              SizedBox(height: compact ? 4 : 6),
              Text(
                summary,
                maxLines: compact ? 2 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                style:
                    meadowSans(
                      compact ? 11.5 : 12.5,
                      opacity: compact ? 0.9 : 0.88,
                      weight: FontWeight.w500,
                    ).copyWith(
                      height: 1.4,
                      shadows: const <Shadow>[
                        Shadow(color: _summaryShadow, blurRadius: 8),
                      ],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MeadowTitle extends StatelessWidget {
  const MeadowTitle({
    super.key,
    required this.compact,
    required this.study,
    required this.year,
  });

  final bool compact;
  final bool study;
  final int year;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          meadowKickerOf(study: study),
          style: meadowHandStyle(compact ? 16 : 17).copyWith(
            shadows: const <Shadow>[
              Shadow(color: _kickerShadow, blurRadius: 8),
            ],
          ),
        ),
        Semantics(
          header: true,
          child: Text(
            meadowTitleOf(study: study, year: year),
            key: meadowTitleKey,
            style: TextStyle(
              fontFamily: TypographyTokens.serif,
              fontSize: compact ? 26 : 34,
              fontWeight: FontWeight.w500,
              height: compact ? 1.05 : 1.02,
              color: meadowCream,
              shadows: const <Shadow>[
                Shadow(
                  color: _titleShadow,
                  offset: Offset(0, 2),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MeadowBackLink extends StatelessWidget {
  const MeadowBackLink({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget face = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          MeadowGlyph(
            path: meadowBackChevron,
            size: 12,
            color: meadowCreamAt(0.9),
            stroke: 2.4,
          ),
          const SizedBox(width: 5),
          Text(
            meadowBackLabel,
            maxLines: 1,
            softWrap: false,
            style: meadowSans(12, opacity: 0.9),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: meadowBackLabel,
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onPressed,
          child: FocusRing(
            onPressed: onPressed,
            surface: FocusRingSurface.dark,
            borderRadius: _linkRadius,
            child: ExcludeSemantics(child: face),
          ),
        ),
      ),
    );
  }
}
