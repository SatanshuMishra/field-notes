import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';

const Key onboardingCardKey = ValueKey<String>('onboarding-card');
const Key onboardingPageKey = ValueKey<String>('onboarding-page');

const double onboardingCardWidth = 520;

const double _cardBorderWidth = 2;
const double _cardMargin = 28;
const double _cardRoomyHeight = 560;
const double _cardSideInset = 16;
const double _scrimBlurSigma = 3.5;
const double _minTapTarget = 48;
const double _disabledOpacity = 0.45;

const RadialGradient _scrimGradient = RadialGradient(
  center: Alignment(0, -0.36),
  radius: 1.2,
  colors: <Color>[Color(0x5C2A2016), Color(0x9E1C140C)],
);

const BoxShadow _cardLift = BoxShadow(
  color: Color(0xB3140C06),
  offset: Offset(0, 30),
  blurRadius: 70,
  spreadRadius: -24,
);

List<BoxShadow> _cardShadow(FieldNotesColors colors) => <BoxShadow>[
  BoxShadow(color: colors.shadowTint(0x59), offset: const Offset(5, 5)),
  _cardLift,
];

LinearGradient _pageGradient(FieldNotesColors colors) => LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[colors.paperShade, colors.hatchLight],
);

const RadialGradient _pageGlow = RadialGradient(
  center: Alignment(0.64, -1),
  radius: 1.2,
  colors: <Color>[Color(0x29C76A54), Color(0x00C76A54)],
  stops: <double>[0, 0.6],
);

const TextStyle _primaryLabel = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: Palette.onAccent,
);

class OnboardingSurface extends StatelessWidget {
  const OnboardingSurface({
    super.key,
    required this.layout,
    required this.child,
  });

  final ShellLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return BlockSemantics(
      child: switch (layout) {
        ShellLayout.sidebar => _card(colors),
        ShellLayout.bottomBar => _page(colors),
      },
    );
  }

  Widget _card(FieldNotesColors colors) {
    return Stack(
      children: <Widget>[
        const Positioned.fill(child: _OnboardingScrim()),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double margin = constraints.maxHeight < _cardRoomyHeight
                  ? 0
                  : _cardMargin;
              final double width = math.min(
                onboardingCardWidth,
                math.max(0, constraints.maxWidth - 2 * _cardSideInset),
              );
              return Center(
                child: Container(
                  key: onboardingCardKey,
                  width: width,
                  constraints: BoxConstraints(
                    maxHeight: math.max(0, constraints.maxHeight - 2 * margin),
                  ),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: colors.composerPaper,
                    border: Border.all(
                      color: colors.line,
                      width: _cardBorderWidth,
                    ),
                    borderRadius: BorderRadius.circular(Shapes.radiusSheet),
                    boxShadow: _cardShadow(colors),
                  ),
                  child: child,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _page(FieldNotesColors colors) {
    return SizedBox.expand(
      child: DecoratedBox(
        key: onboardingPageKey,
        decoration: BoxDecoration(gradient: _pageGradient(colors)),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: _pageGlow),
          child: SafeArea(child: child),
        ),
      ),
    );
  }
}

class _OnboardingScrim extends StatelessWidget {
  const _OnboardingScrim();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: _scrimBlurSigma,
          sigmaY: _scrimBlurSigma,
        ),
        child: const DecoratedBox(
          decoration: BoxDecoration(gradient: _scrimGradient),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.height,
    required this.borderRadius,
    this.labelStyle = _primaryLabel,
    this.padding = EdgeInsets.zero,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final BorderRadius borderRadius;
  final TextStyle labelStyle;
  final EdgeInsets padding;
  final bool expand;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final FieldNotesShadows shadows = context.shadows;
    final Widget face = SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.coral,
          border: shadows.outline,
          borderRadius: borderRadius,
          boxShadow: shadows.emphasis,
        ),
        child: Padding(
          padding: padding,
          child: Center(
            widthFactor: expand ? null : 1,
            child: ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
          ),
        ),
      ),
    );
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
                borderRadius: borderRadius,
                child: face,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingTextButton extends StatelessWidget {
  const OnboardingTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.style,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final TextStyle style;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: Opacity(
        opacity: enabled ? 1 : _disabledOpacity,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: FocusRing(
            enabled: enabled,
            onPressed: onPressed,
            borderRadius: const BorderRadius.all(
              Radius.circular(Shapes.radiusXs),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _minTapTarget,
                minHeight: _minTapTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
      ),
    );
  }
}
