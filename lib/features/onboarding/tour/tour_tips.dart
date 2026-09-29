import 'dart:ui' as ui;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:field_notes/design/icons/nav_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/onboarding/tour_anchor.dart';
import 'package:field_notes/features/today/today_date.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TourSide { right, left, below, above }

enum TourVisual { pages, moods, capture, noteContent, week, settings }

class TourSpot {
  const TourSpot({
    required this.padding,
    required this.radius,
    required this.side,
  });

  final double padding;
  final double radius;
  final TourSide side;
}

class TourTip {
  const TourTip({
    required this.target,
    required this.title,
    required this.visual,
    this.sidebarSpot,
    this.bottomBarSpot,
    this.line,
    this.replayLine,
    this.lineInBottomBarOnly = false,
  });

  final TourTarget? target;
  final String title;
  final TourVisual visual;
  final TourSpot? sidebarSpot;
  final TourSpot? bottomBarSpot;
  final String? line;
  final String? replayLine;
  final bool lineInBottomBarOnly;

  TourSpot? spotFor(ShellLayout layout) {
    if (target == null) {
      return null;
    }
    return switch (layout) {
      ShellLayout.sidebar => sidebarSpot,
      ShellLayout.bottomBar => bottomBarSpot,
    };
  }

  String? lineFor(ShellLayout layout, {required bool replay}) {
    if (lineInBottomBarOnly && layout == ShellLayout.sidebar) {
      return null;
    }
    return replay ? replayLine ?? line : line;
  }
}

const List<TourTip> tourTips = <TourTip>[
  TourTip(
    target: TourTarget.nav,
    title: 'Four pages, one journal',
    visual: TourVisual.pages,
    sidebarSpot: TourSpot(padding: 7, radius: 16, side: TourSide.right),
    bottomBarSpot: TourSpot(padding: 5, radius: 32, side: TourSide.above),
  ),
  TourTip(
    target: TourTarget.mood,
    title: 'Plant a bloom each day',
    visual: TourVisual.moods,
    sidebarSpot: TourSpot(padding: 6, radius: 21, side: TourSide.below),
    bottomBarSpot: TourSpot(padding: 5, radius: 18, side: TourSide.below),
    line: 'One mood per day · 10 to choose from',
  ),
  TourTip(
    target: TourTarget.capture,
    title: 'Capture a moment',
    visual: TourVisual.capture,
    sidebarSpot: TourSpot(padding: 8, radius: 18, side: TourSide.left),
    bottomBarSpot: TourSpot(padding: 5, radius: 40, side: TourSide.above),
    line: 'Tap + from any page.',
    lineInBottomBarOnly: true,
  ),
  TourTip(
    target: null,
    title: 'What a note can hold',
    visual: TourVisual.noteContent,
  ),
  TourTip(
    target: TourTarget.calendar,
    title: 'Past days stay open',
    visual: TourVisual.week,
    sidebarSpot: TourSpot(padding: 5, radius: 15, side: TourSide.right),
    bottomBarSpot: TourSpot(padding: 5, radius: 20, side: TourSide.above),
    line: 'Open any day in Calendar to add or edit.',
  ),
  TourTip(
    target: TourTarget.settings,
    title: 'Settings live here',
    visual: TourVisual.settings,
    sidebarSpot: TourSpot(padding: 6, radius: 12, side: TourSide.right),
    bottomBarSpot: TourSpot(padding: 5, radius: 14, side: TourSide.below),
    line: 'We’ll set these up next.',
    replayLine: 'Change these anytime.',
  ),
];

const Key tourWorksInNotesKey = ValueKey<String>('tour-works-in-notes');
const Key tourNotSupportedKey = ValueKey<String>('tour-not-supported');

const String tourWorksInNotesHeading = 'works in notes';
const String tourNotSupportedHeading = 'not supported';

const List<({String code, String label})> tourNoteFeatures =
    <({String code, String label})>[
      (code: '#', label: 'Headings'),
      (code: '-', label: 'Lists'),
      (code: '1.', label: 'Steps'),
      (code: '[ ]', label: 'To-dos'),
      (code: '>', label: 'Quotes'),
      (code: 'B I', label: 'Styles'),
      (code: '|', label: 'Tables'),
      (code: '```', label: 'Code blocks'),
      (code: '+', label: 'Photos'),
    ];

const List<String> tourUnsupportedNoteFeatures = <String>[
  'Files & PDFs',
  'Editing voice or video',
];

const List<Mood> tourMoods = <Mood>[
  Mood.happy,
  Mood.calm,
  Mood.tired,
  Mood.sad,
  Mood.angry,
];

const List<Mood> tourWeekBlooms = <Mood>[Mood.warm, Mood.calm, Mood.happy];

const String tourWeekTodayLabel = 'Today';
const String tourWeekOpenCaption = '← open & edit';
const String tourWeekClosedCaption = 'closed →';

const Color _tileBorder = Color(0x474A3B2E);
const Color _dashedChipBorder = Color(0x524A3B2E);
const double _futureOpacity = 0.6;
const double _dashedStroke = 1.5;
const double _headingTracking = 0.855;

const TextStyle _tileLabelStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: Palette.ink,
);

const TextStyle _tileCaptionStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 10,
  fontWeight: FontWeight.w400,
  height: 1.3,
  color: Palette.muted,
);

const TextStyle _headingStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 9.5,
  fontWeight: FontWeight.w600,
  letterSpacing: _headingTracking,
  color: Palette.sage,
);

const TextStyle _codeStyle = TextStyle(
  fontFamily: TypographyTokens.mono,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: Palette.coral,
);

const TextStyle _chipLabelStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: Palette.ink,
);

const TextStyle _weekLabelStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 9,
  fontWeight: FontWeight.w600,
  color: Palette.mutedDeep,
);

const TextStyle _weekCaptionStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 10,
  fontWeight: FontWeight.w600,
  color: Palette.sage,
);

class TourTipVisual extends StatelessWidget {
  const TourTipVisual({super.key, required this.visual, required this.layout});

  final TourVisual visual;
  final ShellLayout layout;

  bool get _sidebar => layout == ShellLayout.sidebar;

  @override
  Widget build(BuildContext context) {
    return switch (visual) {
      TourVisual.pages => _tiles(<Widget>[
        _tile(_nav(NavGlyph.home), 'Today', 'this day'),
        _tile(_nav(NavGlyph.calendar), 'Calendar', 'past days'),
        _tile(_nav(NavGlyph.garden), 'Garden', 'your year'),
        _tile(_nav(NavGlyph.search), 'Search', 'find anything'),
      ]),
      TourVisual.moods => _tiles(<Widget>[
        for (final Mood mood in tourMoods)
          _tile(
            FlowerBloom.forMood(mood, size: _sidebar ? 30 : 26),
            mood.label,
            null,
          ),
      ]),
      TourVisual.capture => _tiles(<Widget>[
        _tile(_capture(CaptureGlyph.pencil), 'Write', 'words + photos'),
        _tile(_capture(CaptureGlyph.mic), 'Voice', 'speak it'),
        _tile(_capture(CaptureGlyph.video), 'Video', 'film it'),
      ]),
      TourVisual.noteContent => _NoteContent(sidebar: _sidebar),
      TourVisual.week => _WeekStrip(sidebar: _sidebar),
      TourVisual.settings => _tiles(<Widget>[
        _tile(_glyph(_TourGlyph.bell), 'Reminders', null),
        _tile(_nav(NavGlyph.calendar), 'Week start', null),
        _tile(_glyph(_TourGlyph.lock), 'Storage', null),
      ]),
    };
  }

  double get _glyphSize => _sidebar ? 20 : 18;

  Widget _nav(NavGlyph glyph) {
    return NavIcon(glyph: glyph, color: Palette.ink, size: _glyphSize);
  }

  Widget _capture(CaptureGlyph glyph) {
    return CaptureIcon(glyph: glyph, color: Palette.ink, size: _glyphSize);
  }

  Widget _glyph(_TourGlyph glyph) {
    return _TourGlyphIcon(glyph: glyph, color: Palette.ink, size: _glyphSize);
  }

  Widget _tile(Widget art, String label, String? caption) {
    return _TourTile(
      art: art,
      label: label,
      caption: caption,
      sidebar: _sidebar,
    );
  }

  Widget _tiles(List<Widget> tiles) {
    final double gap = _sidebar ? 8 : 5;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int index = 0; index < tiles.length; index++) ...<Widget>[
              if (index > 0) SizedBox(width: gap),
              Expanded(child: tiles[index]),
            ],
          ],
        ),
      ),
    );
  }
}

class _TourTile extends StatelessWidget {
  const _TourTile({
    required this.art,
    required this.label,
    required this.caption,
    required this.sidebar,
  });

  final Widget art;
  final String label;
  final String? caption;
  final bool sidebar;

  @override
  Widget build(BuildContext context) {
    final String? line = caption;
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.cardWarm,
          border: Border.all(color: _tileBorder, width: Shapes.outlineWidth),
          borderRadius: BorderRadius.all(
            Radius.circular(sidebar ? Shapes.radiusControl : Shapes.radiusSm),
          ),
        ),
        child: Padding(
          padding: sidebar
              ? const EdgeInsets.fromLTRB(4, 10, 4, 9)
              : const EdgeInsets.fromLTRB(2, 9, 2, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ExcludeSemantics(child: art),
              SizedBox(height: sidebar ? 5 : 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: sidebar
                    ? _tileLabelStyle
                    : _tileLabelStyle.copyWith(fontSize: 11),
              ),
              if (line != null)
                Text(
                  line,
                  textAlign: TextAlign.center,
                  style: sidebar
                      ? _tileCaptionStyle
                      : _tileCaptionStyle.copyWith(fontSize: 9.5, height: 1.25),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteContent extends StatelessWidget {
  const _NoteContent({required this.sidebar});

  final bool sidebar;

  @override
  Widget build(BuildContext context) {
    final double gap = sidebar ? 6 : 5;
    return Padding(
      padding: EdgeInsets.only(top: sidebar ? 14 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _section(
            key: tourWorksInNotesKey,
            heading: tourWorksInNotesHeading,
            headingColor: Palette.sage,
            chips: <Widget>[
              for (final ({String code, String label}) feature
                  in tourNoteFeatures)
                _FeatureChip(
                  code: feature.code,
                  label: feature.label,
                  sidebar: sidebar,
                ),
            ],
            gap: gap,
          ),
          SizedBox(height: sidebar ? 12 : 11),
          _section(
            key: tourNotSupportedKey,
            heading: tourNotSupportedHeading,
            headingColor: Palette.muted,
            chips: <Widget>[
              for (final String label in tourUnsupportedNoteFeatures)
                _UnsupportedChip(label: label, sidebar: sidebar),
            ],
            gap: gap,
          ),
        ],
      ),
    );
  }

  Widget _section({
    required Key key,
    required String heading,
    required Color headingColor,
    required List<Widget> chips,
    required double gap,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            heading.toUpperCase(),
            semanticsLabel: heading,
            style: _headingStyle.copyWith(color: headingColor),
          ),
        ),
        SizedBox(height: sidebar ? 7 : 6),
        Wrap(spacing: gap, runSpacing: gap, children: chips),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.code,
    required this.label,
    required this.sidebar,
  });

  final String code;
  final String label;
  final bool sidebar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.cardWarm,
        border: Border.fromBorderSide(
          BorderSide(color: Palette.ink30, width: Shapes.outlineWidth),
        ),
        borderRadius: BorderRadius.all(Radius.circular(Shapes.radiusThumb)),
      ),
      child: Padding(
        padding: sidebar
            ? const EdgeInsets.symmetric(horizontal: 9, vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExcludeSemantics(
              child: Text(
                code,
                style: sidebar
                    ? _codeStyle
                    : _codeStyle.copyWith(fontSize: 10.5),
              ),
            ),
            SizedBox(width: sidebar ? 6 : 5),
            Text(
              label,
              style: sidebar
                  ? _chipLabelStyle
                  : _chipLabelStyle.copyWith(fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsupportedChip extends StatelessWidget {
  const _UnsupportedChip({required this.label, required this.sidebar});

  final String label;
  final bool sidebar;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedOutlinePainter(
        color: _dashedChipBorder,
        radius: Shapes.radiusThumb,
      ),
      child: Padding(
        padding: sidebar
            ? const EdgeInsets.symmetric(horizontal: 9, vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExcludeSemantics(
              child: _TourGlyphIcon(
                glyph: _TourGlyph.cross,
                color: Palette.mutedDeep,
                size: sidebar ? 9 : 8,
              ),
            ),
            SizedBox(width: sidebar ? 6 : 5),
            Text(
              label,
              style: _chipLabelStyle.copyWith(
                fontSize: sidebar ? 12 : 11.5,
                color: Palette.mutedDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends ConsumerWidget {
  const _WeekStrip({required this.sidebar});

  final bool sidebar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime today = ref.watch(todayClockProvider)();
    final double gap = sidebar ? 5 : 4;
    final List<Widget> cells = <Widget>[
      for (int index = 0; index < tourWeekBlooms.length; index++)
        _WeekCell.past(
          label: shortWeekdayLabel(_offsetDay(today, index - 3)),
          mood: tourWeekBlooms[index],
          sidebar: sidebar,
        ),
      _WeekCell.today(sidebar: sidebar),
      for (int offset = 1; offset <= 3; offset++)
        _WeekCell.future(
          label: shortWeekdayLabel(_offsetDay(today, offset)),
          sidebar: sidebar,
        ),
    ];
    return Padding(
      padding: EdgeInsets.only(top: sidebar ? 14 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int index = 0; index < cells.length; index++) ...<Widget>[
                  if (index > 0) SizedBox(width: gap),
                  Expanded(child: cells[index]),
                ],
              ],
            ),
          ),
          SizedBox(height: sidebar ? 7 : 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(tourWeekOpenCaption, style: _weekCaptionStyle),
              Text(
                tourWeekClosedCaption,
                style: _weekCaptionStyle.copyWith(color: Palette.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static DateTime _offsetDay(DateTime today, int days) {
    return DateTime(today.year, today.month, today.day + days);
  }
}

enum _WeekCellKind { past, today, future }

class _WeekCell extends StatelessWidget {
  const _WeekCell.past({
    required this.label,
    required Mood this.mood,
    required this.sidebar,
  }) : kind = _WeekCellKind.past;

  const _WeekCell.today({required this.sidebar})
    : kind = _WeekCellKind.today,
      label = tourWeekTodayLabel,
      mood = null;

  const _WeekCell.future({required this.label, required this.sidebar})
    : kind = _WeekCellKind.future,
      mood = null;

  final _WeekCellKind kind;
  final String label;
  final Mood? mood;
  final bool sidebar;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: sidebar
          ? const EdgeInsets.fromLTRB(0, 7, 0, 5)
          : const EdgeInsets.fromLTRB(0, 6, 0, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox.square(
            dimension: sidebar ? 24 : 20,
            child: Center(child: ExcludeSemantics(child: _art())),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
            style: _weekLabelStyle.copyWith(
              fontSize: sidebar ? 9 : 8.5,
              color: kind == _WeekCellKind.today
                  ? Palette.coral
                  : Palette.mutedDeep,
            ),
          ),
        ],
      ),
    );
    return switch (kind) {
      _WeekCellKind.past => DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.cardWarm,
          border: Border.all(color: _tileBorder, width: Shapes.outlineWidth),
          borderRadius: const BorderRadius.all(
            Radius.circular(Shapes.radiusCell),
          ),
        ),
        child: content,
      ),
      _WeekCellKind.today => DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.cardLight,
          border: Border.all(color: Palette.coral, width: Shapes.outlineWidth),
          borderRadius: const BorderRadius.all(
            Radius.circular(Shapes.radiusCell),
          ),
        ),
        child: content,
      ),
      _WeekCellKind.future => Opacity(
        opacity: _futureOpacity,
        child: CustomPaint(
          painter: const _DashedOutlinePainter(
            color: Palette.ink25,
            radius: Shapes.radiusCell,
          ),
          child: content,
        ),
      ),
    };
  }

  Widget _art() {
    final Mood? bloom = mood;
    if (bloom != null) {
      return FlowerBloom.forMood(bloom, size: sidebar ? 24 : 20);
    }
    if (kind == _WeekCellKind.today) {
      final double size = sidebar ? 20 : 17;
      return SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DashedOutlinePainter(color: Palette.coral, radius: size),
        ),
      );
    }
    return _TourGlyphIcon(
      glyph: _TourGlyph.lock,
      color: Palette.muted,
      size: sidebar ? 14 : 12,
      strokeWidth: 2,
    );
  }
}

class _DashedOutlinePainter extends CustomPainter {
  const _DashedOutlinePainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = (Offset.zero & size).deflate(_dashedStroke / 2);
    final double corner = radius.clamp(0, bounds.shortestSide / 2);
    final Path outline = Path()
      ..addRRect(RRect.fromRectAndRadius(bounds, Radius.circular(corner)));
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _dashedStroke
      ..isAntiAlias = true;
    for (final ui.PathMetric metric in outline.computeMetrics()) {
      for (
        double start = 0;
        start < metric.length;
        start += Shapes.dashLength + Shapes.dashGap
      ) {
        canvas.drawPath(
          metric.extractPath(start, start + Shapes.dashLength),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutlinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

enum _TourGlyph { bell, lock, cross }

class _TourGlyphIcon extends StatelessWidget {
  const _TourGlyphIcon({
    required this.glyph,
    required this.color,
    required this.size,
    this.strokeWidth = 1.8,
  });

  final _TourGlyph glyph;
  final Color color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _TourGlyphPainter(
          glyph: glyph,
          color: color,
          strokeWidth: strokeWidth,
        ),
        size: Size.square(size),
      ),
    );
  }
}

class _TourGlyphPainter extends CustomPainter {
  const _TourGlyphPainter({
    required this.glyph,
    required this.color,
    required this.strokeWidth,
  });

  final _TourGlyph glyph;
  final Color color;
  final double strokeWidth;

  static const double _viewBox = 24;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / _viewBox);
    canvas.drawPath(
      switch (glyph) {
        _TourGlyph.bell => _bell(),
        _TourGlyph.lock => _lock(),
        _TourGlyph.cross => _cross(),
      },
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = glyph == _TourGlyph.cross ? 3 : strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  Path _bell() => Path()
    ..moveTo(6, 16)
    ..lineTo(6, 11)
    ..arcToPoint(const Offset(18, 11), radius: const Radius.circular(6))
    ..lineTo(18, 16)
    ..lineTo(19.5, 18)
    ..lineTo(4.5, 18)
    ..close()
    ..moveTo(10, 20.5)
    ..arcToPoint(
      const Offset(14, 20.5),
      radius: const Radius.circular(2),
      clockwise: false,
    );

  Path _lock() => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 11, 14, 9),
        const Radius.circular(2),
      ),
    )
    ..moveTo(8, 11)
    ..lineTo(8, 8)
    ..arcToPoint(const Offset(16, 8), radius: const Radius.circular(4))
    ..lineTo(16, 11);

  Path _cross() => Path()
    ..moveTo(6, 6)
    ..lineTo(18, 18)
    ..moveTo(18, 6)
    ..lineTo(6, 18);

  @override
  bool shouldRepaint(_TourGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
