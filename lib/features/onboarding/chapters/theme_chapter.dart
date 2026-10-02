import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/dashed_divider.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/onboarding_surface.dart';
import 'package:field_notes/features/settings/settings_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kicker = 'and you';
const String _title = 'Daylight or lamplight?';

Key themeChoiceKey(Appearance appearance) =>
    ValueKey<String>('theme-choice-${appearance.name}');

const Key themePreviewKey = ValueKey<String>('theme-preview');
const Key themeFailureKey = ValueKey<String>('theme-failure');

const List<Appearance> _choices = <Appearance>[
  Appearance.light,
  Appearance.dark,
  Appearance.system,
];

const double _sidebarBodyGap = 92;
const double _sidebarMargin = 56;
const double _sidebarBottom = 72;
const double _sidebarGridMaxWidth = 1028;
const double _sidebarCardGap = 22;
const EdgeInsets _cardPadding = EdgeInsets.all(10);
const double _cardInnerGap = 10;
const double _cardOutline = 2;
const BorderRadius _cardRadius = BorderRadius.all(Radius.circular(16));
const Offset _cardShadowOffset = Offset(3, 3);
const EdgeInsets _cardLabelPadding = EdgeInsets.symmetric(
  horizontal: 4,
  vertical: 2,
);
const double _cardLabelGap = 8;
const double _cardIcon = 16;

const double _miniatureHeight = 170;
const double _miniatureEdge = 1.5;
const BorderRadius _miniatureRadius = BorderRadius.all(Radius.circular(10));
const double _miniatureSideWidth = 52;
const double _miniatureSideRule = 1;
const EdgeInsets _miniatureSidePadding = EdgeInsets.symmetric(
  horizontal: 9,
  vertical: 14,
);
const double _miniatureSideGap = 7;
const double _miniatureDot = 14;
const double _miniatureDotGap = 6;
const double _miniatureLine = 5;
const EdgeInsets _miniatureContentPadding = EdgeInsets.symmetric(
  horizontal: 14,
  vertical: 16,
);
const double _miniatureContentGap = 9;
const double _miniatureBar = 6;
const double _miniaturePill = 12;
const double _miniatureFlowersGap = 6;
const double _miniatureFlower = 24;
const double _miniatureFlowerGap = 6;
const double _dash = 3;
const List<Mood> _miniatureFlowers = <Mood>[Mood.happy, Mood.calm, Mood.warm];

const double _bottomBarSide = 18;
const double _bottomBarBottom = 76;
const double _bottomBarMiddlePadding = 14;
const double _rowHeight = 56;
const EdgeInsets _rowPadding = EdgeInsets.symmetric(
  horizontal: 14,
  vertical: 8,
);
const double _rowGap = 12;
const double _rowIcon = 20;
const double _rowRule = 1;
const double _rowsOutline = 1.5;
const BorderRadius _rowsRadius = BorderRadius.all(Radius.circular(16));
const BorderRadius _rowsInnerRadius = BorderRadius.all(
  Radius.circular(16 - _rowsOutline),
);
const double _radioSize = 22;
const double _radioRing = 2;
const double _radioDot = 10;

const double _phoneWidth = 130;
const double _phoneHeight = 200;
const double _phoneBezel = 4;
const EdgeInsets _phonePadding = EdgeInsets.fromLTRB(12, 16, 12, 10);
const BorderRadius _phoneRadius = BorderRadius.all(Radius.circular(20));
const double _phoneGap = 7;
const double _phoneCardGap = 7;
const double _phoneCardTop = 4;
const EdgeInsets _phoneCardPadding = EdgeInsets.all(7);
const BorderRadius _phoneCardRadius = BorderRadius.all(Radius.circular(9));
const double _phoneFlower = 22;
const double _phoneCardLinesGap = 4;
const double _phonePill = 16;
const Color _phoneBezelColor = Color(0xFF211C16);
const Color _phoneCardEdge = Color(0x59786450);
const Color _phoneShadow = Color(0x8C1E140A);
const Offset _phoneShadowOffset = Offset(0, 18);
const double _phoneShadowBlur = 34;
const double _phoneShadowSpread = -16;

const double _failureGap = 14;
const double _iconStroke = 1.9;
const double _iconViewBox = 24;

const Duration _headingRise = Duration(milliseconds: 500);
const Duration _cardRise = Duration(milliseconds: 500);
const Duration _cardDelay = Duration(milliseconds: 100);
const Duration _cardStagger = Duration(milliseconds: 120);
const Duration _phoneRise = Duration(milliseconds: 500);
const Duration _phoneDelay = Duration(milliseconds: 100);
const Duration _rowsRise = Duration(milliseconds: 500);
const Duration _rowsDelay = Duration(milliseconds: 200);
const Duration _selectFade = Duration(milliseconds: 150);
const Duration _dotPop = Duration(milliseconds: 200);

const double _travel = 14;
const Cubic _dotCurve = Cubic(0.2, 0.9, 0.3, 1.3);

String _label(Appearance appearance) => switch (appearance) {
  Appearance.light => 'Light',
  Appearance.dark => 'Dark',
  Appearance.system => 'System',
};

String _sidebarCaption(Appearance appearance) => switch (appearance) {
  Appearance.light => 'daylight',
  Appearance.dark => 'lamplight',
  Appearance.system => 'follows device',
};

String _rowCaption(Appearance appearance) => switch (appearance) {
  Appearance.light => 'Daylight · warm paper',
  Appearance.dark => 'Lamplight · easy at night',
  Appearance.system => 'Follows your phone',
};

typedef _Failure = ({String message, Appearance storedAt});

class ThemeChapter extends ConsumerStatefulWidget {
  const ThemeChapter({super.key, required this.layout});

  final ShellLayout layout;

  @override
  ConsumerState<ThemeChapter> createState() => _ThemeChapterState();
}

class _ThemeChapterState extends ConsumerState<ThemeChapter> {
  int _attempt = 0;
  _Failure? _failure;

  Future<void> _choose(Appearance appearance) async {
    final Appearance stored = ref.read(appearanceProvider);
    if (appearance == stored) {
      return;
    }
    final int attempt = ++_attempt;
    final SettingsWriteResult result = await ref
        .read(settingsControllerProvider)
        .setAppearance(appearance);
    if (!mounted || attempt != _attempt) {
      return;
    }
    setState(
      () => _failure = switch (result) {
        SettingsWriteFailed(:final String message) => (
          message: message,
          storedAt: ref.read(appearanceProvider),
        ),
        SettingsWriteSucceeded() => null,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Appearance selected = ref.watch(appearanceProvider);
    final _Failure? failure = _failure;
    final String? message = failure != null && failure.storedAt == selected
        ? failure.message
        : null;
    return SizedBox.expand(
      child: switch (widget.layout) {
        ShellLayout.sidebar => _SidebarTheme(
          selected: selected,
          failure: message,
          onChoose: _choose,
        ),
        ShellLayout.bottomBar => _BottomBarTheme(
          selected: selected,
          failure: message,
          onChoose: _choose,
        ),
      },
    );
  }
}

class _SidebarTheme extends StatelessWidget {
  const _SidebarTheme({
    required this.selected,
    required this.failure,
    required this.onChoose,
  });

  final Appearance selected;
  final String? failure;
  final ValueChanged<Appearance> onChoose;

  @override
  Widget build(BuildContext context) {
    final String? message = failure;
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
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints area) {
                final double width = math.min(
                  area.maxWidth,
                  _sidebarGridMaxWidth,
                );
                return Align(
                  alignment: Alignment.topCenter,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: width,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              for (final (int index, Appearance option)
                                  in _choices.indexed) ...<Widget>[
                                if (index > 0)
                                  const SizedBox(width: _sidebarCardGap),
                                Expanded(
                                  child: _Rise(
                                    duration: _cardRise,
                                    delay: _cardDelay + _cardStagger * index,
                                    child: _ThemeCard(
                                      key: themeChoiceKey(option),
                                      appearance: option,
                                      selected: option == selected,
                                      onPressed: () => onChoose(option),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (message != null) ...<Widget>[
                            const SizedBox(height: _failureGap),
                            _FailureText(
                              message: message,
                              align: TextAlign.center,
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
      ],
    );
  }
}

class _BottomBarTheme extends StatelessWidget {
  const _BottomBarTheme({
    required this.selected,
    required this.failure,
    required this.onChoose,
  });

  final Appearance selected;
  final String? failure;
  final ValueChanged<Appearance> onChoose;

  @override
  Widget build(BuildContext context) {
    final String? message = failure;
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
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints area) {
              final double width = math.max(
                0.0,
                area.maxWidth - 2 * _bottomBarSide,
              );
              return Column(
                children: <Widget>[
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: _bottomBarMiddlePadding,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _Rise(
                            duration: _phoneRise,
                            delay: _phoneDelay,
                            child: _PhonePreview(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: area.maxHeight),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: width,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _Rise(
                              duration: _rowsRise,
                              delay: _rowsDelay,
                              child: _ThemeRows(
                                selected: selected,
                                onChoose: onChoose,
                              ),
                            ),
                            if (message != null) ...<Widget>[
                              const SizedBox(height: _failureGap),
                              _FailureText(
                                message: message,
                                align: TextAlign.start,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: _bottomBarBottom),
      ],
    );
  }
}

class _FailureText extends StatelessWidget {
  const _FailureText({required this.message, required this.align});

  final String message;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: themeFailureKey,
      liveRegion: true,
      child: Text(
        message,
        textAlign: align,
        style: TextStyle(
          fontFamily: TypographyTokens.sans,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.colors.dangerInk,
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    super.key,
    required this.appearance,
    required this.selected,
    required this.onPressed,
  });

  final Appearance appearance;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final String label = _label(appearance);
    final String caption = _sidebarCaption(appearance);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $caption',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          borderRadius: _cardRadius,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : _selectFade,
            padding: _cardPadding,
            decoration: BoxDecoration(
              color: selected ? colors.cardLight : colors.cardWarm,
              borderRadius: _cardRadius,
              border: Border.all(
                color: selected ? Palette.coral : colors.ink22,
                width: _cardOutline,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: selected ? colors.shadow : colors.shadow.withAlpha(0),
                  offset: _cardShadowOffset,
                ),
              ],
            ),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Miniature(look: _MiniatureLook.of(appearance)),
                  const SizedBox(height: _cardInnerGap),
                  Padding(
                    padding: _cardLabelPadding,
                    child: Row(
                      children: <Widget>[
                        _ModeIcon(
                          appearance: appearance,
                          color: colors.ink,
                          size: _cardIcon,
                        ),
                        const SizedBox(width: _cardLabelGap),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: TypographyTokens.sans,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selected ? colors.accentInk : colors.ink,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          caption,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: TypographyTokens.sans,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.muted,
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
    );
  }
}

@immutable
class _MiniatureLook {
  const _MiniatureLook({
    required this.background,
    required this.side,
    required this.ink,
    required this.pill,
    this.split,
  });

  static final _MiniatureLook light = _MiniatureLook(
    background: FieldNotesColors.light.panelTop,
    side: FieldNotesColors.light.titleBar,
    ink: FieldNotesColors.light.ink,
    pill: FieldNotesColors.light.pill,
  );

  static final _MiniatureLook dark = _MiniatureLook(
    background: FieldNotesColors.dark.panelTop,
    side: FieldNotesColors.dark.cardWarm,
    ink: FieldNotesColors.dark.ink,
    pill: FieldNotesColors.dark.pill,
  );

  static final _MiniatureLook system = _MiniatureLook(
    background: FieldNotesColors.light.panelTop,
    split: FieldNotesColors.dark.panelTop,
    side: FieldNotesColors.dark.panelTop.withAlpha(0),
    ink: FieldNotesColors.dark.line,
    pill: FieldNotesColors.dark.placeholder,
  );

  static _MiniatureLook of(Appearance appearance) => switch (appearance) {
    Appearance.light => light,
    Appearance.dark => dark,
    Appearance.system => system,
  };

  final Color background;
  final Color? split;
  final Color side;
  final Color ink;
  final Color pill;
}

class _Miniature extends StatelessWidget {
  const _Miniature({required this.look});

  final _MiniatureLook look;

  @override
  Widget build(BuildContext context) {
    final Color sideLine = look.ink.withValues(alpha: 0.45);
    return ExcludeSemantics(
      child: SizedBox(
        height: _miniatureHeight,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: _miniatureRadius,
            border: Border.all(
              color: FieldNotesColors.light.ink35,
              width: _miniatureEdge,
            ),
          ),
          child: ClipRRect(
            borderRadius: _miniatureRadius,
            child: CustomPaint(
              painter: _BackdropPainter(
                background: look.background,
                split: look.split,
              ),
              child: Padding(
                padding: const EdgeInsets.all(_miniatureEdge),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      width: _miniatureSideWidth - _miniatureSideRule,
                      color: look.side,
                      padding: _miniatureSidePadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox.square(
                              dimension: _miniatureDot,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Palette.coral,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: _miniatureDotGap + _miniatureSideGap,
                          ),
                          for (int line = 0; line < 3; line++) ...<Widget>[
                            if (line > 0)
                              const SizedBox(height: _miniatureSideGap),
                            _Bar(height: _miniatureLine, color: sideLine),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(
                      width: _miniatureSideRule,
                      child: CustomPaint(
                        painter: DashedLinePainter(
                          axis: Axis.vertical,
                          thickness: _miniatureSideRule,
                          color: FieldNotesColors.light.ink25,
                          dashLength: _dash,
                          dashGap: _dash,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: _miniatureContentPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _Bar(
                              height: _miniatureBar,
                              fraction: 0.7,
                              color: look.ink.withValues(alpha: 0.8),
                            ),
                            const SizedBox(height: _miniatureContentGap),
                            _Bar(
                              height: _miniatureBar,
                              fraction: 0.45,
                              color: look.ink.withValues(alpha: 0.45),
                            ),
                            const SizedBox(height: _miniatureContentGap),
                            _Bar(
                              height: _miniaturePill,
                              color: look.pill.withValues(alpha: 0.9),
                            ),
                            const SizedBox(
                              height:
                                  _miniatureContentGap + _miniatureFlowersGap,
                            ),
                            Row(
                              children: <Widget>[
                                for (final (int index, Mood mood)
                                    in _miniatureFlowers.indexed) ...<Widget>[
                                  if (index > 0)
                                    const SizedBox(width: _miniatureFlowerGap),
                                  FlowerBloom.forMood(
                                    mood,
                                    size: _miniatureFlower,
                                  ),
                                ],
                              ],
                            ),
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
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color, this.fraction = 1});

  final double height;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: fraction,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.all(Radius.circular(height / 2)),
          ),
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({required this.background, this.split});

  final Color background;
  final Color? split;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final Color? other = split;
    if (other == null) {
      return;
    }
    final double reach = size.width + size.height;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(math.pi / 4)
      ..drawRect(Rect.fromLTRB(0, -reach, reach, reach), Paint()..color = other)
      ..restore();
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) =>
      oldDelegate.background != background || oldDelegate.split != split;
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview();

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return ExcludeSemantics(
      key: themePreviewKey,
      child: Container(
        width: _phoneWidth,
        height: _phoneHeight,
        padding: _phonePadding,
        decoration: BoxDecoration(
          color: colors.panelTop,
          borderRadius: _phoneRadius,
          border: Border.all(color: _phoneBezelColor, width: _phoneBezel),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: _phoneShadow,
              offset: _phoneShadowOffset,
              blurRadius: _phoneShadowBlur,
              spreadRadius: _phoneShadowSpread,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Bar(
              height: 5,
              fraction: 0.45,
              color: Palette.coral.withValues(alpha: 0.8),
            ),
            const SizedBox(height: _phoneGap),
            _Bar(
              height: 8,
              fraction: 0.75,
              color: colors.ink.withValues(alpha: 0.7),
            ),
            const SizedBox(height: _phoneGap + _phoneCardTop),
            Container(
              padding: _phoneCardPadding,
              decoration: BoxDecoration(
                color: colors.cardWarm,
                borderRadius: _phoneCardRadius,
                border: Border.all(color: _phoneCardEdge),
              ),
              child: Row(
                children: <Widget>[
                  FlowerBloom.forMood(Mood.happy, size: _phoneFlower),
                  const SizedBox(width: _phoneCardGap),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _Bar(
                          height: 4,
                          fraction: 0.8,
                          color: colors.ink.withValues(alpha: 0.55),
                        ),
                        const SizedBox(height: _phoneCardLinesGap),
                        _Bar(
                          height: 4,
                          fraction: 0.5,
                          color: colors.ink.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _Bar(height: _phonePill, color: colors.pill),
          ],
        ),
      ),
    );
  }
}

class _ThemeRows extends StatelessWidget {
  const _ThemeRows({required this.selected, required this.onChoose});

  final Appearance selected;
  final ValueChanged<Appearance> onChoose;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.cardWarm,
        borderRadius: _rowsRadius,
        border: Border.all(color: colors.ink22, width: _rowsOutline),
      ),
      child: ClipRRect(
        borderRadius: _rowsInnerRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (int index, Appearance option) in _choices.indexed)
              _ThemeRow(
                key: themeChoiceKey(option),
                appearance: option,
                selected: option == selected,
                last: index == _choices.length - 1,
                onPressed: () => onChoose(option),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    super.key,
    required this.appearance,
    required this.selected,
    required this.last,
    required this.onPressed,
  });

  final Appearance appearance;
  final bool selected;
  final bool last;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool still = MediaQuery.disableAnimationsOf(context);
    final String label = _label(appearance);
    final String caption = _rowCaption(appearance);
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      label: '$label, ${caption.replaceAll(' · ', ', ')}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          placement: FocusRingPlacement.edge,
          child: AnimatedContainer(
            duration: still ? Duration.zero : _selectFade,
            constraints: const BoxConstraints(minHeight: _rowHeight),
            padding: _rowPadding,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: selected
                  ? colors.cardLight
                  : colors.cardLight.withAlpha(0),
              border: last
                  ? null
                  : Border(
                      bottom: BorderSide(color: colors.ink12, width: _rowRule),
                    ),
            ),
            child: ExcludeSemantics(
              child: Row(
                children: <Widget>[
                  _ModeIcon(
                    appearance: appearance,
                    color: colors.ink,
                    size: _rowIcon,
                  ),
                  const SizedBox(width: _rowGap),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TypographyTokens.sans,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selected ? colors.accentInk : colors.ink,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TypographyTokens.sans,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: _rowGap),
                  _Radio(selected: selected, still: still),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.still});

  final bool selected;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _radioSize,
      height: _radioSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Palette.coral : context.colors.ink35,
          width: _radioRing,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: still ? Duration.zero : _dotPop,
        curve: _dotCurve,
        child: const SizedBox.square(
          dimension: _radioDot,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.coral,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeIcon extends StatelessWidget {
  const _ModeIcon({
    required this.appearance,
    required this.color,
    required this.size,
  });

  final Appearance appearance;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ModeIconPainter(appearance: appearance, color: color),
        size: Size.square(size),
      ),
    );
  }
}

class _ModeIconPainter extends CustomPainter {
  const _ModeIconPainter({required this.appearance, required this.color});

  final Appearance appearance;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _iconStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas
      ..save()
      ..scale(size.shortestSide / _iconViewBox);
    switch (appearance) {
      case Appearance.light:
        canvas
          ..drawCircle(const Offset(12, 12), 4, stroke)
          ..drawPath(_rays(), stroke);
      case Appearance.dark:
        canvas.drawPath(_moon(), stroke);
      case Appearance.system:
        final Paint fill = Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
        final Path half = _half();
        canvas
          ..drawPath(half, fill)
          ..drawPath(half, stroke)
          ..drawCircle(const Offset(12, 12), 8, stroke);
    }
    canvas.restore();
  }

  Path _rays() => Path()
    ..moveTo(12, 2.5)
    ..lineTo(12, 4.5)
    ..moveTo(12, 19.5)
    ..lineTo(12, 21.5)
    ..moveTo(4.6, 4.6)
    ..lineTo(6, 6)
    ..moveTo(18, 18)
    ..lineTo(19.4, 19.4)
    ..moveTo(2.5, 12)
    ..lineTo(4.5, 12)
    ..moveTo(19.5, 12)
    ..lineTo(21.5, 12)
    ..moveTo(4.6, 19.4)
    ..lineTo(6, 18)
    ..moveTo(18, 6)
    ..lineTo(19.4, 4.6);

  Path _moon() => Path()
    ..moveTo(20, 14.5)
    ..arcToPoint(const Offset(9.5, 4), radius: const Radius.circular(8))
    ..arcToPoint(
      const Offset(20, 14.5),
      radius: const Radius.circular(8),
      largeArc: true,
      clockwise: false,
    )
    ..close();

  Path _half() => Path()
    ..moveTo(12, 4)
    ..arcToPoint(const Offset(12, 20), radius: const Radius.circular(8))
    ..close();

  @override
  bool shouldRepaint(_ModeIconPainter oldDelegate) =>
      oldDelegate.appearance != appearance || oldDelegate.color != color;
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
    required this.child,
  });

  final Duration duration;
  final Duration delay;
  final Widget child;

  static Widget _frame(double progress, Widget child) {
    final double eased = Curves.ease.transform(progress);
    return Opacity(
      opacity: eased,
      alwaysIncludeSemantics: true,
      child: Transform.translate(
        offset: Offset(0, _travel * (1 - eased)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: duration,
      delay: delay,
      frame: _frame,
      child: child,
    );
  }
}
