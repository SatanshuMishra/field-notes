import 'dart:math' as math;

import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/empty_state.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/flame_icon.dart';
import 'package:field_notes/design/icons/nav_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/dashed_divider.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';
import 'package:field_notes/features/onboarding/onboarding_frame.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

const String _kicker = 'one last thing';
const String _title = "Here's where everything lives.";
const String _subtitle = 'Tap a row to see it in the app.';
const String _headerTitle = 'Today';

const int _streakCount = 4;

Key tourLineKey(int number) => ValueKey<String>('tour-line-$number');
Key tourBadgeKey(int number) => ValueKey<String>('tour-badge-$number');
Key tourTargetKey(int number) => ValueKey<String>('tour-target-$number');

typedef _Place = ({String title, String line});

const List<_Place> _sidebarPlaces = <_Place>[
  (
    title: 'Today',
    line:
        'Your day: its mood, its notes, voice and video. New logs start here.',
  ),
  (
    title: 'Calendar',
    line: "Every day you've kept. Tap one to revisit it, or add to it.",
  ),
  (title: 'Meadow', line: 'Your year in bloom. Each flower is a day.'),
  (title: 'Search', line: 'Find any memory by a word, a mood or a date.'),
  (
    title: 'Streak',
    line: 'Days in a row, in the sidebar. Miss one and it waits for you.',
  ),
  (
    title: 'Settings',
    line: 'The gear at the foot of the sidebar: theme, reminders, your week.',
  ),
];

enum _Mark { home, calendar, add, meadow, search, streak, gear }

typedef _PhonePlace = ({String title, String line, _Mark mark});

const List<_PhonePlace> _bottomBarPlaces = <_PhonePlace>[
  (title: 'Today', line: 'Your day, its mood and its logs.', mark: _Mark.home),
  (
    title: 'Calendar',
    line: 'A month of flowers. Swipe to change month.',
    mark: _Mark.calendar,
  ),
  (
    title: 'New log',
    line: 'Write, speak, film or add a photo.',
    mark: _Mark.add,
  ),
  (
    title: 'Meadow',
    line: 'Your year in bloom, full screen.',
    mark: _Mark.meadow,
  ),
  (
    title: 'Search',
    line: 'The field sits at the bottom, by your thumb.',
    mark: _Mark.search,
  ),
  (
    title: 'Streak',
    line: 'Days in a row, top right of every page.',
    mark: _Mark.streak,
  ),
  (
    title: 'Settings',
    line: 'The gear beside it: theme, reminders, week.',
    mark: _Mark.gear,
  ),
];

typedef _NavPlace = ({String label, NavGlyph glyph});

const List<_NavPlace> _sidebarNav = <_NavPlace>[
  (label: 'Today', glyph: NavGlyph.home),
  (label: 'Calendar', glyph: NavGlyph.calendar),
  (label: 'Meadow', glyph: NavGlyph.garden),
  (label: 'Search', glyph: NavGlyph.search),
];

const int _sidebarStreakNumber = 5;
const int _sidebarGearNumber = 6;
const int _bottomBarFirstNumber = 1;
const int _bottomBarAddNumber = 3;
const int _bottomBarSlots = 5;
const int _bottomBarStreakNumber = 6;
const int _bottomBarGearNumber = 7;

const Map<int, ShellDestination> _bottomBarSelection = <int, ShellDestination>{
  1: ShellDestination.today,
  2: ShellDestination.calendar,
  4: ShellDestination.garden,
  5: ShellDestination.search,
};

const Color _miniatureDrop = Color(0x66281C12);
const Color _streakFlame = Color(0xFFE0863C);
const Color _ring = Color.fromRGBO(199, 106, 84, 0.25);

const double _outline = 1.5;
const double _badgeSidebar = 20;
const double _badgeBottomBar = 18;
const double _badgeFontSidebar = 11;
const double _badgeFontBottomBar = 10;

const double _sidebarHeadingSide = 40;
const double _sidebarMargin = 40;
const double _sidebarBodyGap = 36;
const double _sidebarBottom = 72;
const double _sidebarColumnsGap = 40;
const double _sidebarListWidth = 340;
const double _sidebarLineGap = 6;

const double _sidebarLineMinHeight = 48;
const BorderRadius _sidebarLineRadius = BorderRadius.all(Radius.circular(12));
const EdgeInsets _sidebarLinePadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 9,
);
const double _sidebarLineInnerGap = 12;
const double _sidebarLineTextGap = 2;

const double _bottomBarHeadingSide = 20;
const double _bottomBarSubtitleGap = 4;
const double _bottomBarSectionGap = 10;
const double _bottomBarBottomGap = 10;
const double _bottomBarSide = 12;

const double _headerHeight = 52;
const EdgeInsets _headerPadding = EdgeInsets.fromLTRB(14, 0, 6, 0);
const BorderRadius _headerRadius = BorderRadius.all(Radius.circular(14));
const double _headerTrailingGap = 4;
const double _headerGear = 36;
const double _headerGearGlyph = 20;
const double _ringSpread = 4;

const double _rowGap = 2;
const double _rowMinHeight = 50;
const EdgeInsets _rowPadding = EdgeInsets.symmetric(
  horizontal: 10,
  vertical: 5,
);
const BorderRadius _rowRadius = BorderRadius.all(Radius.circular(14));
const double _rowIconBox = 36;
const double _rowIconGlyph = 17;
const double _rowInnerGap = 12;

const double _captureExtent = 46;
const double _captureRing = 4;

const double _miniatureWidth = 540;
const double _miniatureHeight = 400;
const BorderRadius _miniatureRadius = BorderRadius.all(Radius.circular(16));
const BorderRadius _miniatureInnerRadius = BorderRadius.all(
  Radius.circular(16 - _outline),
);
const Offset _miniatureHardOffset = Offset(4, 4);
const Offset _miniatureDropOffset = Offset(0, 30);
const double _miniatureDropBlur = 60;
const double _miniatureDropSpread = -30;
const double _miniatureSideWidth = 177;
const double _miniatureSideRule = 1;
const EdgeInsets _miniatureSidePadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 16,
);
const double _wordmarkFlower = 24;
const double _wordmarkGap = 7;
const double _wordmarkBelow = 18;
const double _navRowGap = 6;
const EdgeInsets _navRowPadding = EdgeInsets.symmetric(
  horizontal: 10,
  vertical: 8,
);
const BorderRadius _navRowRadius = BorderRadius.all(Radius.circular(10));
const double _navRowIcon = 15;
const double _navRowInnerGap = 9;
const double _streakBadgeInset = 10;
const double _streakGearGap = 10;
const double _gearBox = 30;
const double _gearBoxGlyph = 14;
const BorderRadius _gearBoxRadius = BorderRadius.all(Radius.circular(8));
const double _gearRowGap = 8;
const EdgeInsets _miniatureContentPadding = EdgeInsets.symmetric(
  horizontal: 22,
  vertical: 20,
);
const double _miniatureContentGap = 12;
const double _miniatureCardHeight = 58;
const BorderRadius _miniatureCardRadius = BorderRadius.all(Radius.circular(12));
const double _miniatureCardFlower = 30;
const double _miniatureCardGap = 10;
const double _miniatureCardLinesGap = 6;
const double _miniatureBoxHeight = 44;
const double _miniatureBoxRadius = 10;

const Duration _headingRise = Duration(milliseconds: 500);
const Duration _bodyRise = Duration(milliseconds: 600);
const Duration _miniatureDelay = Duration(milliseconds: 150);
const Duration _sidebarListDelay = Duration(milliseconds: 300);
const Duration _headerDelay = Duration(milliseconds: 150);
const Duration _bottomBarListDelay = Duration(milliseconds: 200);
const Duration _navBarDelay = Duration(milliseconds: 400);
const Duration _highlightFade = Duration(milliseconds: 200);

const double _riseTravel = 14;
const double _liftTravel = 40;

Duration _fade(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : _highlightFade;

class TourChapter extends StatefulWidget {
  const TourChapter({super.key, required this.layout});

  final ShellLayout layout;

  @override
  State<TourChapter> createState() => _TourChapterState();
}

class _TourChapterState extends State<TourChapter> {
  late int? _highlighted = switch (widget.layout) {
    ShellLayout.sidebar => null,
    ShellLayout.bottomBar => _bottomBarFirstNumber,
  };

  void _highlight(int number) {
    if (_highlighted != number) {
      setState(() => _highlighted = number);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: switch (widget.layout) {
        ShellLayout.sidebar => _SidebarTour(
          highlighted: _highlighted,
          onHighlight: _highlight,
        ),
        ShellLayout.bottomBar => _BottomBarTour(
          highlighted: _highlighted,
          onHighlight: _highlight,
        ),
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.layout});

  final ShellLayout layout;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool sidebar = layout == ShellLayout.sidebar;
    final TextAlign align = sidebar ? TextAlign.center : TextAlign.start;
    return Padding(
      padding: sidebar
          ? const EdgeInsets.fromLTRB(
              _sidebarHeadingSide,
              onboardingTitleTop,
              _sidebarHeadingSide,
              0,
            )
          : const EdgeInsets.symmetric(horizontal: _bottomBarHeadingSide),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: sidebar
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _kicker,
            textAlign: align,
            style: TextStyle(
              fontFamily: TypographyTokens.accent,
              fontSize: sidebar ? 21 : 18,
              fontWeight: FontWeight.w600,
              color: colors.accentInk,
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              _title,
              textAlign: align,
              style: TextStyle(
                fontFamily: TypographyTokens.serif,
                fontSize: sidebar ? 44 : 28,
                fontWeight: FontWeight.w500,
                height: sidebar ? 1.05 : 1.08,
                color: colors.ink,
              ),
            ),
          ),
          if (!sidebar) ...<Widget>[
            const SizedBox(height: _bottomBarSubtitleGap),
            Text(
              _subtitle,
              style: TextStyle(
                fontFamily: TypographyTokens.sans,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: colors.mutedDeep,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarTour extends StatelessWidget {
  const _SidebarTour({required this.highlighted, required this.onHighlight});

  final int? highlighted;
  final ValueChanged<int> onHighlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const _Rise(
          duration: _headingRise,
          child: _Heading(layout: ShellLayout.sidebar),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _sidebarMargin,
              _sidebarBodyGap,
              _sidebarMargin,
              _sidebarBottom,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Rise(
                      duration: _bodyRise,
                      delay: _miniatureDelay,
                      child: _SidebarMiniature(highlighted: highlighted),
                    ),
                    const SizedBox(width: _sidebarColumnsGap),
                    _Rise(
                      duration: _bodyRise,
                      delay: _sidebarListDelay,
                      child: SizedBox(
                        width: _sidebarListWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (final (int index, _Place place)
                                in _sidebarPlaces.indexed) ...<Widget>[
                              if (index > 0)
                                const SizedBox(height: _sidebarLineGap),
                              _SidebarLine(
                                key: tourLineKey(index + 1),
                                number: index + 1,
                                place: place,
                                highlighted: highlighted == index + 1,
                                onHighlight: () => onHighlight(index + 1),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomBarTour extends StatelessWidget {
  const _BottomBarTour({required this.highlighted, required this.onHighlight});

  final int? highlighted;
  final ValueChanged<int> onHighlight;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets insets = MediaQuery.paddingOf(context);
    final double gesture = math.max(
      insets.bottom,
      MediaQuery.viewPaddingOf(context).bottom,
    );
    return Padding(
      padding: EdgeInsets.only(
        top: insets.top + onboardingPhoneTitleTop,
        bottom: gesture + onboardingControlBarReserve + _bottomBarBottomGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Rise(
            duration: _headingRise,
            child: _Heading(layout: ShellLayout.bottomBar),
          ),
          const SizedBox(height: _bottomBarSectionGap),
          _Rise(
            duration: _bodyRise,
            delay: _headerDelay,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _bottomBarSide),
              child: _HeaderReplica(highlighted: highlighted),
            ),
          ),
          const SizedBox(height: _bottomBarSectionGap),
          Expanded(
            child: _Rise(
              duration: _bodyRise,
              delay: _bottomBarListDelay,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints area) {
                  final double width = math.max(
                    0.0,
                    area.maxWidth - 2 * _bottomBarSide,
                  );
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: width,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (final (int index, _PhonePlace place)
                                in _bottomBarPlaces.indexed) ...<Widget>[
                              if (index > 0) const SizedBox(height: _rowGap),
                              _PhoneLine(
                                key: tourLineKey(index + 1),
                                place: place,
                                highlighted: highlighted == index + 1,
                                onHighlight: () => onHighlight(index + 1),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: _bottomBarSectionGap),
          _Rise(
            duration: _bodyRise,
            delay: _navBarDelay,
            travel: _liftTravel,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _bottomBarSide),
              child: _BarReplica(highlighted: highlighted),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineTarget extends StatelessWidget {
  const _LineTarget({
    required this.label,
    required this.highlighted,
    required this.onHighlight,
    required this.borderRadius,
    required this.child,
  });

  final String label;
  final bool highlighted;
  final VoidCallback onHighlight;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      selected: highlighted,
      label: label,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: (bool focused) {
          if (focused) {
            onHighlight();
          }
        },
        child: MouseRegion(
          onEnter: (PointerEnterEvent event) => onHighlight(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: onHighlight,
            child: FocusRing(
              onPressed: null,
              borderRadius: borderRadius,
              child: ExcludeSemantics(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _lineDecoration(
  FieldNotesColors colors,
  BorderRadius radius, {
  required bool highlighted,
}) => BoxDecoration(
  color: highlighted ? colors.cardLight : colors.cardLight.withAlpha(0),
  borderRadius: radius,
  border: Border.all(
    color: highlighted ? colors.ink30 : colors.ink30.withAlpha(0),
    width: _outline,
  ),
);

class _SidebarLine extends StatelessWidget {
  const _SidebarLine({
    super.key,
    required this.number,
    required this.place,
    required this.highlighted,
    required this.onHighlight,
  });

  final int number;
  final _Place place;
  final bool highlighted;
  final VoidCallback onHighlight;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return _LineTarget(
      label: '$number, ${place.title}, ${place.line}',
      highlighted: highlighted,
      onHighlight: onHighlight,
      borderRadius: _sidebarLineRadius,
      child: AnimatedContainer(
        duration: _fade(context),
        constraints: const BoxConstraints(minHeight: _sidebarLineMinHeight),
        padding: _sidebarLinePadding,
        decoration: _lineDecoration(
          colors,
          _sidebarLineRadius,
          highlighted: highlighted,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TourBadge(
              number: number,
              highlighted: highlighted,
              inMiniature: false,
              layout: ShellLayout.sidebar,
            ),
            const SizedBox(width: _sidebarLineInnerGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    place.title,
                    style: TextStyle(
                      fontFamily: TypographyTokens.serif,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: _sidebarLineTextGap),
                  Text(
                    place.line,
                    style: TextStyle(
                      fontFamily: TypographyTokens.sans,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      color: colors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneLine extends StatelessWidget {
  const _PhoneLine({
    super.key,
    required this.place,
    required this.highlighted,
    required this.onHighlight,
  });

  final _PhonePlace place;
  final bool highlighted;
  final VoidCallback onHighlight;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return _LineTarget(
      label: '${place.title}, ${place.line}',
      highlighted: highlighted,
      onHighlight: onHighlight,
      borderRadius: _rowRadius,
      child: AnimatedContainer(
        duration: _fade(context),
        constraints: const BoxConstraints(minHeight: _rowMinHeight),
        padding: _rowPadding,
        decoration: _lineDecoration(
          colors,
          _rowRadius,
          highlighted: highlighted,
        ),
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: _fade(context),
              width: _rowIconBox,
              height: _rowIconBox,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: highlighted ? Palette.coral : colors.cardWarm,
                shape: BoxShape.circle,
                border: Border.all(color: colors.line, width: _outline),
              ),
              child: _PlaceMark(mark: place.mark, highlighted: highlighted),
            ),
            const SizedBox(width: _rowInnerGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    place.title,
                    style: TextStyle(
                      fontFamily: TypographyTokens.serif,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                      color: colors.ink,
                    ),
                  ),
                  Text(
                    place.line,
                    style: TextStyle(
                      fontFamily: TypographyTokens.sans,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                      color: colors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceMark extends StatelessWidget {
  const _PlaceMark({required this.mark, required this.highlighted});

  final _Mark mark;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final Color ink = highlighted ? Palette.onAccent : context.colors.ink;
    NavIcon nav(NavGlyph glyph) =>
        NavIcon(glyph: glyph, color: ink, size: _rowIconGlyph);
    return switch (mark) {
      _Mark.home => nav(NavGlyph.home),
      _Mark.calendar => nav(NavGlyph.calendar),
      _Mark.add => nav(NavGlyph.plus),
      _Mark.meadow => nav(NavGlyph.garden),
      _Mark.search => nav(NavGlyph.search),
      _Mark.streak => FlameIcon(
        color: highlighted ? Palette.onAccent : _streakFlame,
        size: _rowIconGlyph,
      ),
      _Mark.gear => Icon(
        Icons.settings_outlined,
        size: _rowIconGlyph,
        color: ink,
      ),
    };
  }
}

class _HeaderReplica extends StatelessWidget {
  const _HeaderReplica({required this.highlighted});

  final int? highlighted;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool streakOn = highlighted == _bottomBarStreakNumber;
    final bool gearOn = highlighted == _bottomBarGearNumber;
    return ExcludeSemantics(
      child: Container(
        height: _headerHeight,
        padding: _headerPadding,
        decoration: BoxDecoration(
          color: colors.panelTop,
          borderRadius: _headerRadius,
          border: Border.all(color: colors.ink20, width: _outline),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _headerTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: TypographyTokens.serif,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: colors.ink,
                ),
              ),
            ),
            MapPlaceHighlight(
              key: tourTargetKey(_bottomBarStreakNumber),
              highlighted: streakOn,
              child: StreakPill(
                count: _streakCount,
                numberOnly: true,
                highlighted: streakOn,
              ),
            ),
            const SizedBox(width: _headerTrailingGap),
            MapPlaceHighlight(
              key: tourTargetKey(_bottomBarGearNumber),
              highlighted: gearOn,
              child: AnimatedContainer(
                duration: _fade(context),
                width: _headerGear,
                height: _headerGear,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gearOn ? Palette.coral : Palette.coral.withAlpha(0),
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: gearOn ? _ring : _ring.withAlpha(0),
                      spreadRadius: _ringSpread,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.settings_outlined,
                  size: _headerGearGlyph,
                  color: gearOn ? Palette.onAccent : colors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarReplica extends StatelessWidget {
  const _BarReplica({required this.highlighted});

  final int? highlighted;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            removeRight: true,
            removeBottom: true,
            child: PhoneBottomBar(
              destinations: ShellDestination.primary,
              selected: _bottomBarSelection[highlighted],
            ),
          ),
          Positioned.fill(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int number = 1; number <= _bottomBarSlots; number++)
                  Expanded(
                    child: MapPlaceHighlight(
                      key: tourTargetKey(number),
                      highlighted: highlighted == number,
                      child: number == _bottomBarAddNumber
                          ? Center(
                              child: _CaptureRing(shown: highlighted == number),
                            )
                          : const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureRing extends StatelessWidget {
  const _CaptureRing({required this.shown});

  final bool shown;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: _fade(context),
        width: _captureExtent + 2 * _captureRing,
        height: _captureExtent + 2 * _captureRing,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: shown ? Palette.coral30 : Palette.coral30.withAlpha(0),
            width: _captureRing,
          ),
        ),
      ),
    );
  }
}

class TourBadge extends StatelessWidget {
  const TourBadge({
    super.key,
    required this.number,
    required this.highlighted,
    required this.inMiniature,
    required this.layout,
  });

  final int number;
  final bool highlighted;
  final bool inMiniature;
  final ShellLayout layout;

  @override
  Widget build(BuildContext context) {
    final bool sidebar = layout == ShellLayout.sidebar;
    final double size = sidebar ? _badgeSidebar : _badgeBottomBar;
    final Color fill = switch ((inMiniature, highlighted)) {
      (true, false) || (false, true) => Palette.coral,
      (true, true) || (false, false) => context.colors.sage,
    };
    return AnimatedContainer(
      duration: _fade(context),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.line, width: _outline),
      ),
      child: Text(
        '$number',
        maxLines: 1,
        style: TextStyle(
          fontFamily: TypographyTokens.sans,
          fontSize: sidebar ? _badgeFontSidebar : _badgeFontBottomBar,
          fontWeight: FontWeight.w600,
          height: 1,
          color: Palette.onAccent,
        ),
      ),
    );
  }
}

class MapPlaceHighlight extends StatelessWidget {
  const MapPlaceHighlight({
    super.key,
    required this.highlighted,
    required this.child,
  });

  final bool highlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _SidebarMiniature extends StatelessWidget {
  const _SidebarMiniature({required this.highlighted});

  final int? highlighted;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: _miniatureWidth,
        height: _miniatureHeight,
        decoration: BoxDecoration(
          color: colors.panelTop,
          borderRadius: _miniatureRadius,
          border: Border.all(color: colors.line, width: _outline),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.shadowTint(0x2E),
              offset: _miniatureHardOffset,
            ),
            const BoxShadow(
              color: _miniatureDrop,
              offset: _miniatureDropOffset,
              blurRadius: _miniatureDropBlur,
              spreadRadius: _miniatureDropSpread,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: _miniatureInnerRadius,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: _miniatureSideWidth,
                child: _MiniatureSidebar(highlighted: highlighted),
              ),
              DashedDivider(
                axis: Axis.vertical,
                thickness: _miniatureSideRule,
                color: colors.ink25,
              ),
              const Expanded(child: _MiniatureContent()),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniatureSidebar extends StatelessWidget {
  const _MiniatureSidebar({required this.highlighted});

  final int? highlighted;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool streakOn = highlighted == _sidebarStreakNumber;
    final bool gearOn = highlighted == _sidebarGearNumber;
    return Padding(
      padding: _miniatureSidePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const FlowerBloom(kind: FlowerKind.peony, size: _wordmarkFlower),
              const SizedBox(width: _wordmarkGap),
              Text(
                'field\nnotes',
                style: TextStyle(
                  fontFamily: TypographyTokens.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 0.85,
                  color: colors.accentInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: _wordmarkBelow),
          for (final (int index, _NavPlace place)
              in _sidebarNav.indexed) ...<Widget>[
            if (index > 0) const SizedBox(height: _navRowGap),
            _MiniatureNavRow(
              number: index + 1,
              place: place,
              highlighted: highlighted == index + 1,
            ),
          ],
          const Spacer(),
          MapPlaceHighlight(
            key: tourTargetKey(_sidebarStreakNumber),
            highlighted: streakOn,
            child: Stack(
              children: <Widget>[
                StreakPill(
                  form: StreakPillForm.sidebar,
                  count: _streakCount,
                  highlighted: streakOn,
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: _streakBadgeInset,
                  child: Center(
                    child: TourBadge(
                      key: tourBadgeKey(_sidebarStreakNumber),
                      number: _sidebarStreakNumber,
                      highlighted: streakOn,
                      inMiniature: true,
                      layout: ShellLayout.sidebar,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _streakGearGap),
          Row(
            children: <Widget>[
              MapPlaceHighlight(
                key: tourTargetKey(_sidebarGearNumber),
                highlighted: gearOn,
                child: AnimatedContainer(
                  duration: _fade(context),
                  width: _gearBox,
                  height: _gearBox,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: gearOn ? Palette.coral : colors.cardLight,
                    borderRadius: _gearBoxRadius,
                    border: Border.all(color: colors.line, width: _outline),
                  ),
                  child: IconStickerGlyphIcon(
                    glyph: IconStickerGlyph.gear,
                    color: gearOn ? Palette.onAccent : colors.ink,
                    size: _gearBoxGlyph,
                  ),
                ),
              ),
              const SizedBox(width: _gearRowGap),
              TourBadge(
                key: tourBadgeKey(_sidebarGearNumber),
                number: _sidebarGearNumber,
                highlighted: gearOn,
                inMiniature: true,
                layout: ShellLayout.sidebar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniatureNavRow extends StatelessWidget {
  const _MiniatureNavRow({
    required this.number,
    required this.place,
    required this.highlighted,
  });

  final int number;
  final _NavPlace place;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final Color ink = highlighted ? Palette.onAccent : colors.ink;
    return MapPlaceHighlight(
      key: tourTargetKey(number),
      highlighted: highlighted,
      child: AnimatedContainer(
        duration: _fade(context),
        padding: _navRowPadding,
        decoration: BoxDecoration(
          color: highlighted ? Palette.coral : Palette.coral.withAlpha(0),
          borderRadius: _navRowRadius,
          border: Border.all(
            color: highlighted ? colors.line : colors.line.withAlpha(0),
            width: _outline,
          ),
        ),
        child: Row(
          children: <Widget>[
            NavIcon(glyph: place.glyph, color: ink, size: _navRowIcon),
            const SizedBox(width: _navRowInnerGap),
            Expanded(
              child: Text(
                place.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: TypographyTokens.sans,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(width: _navRowInnerGap),
            TourBadge(
              key: tourBadgeKey(number),
              number: number,
              highlighted: highlighted,
              inMiniature: true,
              layout: ShellLayout.sidebar,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniatureContent extends StatelessWidget {
  const _MiniatureContent();

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Padding(
      padding: _miniatureContentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PlaceholderBar(widthFactor: 0.46, height: 9, color: colors.ink35),
          const SizedBox(height: _miniatureContentGap),
          _PlaceholderBar(
            widthFactor: 0.7,
            height: 14,
            color: colors.ink.withAlpha(0x8C),
          ),
          const SizedBox(height: _miniatureContentGap),
          Container(
            height: _miniatureCardHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colors.cardWarm,
              borderRadius: _miniatureCardRadius,
              border: Border.all(color: colors.ink30, width: _outline),
            ),
            child: Row(
              children: <Widget>[
                const FlowerBloom(
                  kind: FlowerKind.peony,
                  size: _miniatureCardFlower,
                ),
                const SizedBox(width: _miniatureCardGap),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _PlaceholderBar(
                        widthFactor: 0.6,
                        height: 7,
                        color: colors.ink30,
                      ),
                      const SizedBox(height: _miniatureCardLinesGap),
                      _PlaceholderBar(
                        widthFactor: 0.38,
                        height: 6,
                        color: colors.ink18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _miniatureContentGap),
          Container(
            height: _miniatureBoxHeight,
            decoration: BoxDecoration(
              color: colors.cardBright,
              borderRadius: const BorderRadius.all(
                Radius.circular(_miniatureBoxRadius),
              ),
              border: Border.all(color: colors.ink30, width: _outline),
            ),
          ),
          const SizedBox(height: _miniatureContentGap),
          SizedBox(
            height: _miniatureBoxHeight,
            child: CustomPaint(
              painter: DashedBorderPainter(
                color: colors.ink30,
                radius: _miniatureBoxRadius,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderBar extends StatelessWidget {
  const _PlaceholderBar({
    required this.widthFactor,
    required this.height,
    required this.color,
  });

  final double widthFactor;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.all(Radius.circular(height < 9 ? 4 : 5)),
        ),
      ),
    );
  }
}

typedef _EntranceFrame = Widget Function(double progress, Widget child);

class _Entrance extends StatefulWidget {
  const _Entrance({
    required this.duration,
    required this.delay,
    required this.frame,
    required this.child,
  });

  final Duration duration;
  final Duration delay;
  final _EntranceFrame frame;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.value = 1;
    } else if (_clock.isDismissed) {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  double get _progress {
    final int delay = widget.delay.inMicroseconds;
    final int duration = widget.duration.inMicroseconds;
    final double elapsed = _clock.value * (delay + duration);
    return duration == 0 ? 1 : ((elapsed - delay) / duration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      child: widget.child,
      builder: (BuildContext context, Widget? child) =>
          widget.frame(_progress, child!),
    );
  }
}

class _Rise extends StatelessWidget {
  const _Rise({
    required this.duration,
    this.delay = Duration.zero,
    this.travel = _riseTravel,
    required this.child,
  });

  final Duration duration;
  final Duration delay;
  final double travel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: duration,
      delay: delay,
      frame: (double progress, Widget child) {
        final double eased = Curves.ease.transform(progress);
        return Opacity(
          opacity: eased,
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, travel * (1 - eased)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
