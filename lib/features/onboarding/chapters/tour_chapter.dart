import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/empty_state.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/nav_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/dashed_divider.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';
import 'package:field_notes/features/onboarding/onboarding_surface.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kicker = 'one last thing';
const String _title = "Here's where everything lives.";

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
    title: 'Settings',
    line: 'Theme, reminders and your week. Change them anytime.',
  ),
];

const List<_Place> _bottomBarPlaces = <_Place>[
  (title: 'Today', line: 'Your day, its mood and its logs.'),
  (title: 'Calendar', line: "Every day you've kept."),
  (title: 'New log', line: 'Write, speak, film or add a photo.'),
  (title: 'Meadow', line: 'Your year in bloom.'),
  (title: 'Search', line: 'Find any memory.'),
  (title: 'Settings', line: 'The gear on Today: theme, reminders, week.'),
];

typedef _NavPlace = ({String label, NavGlyph glyph});

const List<_NavPlace> _sidebarNav = <_NavPlace>[
  (label: 'Today', glyph: NavGlyph.home),
  (label: 'Calendar', glyph: NavGlyph.calendar),
  (label: 'Meadow', glyph: NavGlyph.garden),
  (label: 'Search', glyph: NavGlyph.search),
];

const int _sidebarGearNumber = 5;
const int _bottomBarAddNumber = 3;
const int _bottomBarGearNumber = 6;

const Map<int, ShellDestination> _bottomBarSelection = <int, ShellDestination>{
  1: ShellDestination.today,
  2: ShellDestination.calendar,
  4: ShellDestination.garden,
  5: ShellDestination.search,
};

const Color _miniatureDrop = Color(0x66281C12);

const double _outline = 1.5;
const double _badgeSidebar = 20;
const double _badgeBottomBar = 18;
const double _badgeFontSidebar = 11;
const double _badgeFontBottomBar = 10;

const double _sidebarMargin = 40;
const double _sidebarBodyGap = 52;
const double _sidebarBottom = 72;
const double _sidebarColumnsGap = 40;
const double _sidebarListWidth = 340;
const double _sidebarLineGap = 6;

const double _bottomBarSide = 16;
const double _bottomBarListTop = 12;
const double _bottomBarBottom = 76;
const double _bottomBarLineGap = 4;
const double _bottomBarNavGap = 16;

const double _lineMinHeight = 48;
const BorderRadius _lineRadius = BorderRadius.all(Radius.circular(12));
const EdgeInsets _sidebarLinePadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 10,
);
const EdgeInsets _bottomBarLinePadding = EdgeInsets.symmetric(
  horizontal: 9,
  vertical: 7,
);
const double _sidebarLineInnerGap = 12;
const double _bottomBarLineInnerGap = 10;
const double _sidebarLineTextGap = 2;

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

const double _navBadgeTop = -_badgeBottomBar / 2;
const double _navAddBadgeTop = _navBadgeTop - phoneBottomBarCaptureRise;
const double _navGearGlyph = 22;
const double _navGearGap = 10;

const Duration _headingRise = Duration(milliseconds: 500);
const Duration _bodyRise = Duration(milliseconds: 600);
const Duration _miniatureDelay = Duration(milliseconds: 150);
const Duration _sidebarListDelay = Duration(milliseconds: 300);
const Duration _bottomBarListDelay = Duration(milliseconds: 200);
const Duration _navBarDelay = Duration(milliseconds: 400);
const Duration _highlightFade = Duration(milliseconds: 200);

const double _riseTravel = 14;
const double _liftTravel = 40;

Duration _fade(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : _highlightFade;

class TourChapter extends ConsumerStatefulWidget {
  const TourChapter({super.key, required this.layout});

  final ShellLayout layout;

  @override
  ConsumerState<TourChapter> createState() => _TourChapterState();
}

class _TourChapterState extends ConsumerState<TourChapter> {
  int? _highlighted;

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
          child: OnboardingHeading(
            layout: ShellLayout.sidebar,
            kicker: _kicker,
            title: _title,
          ),
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
                        child: _TourLines(
                          layout: ShellLayout.sidebar,
                          places: _sidebarPlaces,
                          gap: _sidebarLineGap,
                          highlighted: highlighted,
                          onHighlight: onHighlight,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _Rise(
          duration: _headingRise,
          child: OnboardingHeading(
            layout: ShellLayout.bottomBar,
            kicker: _kicker,
            title: _title,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              _bottomBarSide,
              _bottomBarListTop,
              _bottomBarSide,
              _bottomBarBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Rise(
                  duration: _bodyRise,
                  delay: _bottomBarListDelay,
                  child: _TourLines(
                    layout: ShellLayout.bottomBar,
                    places: _bottomBarPlaces,
                    gap: _bottomBarLineGap,
                    highlighted: highlighted,
                    onHighlight: onHighlight,
                  ),
                ),
                const SizedBox(height: _bottomBarNavGap),
                _Rise(
                  duration: _bodyRise,
                  delay: _navBarDelay,
                  travel: _liftTravel,
                  child: _BottomBarMiniature(highlighted: highlighted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TourLines extends StatelessWidget {
  const _TourLines({
    required this.layout,
    required this.places,
    required this.gap,
    required this.highlighted,
    required this.onHighlight,
  });

  final ShellLayout layout;
  final List<_Place> places;
  final double gap;
  final int? highlighted;
  final ValueChanged<int> onHighlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (int index, _Place place) in places.indexed) ...<Widget>[
          if (index > 0) SizedBox(height: gap),
          _TourLine(
            key: tourLineKey(index + 1),
            layout: layout,
            number: index + 1,
            place: place,
            highlighted: highlighted == index + 1,
            onHighlight: () => onHighlight(index + 1),
          ),
        ],
      ],
    );
  }
}

class _TourLine extends StatelessWidget {
  const _TourLine({
    super.key,
    required this.layout,
    required this.number,
    required this.place,
    required this.highlighted,
    required this.onHighlight,
  });

  final ShellLayout layout;
  final int number;
  final _Place place;
  final bool highlighted;
  final VoidCallback onHighlight;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool sidebar = layout == ShellLayout.sidebar;
    return Semantics(
      container: true,
      selected: highlighted,
      label: '$number, ${place.title}, ${place.line}',
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
              borderRadius: _lineRadius,
              child: AnimatedContainer(
                duration: _fade(context),
                constraints: const BoxConstraints(minHeight: _lineMinHeight),
                padding: sidebar ? _sidebarLinePadding : _bottomBarLinePadding,
                decoration: BoxDecoration(
                  color: highlighted
                      ? colors.cardLight
                      : colors.cardLight.withAlpha(0),
                  borderRadius: _lineRadius,
                  border: Border.all(
                    color: highlighted
                        ? colors.ink30
                        : colors.ink30.withAlpha(0),
                    width: _outline,
                  ),
                ),
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TourBadge(
                        number: number,
                        highlighted: highlighted,
                        inMiniature: false,
                        layout: layout,
                      ),
                      SizedBox(
                        width: sidebar
                            ? _sidebarLineInnerGap
                            : _bottomBarLineInnerGap,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              place.title,
                              style: TextStyle(
                                fontFamily: TypographyTokens.serif,
                                fontSize: sidebar ? 18 : 15,
                                fontWeight: FontWeight.w500,
                                height: 1.15,
                                color: colors.ink,
                              ),
                            ),
                            if (sidebar)
                              const SizedBox(height: _sidebarLineTextGap),
                            Text(
                              place.line,
                              style: TextStyle(
                                fontFamily: TypographyTokens.sans,
                                fontSize: sidebar ? 13 : 11.5,
                                fontWeight: FontWeight.w400,
                                height: sidebar ? 1.4 : 1.35,
                                color: colors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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

class _BottomBarMiniature extends StatelessWidget {
  const _BottomBarMiniature({required this.highlighted});

  final int? highlighted;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: _MiniatureGear(
              highlighted: highlighted == _bottomBarGearNumber,
            ),
          ),
          const SizedBox(height: _navGearGap),
          Stack(
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
                  children: <Widget>[
                    for (
                      int number = 1;
                      number < _bottomBarGearNumber;
                      number++
                    )
                      Expanded(
                        child: _NavSlot(
                          number: number,
                          highlighted: highlighted == number,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({required this.number, required this.highlighted});

  final int number;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return MapPlaceHighlight(
      key: tourTargetKey(number),
      highlighted: highlighted,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            top: number == _bottomBarAddNumber ? _navAddBadgeTop : _navBadgeTop,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: TourBadge(
                key: tourBadgeKey(number),
                number: number,
                highlighted: highlighted,
                inMiniature: true,
                layout: ShellLayout.bottomBar,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniatureGear extends StatelessWidget {
  const _MiniatureGear({required this.highlighted});

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return MapPlaceHighlight(
      key: tourTargetKey(_bottomBarGearNumber),
      highlighted: highlighted,
      child: SizedBox.square(
        dimension: _navGearGlyph,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            IconStickerGlyphIcon(
              glyph: IconStickerGlyph.gear,
              color: context.colors.ink,
              size: _navGearGlyph,
            ),
            Positioned(
              top: _navBadgeTop,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: TourBadge(
                  key: tourBadgeKey(_bottomBarGearNumber),
                  number: _bottomBarGearNumber,
                  highlighted: highlighted,
                  inMiniature: true,
                  layout: ShellLayout.bottomBar,
                ),
              ),
            ),
          ],
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
