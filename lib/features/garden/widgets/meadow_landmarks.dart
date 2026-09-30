import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';

const double _minColumn = 190;
const double _sidebarGap = 10;
const double _bottomBarGap = 7;
const double _edge = Shapes.outlineWidth;
const Color _pillTint = Color(0x1AC76A54);
const Duration _borderDuration = Duration(milliseconds: 200);
const BorderRadius _cardRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusPill),
);
const BorderRadius _pillRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusXl),
);

@immutable
class MeadowLandmark {
  const MeadowLandmark({
    required this.kicker,
    required this.title,
    required this.text,
    this.range,
  });

  final String kicker;
  final String title;
  final String text;
  final MeadowRange? range;

  @override
  bool operator ==(Object other) =>
      other is MeadowLandmark &&
      other.kicker == kicker &&
      other.title == title &&
      other.text == text &&
      other.range == range;

  @override
  int get hashCode => Object.hash(kicker, title, text, range);
}

List<MeadowLandmark> meadowLandmarks(
  MeadowYear year, {
  required bool isCurrentYear,
}) {
  final MeadowRun run = year.longestRun;
  final MeadowWindow? heaviest = year.heaviest;
  final MeadowWindow? brightest = year.brightest;
  final int heavyPercent = (year.heavyShare * 100).round();
  final String soFar = isCurrentYear ? 'so far ' : '';
  return List<MeadowLandmark>.unmodifiable(<MeadowLandmark>[
    if (year.hasSpruce)
      MeadowLandmark(
        kicker: 'longest run',
        title: 'The old spruce',
        text:
            'The tallest tree at the forest edge marks the ${run.length} days '
            'in a row your meadow grew. The bees keep their hive in it.',
        range: MeadowRange(first: run.first, last: run.last, key: 'l0'),
      ),
    if (heaviest != null)
      MeadowLandmark(
        kicker: 'heaviest stretch',
        title: 'Mist in the hollow',
        text:
            'Fog settles over the flowers from these days. After dark the '
            'fireflies gather there and flash together.',
        range: MeadowRange(
          first: heaviest.first,
          last: heaviest.last,
          key: 'l1',
        ),
      ),
    if (brightest != null)
      MeadowLandmark(
        kicker: 'brightest stretch',
        title: 'Butterflies',
        text:
            'They drift toward the flowers from these days and linger '
            'longest there.',
        range: MeadowRange(
          first: brightest.first,
          last: brightest.last,
          key: 'l2',
        ),
      ),
    MeadowLandmark(
      kicker: 'the weather',
      title: year.weather,
      text:
          '$heavyPercent% of your days ${soFar}were heavy ones. That sets '
          'the cloud cover and how thick the morning fog lies.',
    ),
  ]);
}

class MeadowLandmarks extends StatelessWidget {
  const MeadowLandmarks({
    super.key,
    required this.year,
    required this.isCurrentYear,
    required this.compact,
    required this.highlight,
    required this.onHighlight,
  });

  final MeadowYear year;
  final bool isCurrentYear;
  final bool compact;
  final MeadowRange? highlight;
  final ValueChanged<MeadowRange?> onHighlight;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = <Widget>[
      for (final MeadowLandmark landmark in meadowLandmarks(
        year,
        isCurrentYear: isCurrentYear,
      ))
        _LandmarkCard(
          year: year.year,
          landmark: landmark,
          compact: compact,
          highlight: highlight,
          onHighlight: onHighlight,
        ),
    ];
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int index = 0; index < cards.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(height: _bottomBarGap),
            cards[index],
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int fit =
            ((constraints.maxWidth + _sidebarGap) / (_minColumn + _sidebarGap))
                .floor();
        final int columns = math.max(1, math.min(fit, cards.length));
        final int rows = (cards.length / columns).ceil();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int row = 0; row < rows; row++) ...<Widget>[
              if (row > 0) const SizedBox(height: _sidebarGap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (
                      int column = 0;
                      column < columns;
                      column++
                    ) ...<Widget>[
                      if (column > 0) const SizedBox(width: _sidebarGap),
                      Expanded(
                        child: row * columns + column < cards.length
                            ? cards[row * columns + column]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LandmarkCard extends StatelessWidget {
  const _LandmarkCard({
    required this.year,
    required this.landmark,
    required this.compact,
    required this.highlight,
    required this.onHighlight,
  });

  final int year;
  final MeadowLandmark landmark;
  final bool compact;
  final MeadowRange? highlight;
  final ValueChanged<MeadowRange?> onHighlight;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles styles = context.textStyles;
    final MeadowRange? range = landmark.range;
    final bool highlighted = range != null && highlight?.key == range.key;
    final Widget face = AnimatedContainer(
      duration: _borderDuration,
      padding: compact
          ? const EdgeInsets.fromLTRB(
              11 + _edge,
              9 + _edge,
              11 + _edge,
              10 + _edge,
            )
          : const EdgeInsets.fromLTRB(
              13 + _edge,
              11 + _edge,
              13 + _edge,
              12 + _edge,
            ),
      decoration: BoxDecoration(
        color: colors.cardWarm,
        border: Border.all(
          color: highlighted ? Palette.coral : colors.line,
          width: Shapes.outlineWidth,
        ),
        borderRadius: _cardRadius,
        boxShadow: context.shadows.cardDefault,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            landmark.kicker,
            style: styles.stampAccent.copyWith(fontSize: compact ? 13 : 14),
          ),
          const SizedBox(height: 1),
          Text(
            landmark.title,
            style: styles.sectionSerif.copyWith(
              fontSize: compact ? 15 : 17,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            landmark.text,
            style: styles.captionSans.copyWith(
              color: colors.inkSoft,
              fontSize: compact ? 11 : 12,
              height: 1.45,
            ),
          ),
          if (range != null) ...<Widget>[
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: _pillTint,
                borderRadius: _pillRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                child: Text(
                  meadowRangeLabel(year, range.first, range.last),
                  style: styles.caption11Sans.copyWith(
                    fontSize: compact ? 10 : 11,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    if (range == null) {
      return Semantics(container: true, child: face);
    }
    void toggle() => onHighlight(highlighted ? null : range);
    return Semantics(
      container: true,
      button: true,
      selected: highlighted,
      onTap: toggle,
      child: MouseRegion(
        onEnter: compact
            ? null
            : (PointerEnterEvent event) => onHighlight(range),
        onExit: compact ? null : (PointerExitEvent event) => onHighlight(null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: compact ? toggle : null,
          child: FocusRing(
            onPressed: toggle,
            borderRadius: _cardRadius,
            child: face,
          ),
        ),
      ),
    );
  }
}
