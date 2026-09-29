import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/motion/motion_tokens.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/onboarding/tour/tour_geometry.dart';
import 'package:field_notes/features/onboarding/tour/tour_spotlight.dart';
import 'package:field_notes/features/onboarding/tour/tour_tips.dart';
import 'package:field_notes/features/onboarding/tour_anchor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TourMode { firstRun, replay }

const Key tourCardKey = ValueKey<String>('tour-card');
const Key tourScrimKey = ValueKey<String>('tour-scrim');
const Key tourControlsKey = ValueKey<String>('tour-controls');
const Key tourNextKey = ValueKey<String>('tour-next');
const Key tourBackKey = ValueKey<String>('tour-back');
const Key tourSkipKey = ValueKey<String>('tour-skip');

Key tourProgressKey(int index) => ValueKey<String>('tour-progress-$index');

const String _skipLabel = 'Skip tour';
const String _backLabel = 'Back';
const String _nextLabel = 'Next';
const String _setUpLabel = 'Set up';
const String _doneLabel = 'Done';
const String _keysHint = '← → keys';

const Color _progressDone = Color(0xFFDBA493);
const double _progressHeight = 5;
const double _progressGap = 4;
const double _cardBorderWidth = 2;
const double _sidebarCardRadius = 18;
const double _bottomBarCardRadius = 20;
const double _sidebarButtonHeight = 36;
const double _bottomBarControlHeight = 48;
const double _nextPillMinWidth = 124;
const double _pillBorderWidth = 2;
const double _minTapTarget = 48;
const double _disabledOpacity = 0.45;
const double _backGlyphSize = 22;

const BorderRadius _sidebarButtonRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusSm),
);
const BorderRadius _pillRadius = BorderRadius.all(
  Radius.circular(_bottomBarControlHeight / 2),
);

const BoxShadow _cardLift = BoxShadow(
  color: Color(0xA6140C06),
  offset: Offset(0, 26),
  blurRadius: 50,
  spreadRadius: -20,
);

List<BoxShadow> _cardShadow(FieldNotesColors colors) => <BoxShadow>[
  BoxShadow(color: colors.shadowTint(0x66), offset: const Offset(4, 4)),
  _cardLift,
];

TextStyle _titleStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.serif,
  fontSize: 22,
  fontWeight: FontWeight.w500,
  height: 1.15,
  color: colors.ink,
);

TextStyle _lineStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.45,
  color: colors.mutedDeep,
);

TextStyle _skipStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 11.5,
  fontWeight: FontWeight.w600,
  color: colors.mutedDeep,
);

const TextStyle _skipOnScrimStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12.5,
  fontWeight: FontWeight.w600,
  color: Palette.toastInk,
);

TextStyle _hintStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 10.5,
  fontWeight: FontWeight.w500,
  color: colors.placeholder,
);

TextStyle _backStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12.5,
  fontWeight: FontWeight.w600,
  color: colors.ink,
);

const TextStyle _nextStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12.5,
  fontWeight: FontWeight.w600,
  color: Palette.onAccent,
);

const TextStyle _pillStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 14.5,
  fontWeight: FontWeight.w600,
  color: Palette.onAccent,
);

class OnboardingTour extends ConsumerStatefulWidget {
  const OnboardingTour({
    super.key,
    required this.layout,
    required this.mode,
    this.initialTip = 0,
    required this.onBackOut,
    required this.onFinish,
    required this.onSkip,
  });

  final ShellLayout layout;
  final TourMode mode;
  final int initialTip;
  final VoidCallback onBackOut;
  final VoidCallback onFinish;
  final VoidCallback onSkip;

  @override
  ConsumerState<OnboardingTour> createState() => _OnboardingTourState();
}

class _OnboardingTourState extends ConsumerState<OnboardingTour>
    with SingleTickerProviderStateMixin {
  final GlobalKey _cardBox = GlobalKey(debugLabel: 'tour-card-box');
  final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'tour');
  final FocusNode _nextFocus = FocusNode(debugLabel: 'tour-next');
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: tourMoveDuration,
  );
  late int _tip = widget.initialTip.clamp(0, tourTips.length - 1);
  TourPlacement? _from;
  TourPlacement? _to;
  bool _ready = false;

  bool get _sidebar => widget.layout == ShellLayout.sidebar;

  bool get _lastTip => _tip == tourTips.length - 1;

  bool get _canGoBack => _tip > 0 || widget.mode == TourMode.firstRun;

  String get _nextText {
    if (!_lastTip) {
      return _nextLabel;
    }
    return widget.mode == TourMode.firstRun ? _setUpLabel : _doneLabel;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_claimFocus);
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : tourMoveDuration;
  }

  @override
  void dispose() {
    _motion.dispose();
    _nextFocus.dispose();
    _scope.dispose();
    super.dispose();
  }

  void _claimFocus(Duration timeStamp) {
    if (mounted && !_scope.hasFocus) {
      _nextFocus.requestFocus();
    }
  }

  void _measure(Duration timeStamp) {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    final RenderObject? overlay = context.findRenderObject();
    final TourPlacement? placement = _place(overlay);
    if (overlay is! RenderBox || placement == null) {
      return;
    }
    final TourPlacement? current = _to;
    if (current != null && current.closeTo(placement)) {
      if (!_ready) {
        setState(() => _ready = true);
      }
      return;
    }
    if (!_ready || current == null) {
      setState(() {
        _from = placement;
        _to = placement;
      });
      _motion.value = 1;
      return;
    }
    final TourPlacement shown = _shown(current, overlay.size);
    setState(() {
      _from = shown;
      _to = placement;
    });
    _motion.forward(from: 0);
  }

  TourPlacement? _place(RenderObject? overlay) {
    final RenderObject? card = _cardBox.currentContext?.findRenderObject();
    if (overlay is! RenderBox ||
        !overlay.hasSize ||
        card is! RenderBox ||
        !card.hasSize) {
      return null;
    }
    final TourAnchors anchors = ref.read(tourAnchorsProvider);
    final TourTip tip = tourTips[_tip];
    final TourTarget? target = tip.target;
    final MediaQuery? query = context
        .getInheritedWidgetOfExactType<MediaQuery>();
    return placeTour(
      window: overlay.size,
      safeArea: query?.data.padding ?? EdgeInsets.zero,
      tip: tip,
      layout: widget.layout,
      target: target == null ? null : anchors.rectOf(target, overlay),
      cardHeight: card.size.height,
      navRect: _sidebar ? null : anchors.rectOf(TourTarget.nav, overlay),
    );
  }

  TourPlacement _shown(TourPlacement to, Size window) {
    return TourPlacement.lerp(
      _from ?? to,
      to,
      tourMoveCurve.transform(_motion.value),
      window.center(Offset.zero),
    );
  }

  void _next() {
    if (_lastTip) {
      widget.onFinish();
      return;
    }
    setState(() => _tip = _tip + 1);
  }

  void _back() {
    if (_tip > 0) {
      setState(() => _tip = _tip - 1);
      return;
    }
    if (widget.mode == TourMode.firstRun) {
      widget.onBackOut();
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.arrowRight) {
      _next();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _back();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      widget.onSkip();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesShadows shadows = context.shadows;
    final TourTip tip = tourTips[_tip];
    final Widget card = _card(tip, colors, shadows);
    final Widget? controls = _sidebar ? null : _controls(colors, shadows);
    final EdgeInsets safeArea = MediaQuery.paddingOf(context);
    final Duration fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Motion.fade;
    return BlockSemantics(
      child: Material(
        type: MaterialType.transparency,
        child: FocusScope(
          node: _scope,
          autofocus: true,
          onKeyEvent: _handleKey,
          child: FocusTraversalGroup(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Size window = constraints.biggest;
                final TourPlacement fallback = placeTour(
                  window: window,
                  safeArea: safeArea,
                  tip: tip,
                  layout: widget.layout,
                  target: null,
                  cardHeight: 0,
                );
                return AnimatedBuilder(
                  animation: _motion,
                  builder: (BuildContext context, Widget? child) {
                    final TourPlacement? to = _to;
                    final TourPlacement shown = to == null
                        ? fallback
                        : _shown(to, window);
                    final Rect? controlsRect = shown.controls;
                    return Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: AbsorbPointer(
                            child: ExcludeSemantics(
                              child: CustomPaint(
                                key: tourScrimKey,
                                painter: TourSpotlightPainter(
                                  hole: _ready ? shown.spotlight : null,
                                  radius: shown.radius,
                                  innerRingColor: colors.cardLight,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: shown.card.dx,
                          top: shown.card.dy,
                          width: shown.cardWidth,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: shown.cardMaxHeight,
                            ),
                            child: AnimatedOpacity(
                              opacity: _ready ? 1 : 0,
                              duration: fade,
                              curve: Motion.fadeCurve,
                              child: card,
                            ),
                          ),
                        ),
                        if (controls != null && controlsRect != null)
                          Positioned.fromRect(
                            rect: controlsRect,
                            child: AnimatedOpacity(
                              opacity: _ready ? 1 : 0,
                              duration: fade,
                              curve: Motion.fadeCurve,
                              child: controls,
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(
    TourTip tip,
    FieldNotesColors colors,
    FieldNotesShadows shadows,
  ) {
    final String? line = tip.lineFor(
      widget.layout,
      replay: widget.mode == TourMode.replay,
    );
    return Semantics(
      key: tourCardKey,
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: tip.title,
      child: DecoratedBox(
        key: _cardBox,
        decoration: BoxDecoration(
          color: colors.composerPaper,
          border: Border.all(color: colors.line, width: _cardBorderWidth),
          borderRadius: BorderRadius.all(
            Radius.circular(
              _sidebar ? _sidebarCardRadius : _bottomBarCardRadius,
            ),
          ),
          boxShadow: _cardShadow(colors),
        ),
        child: Padding(
          padding: _sidebar
              ? const EdgeInsets.fromLTRB(18, 4, 18, 10)
              : const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_sidebar) _sidebarHeader(colors) else _progress(colors),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (!_sidebar) const SizedBox(height: 10),
                      Semantics(
                        header: true,
                        child: Text(
                          tip.title,
                          style: _sidebar
                              ? _titleStyle(colors)
                              : _titleStyle(colors).copyWith(fontSize: 19),
                        ),
                      ),
                      TourTipVisual(visual: tip.visual, layout: widget.layout),
                      if (line != null) ...<Widget>[
                        SizedBox(height: _sidebar ? 12 : 10),
                        Text(
                          line,
                          style: _sidebar
                              ? _lineStyle(colors)
                              : _lineStyle(colors).copyWith(fontSize: 11.5),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_sidebar) ...<Widget>[
                const SizedBox(height: 10),
                _sidebarFooter(colors, shadows),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebarHeader(FieldNotesColors colors) {
    return Row(
      children: <Widget>[
        Expanded(child: _progress(colors)),
        const SizedBox(width: 14),
        _TourTextButton(
          key: tourSkipKey,
          label: _skipLabel,
          onPressed: widget.onSkip,
          style: _skipStyle(colors),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _progress(FieldNotesColors colors) {
    return Semantics(
      label: 'Tip ${_tip + 1} of ${tourTips.length}',
      child: Row(
        children: <Widget>[
          for (int index = 0; index < tourTips.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: _progressGap),
            Expanded(
              child: SizedBox(
                height: _progressHeight,
                child: DecoratedBox(
                  key: tourProgressKey(index),
                  decoration: BoxDecoration(
                    color: index == _tip
                        ? Palette.coral
                        : index < _tip
                        ? _progressDone
                        : colors.ink18,
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sidebarFooter(FieldNotesColors colors, FieldNotesShadows shadows) {
    return Row(
      children: <Widget>[
        Expanded(
          child: ExcludeSemantics(
            child: Text(_keysHint, style: _hintStyle(colors)),
          ),
        ),
        _TourButton(
          key: tourBackKey,
          label: _backLabel,
          onPressed: _canGoBack ? _back : null,
          height: _sidebarButtonHeight,
          borderRadius: _sidebarButtonRadius,
          border: Border.all(color: colors.ink35, width: Shapes.outlineWidth),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(_backLabel, maxLines: 1, style: _backStyle(colors)),
        ),
        const SizedBox(width: 8),
        _TourButton(
          key: tourNextKey,
          label: _nextText,
          onPressed: _next,
          height: _sidebarButtonHeight,
          borderRadius: _sidebarButtonRadius,
          border: shadows.outline,
          color: Palette.coral,
          shadow: shadows.control,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          focusNode: _nextFocus,
          autofocus: true,
          child: Text(_nextText, maxLines: 1, style: _nextStyle),
        ),
      ],
    );
  }

  Widget _controls(FieldNotesColors colors, FieldNotesShadows shadows) {
    final Border pillBorder = Border.all(
      color: colors.line,
      width: _pillBorderWidth,
    );
    return Row(
      key: tourControlsKey,
      children: <Widget>[
        _TourTextButton(
          key: tourSkipKey,
          label: _skipLabel,
          onPressed: widget.onSkip,
          style: _skipOnScrimStyle,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          surface: FocusRingSurface.dark,
        ),
        const Spacer(),
        _TourButton(
          key: tourBackKey,
          label: _backLabel,
          onPressed: _canGoBack ? _back : null,
          height: _bottomBarControlHeight,
          width: _bottomBarControlHeight,
          borderRadius: _pillRadius,
          border: pillBorder,
          color: colors.composerPaper,
          surface: FocusRingSurface.dark,
          child: Icon(
            Icons.chevron_left_rounded,
            size: _backGlyphSize,
            color: colors.ink,
          ),
        ),
        const SizedBox(width: 8),
        _TourButton(
          key: tourNextKey,
          label: _nextText,
          onPressed: _next,
          height: _bottomBarControlHeight,
          minWidth: _nextPillMinWidth,
          borderRadius: _pillRadius,
          border: pillBorder,
          color: Palette.coral,
          shadow: shadows.emphasis,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          surface: FocusRingSurface.dark,
          focusNode: _nextFocus,
          autofocus: true,
          child: Text(_nextText, maxLines: 1, style: _pillStyle),
        ),
      ],
    );
  }
}

class _TourButton extends StatelessWidget {
  const _TourButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.height,
    required this.borderRadius,
    required this.border,
    required this.child,
    this.color,
    this.shadow = const <BoxShadow>[],
    this.width,
    this.minWidth = 0,
    this.padding = EdgeInsets.zero,
    this.surface = FocusRingSurface.light,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final BorderRadius borderRadius;
  final BoxBorder border;
  final Widget child;
  final Color? color;
  final List<BoxShadow> shadow;
  final double? width;
  final double minWidth;
  final EdgeInsets padding;
  final FocusRingSurface surface;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : _disabledOpacity,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTapTarget,
              minHeight: _minTapTarget,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: FocusRing(
                enabled: enabled,
                autofocus: autofocus,
                focusNode: focusNode,
                onPressed: onPressed,
                surface: surface,
                borderRadius: borderRadius,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: minWidth),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        border: border,
                        borderRadius: borderRadius,
                        boxShadow: shadow,
                      ),
                      child: Padding(
                        padding: padding,
                        child: Center(
                          widthFactor: 1,
                          child: ExcludeSemantics(child: child),
                        ),
                      ),
                    ),
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

class _TourTextButton extends StatelessWidget {
  const _TourTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.style,
    required this.padding,
    this.surface = FocusRingSurface.light,
  });

  final String label;
  final VoidCallback onPressed;
  final TextStyle style;
  final EdgeInsets padding;
  final FocusRingSurface surface;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          surface: surface,
          borderRadius: const BorderRadius.all(
            Radius.circular(Shapes.radiusXs),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTapTarget,
              minHeight: _minTapTarget,
            ),
            child: Padding(
              padding: padding,
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: ExcludeSemantics(
                  child: Text(label, maxLines: 1, style: style),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
