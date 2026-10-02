import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';

const double _minTapTarget = 48;
const double _disabledOpacity = 0.45;
const double _trailingGap = 8;

const TextStyle _primaryLabel = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: Palette.onAccent,
);

const EdgeInsets _sidebarHeadingPadding = EdgeInsets.fromLTRB(40, 36, 40, 0);
const EdgeInsets _bottomBarHeadingPadding = EdgeInsets.fromLTRB(18, 16, 18, 0);

class OnboardingHeading extends StatelessWidget {
  const OnboardingHeading({
    super.key,
    required this.layout,
    required this.kicker,
    required this.title,
  });

  final ShellLayout layout;
  final String kicker;
  final String title;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool sidebar = layout == ShellLayout.sidebar;
    final TextAlign align = sidebar ? TextAlign.center : TextAlign.start;
    return Padding(
      padding: sidebar ? _sidebarHeadingPadding : _bottomBarHeadingPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: sidebar
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            kicker,
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
              title,
              textAlign: align,
              style: TextStyle(
                fontFamily: TypographyTokens.serif,
                fontSize: sidebar ? 44 : 26,
                fontWeight: FontWeight.w500,
                height: sidebar ? 1.05 : 1.08,
                color: colors.ink,
              ),
            ),
          ),
        ],
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
    this.trailing,
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
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final FieldNotesShadows shadows = context.shadows;
    final String? trailingGlyph = trailing;
    final Widget text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: labelStyle,
    );
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
              child: trailingGlyph == null
                  ? text
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(child: text),
                        const SizedBox(width: _trailingGap),
                        Text(trailingGlyph, maxLines: 1, style: labelStyle),
                      ],
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
