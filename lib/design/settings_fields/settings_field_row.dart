import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

const double _sidebarControlGap = 20;
const double _sidebarDescriptionGap = 1;
const double _phoneControlGap = 16;
const double _phoneDescriptionGap = 2;
const double _phoneControlShare = 2 / 3;
const double _leadingGap = 8;
const double _markerHang = 16;
const double _markerDrop = 7;
const double _belowGap = 8;

class SettingsFieldRow extends StatelessWidget {
  const SettingsFieldRow({
    super.key,
    required this.label,
    this.description,
    required this.control,
    this.labelColor,
    this.descriptionColor,
    this.leading,
    this.marker,
    this.below,
    this.onPressed,
    this.semanticsValue,
    this.expanded,
  });

  final String label;
  final String? description;
  final Widget control;
  final Color? labelColor;
  final Color? descriptionColor;
  final Widget? leading;
  final Widget? marker;
  final Widget? below;
  final VoidCallback? onPressed;
  final String? semanticsValue;
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final ShellLayout layout = resolveShellLayout(Theme.of(context).platform);
    final bool sidebar = layout == ShellLayout.sidebar;
    final FieldNotesTextStyles textStyles = context.textStyles;
    final TextStyle labelStyle = sidebar
        ? textStyles.labelSans.copyWith(
            fontWeight: FontWeight.w600,
            color: labelColor,
          )
        : textStyles.labelSans.copyWith(color: labelColor);
    final Widget? marker = this.marker;
    final Widget? below = this.below;
    final Widget column = MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _labelLine(context, labelStyle),
          if (description != null) ...<Widget>[
            SizedBox(
              height: sidebar ? _sidebarDescriptionGap : _phoneDescriptionGap,
            ),
            Text(
              description!,
              style: textStyles.captionSans.copyWith(
                color: descriptionColor ?? context.colors.muted,
              ),
            ),
          ],
          if (below != null) ...<Widget>[
            const SizedBox(height: _belowGap),
            below,
          ],
        ],
      ),
    );
    final Widget text = marker == null
        ? column
        : Stack(
            fit: StackFit.passthrough,
            clipBehavior: Clip.none,
            children: <Widget>[
              column,
              Positioned(left: -_markerHang, top: _markerDrop, child: marker),
            ],
          );
    final VoidCallback? onPressed = this.onPressed;
    final Widget slot = onPressed == null
        ? Semantics(container: true, child: control)
        : ExcludeFocus(child: IgnorePointer(child: control));
    final Widget row = switch (layout) {
      ShellLayout.sidebar => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: text),
            const SizedBox(width: _sidebarControlGap),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
              child: slot,
            ),
          ],
        ),
      ),
      ShellLayout.bottomBar => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: text),
            const SizedBox(width: _phoneControlGap),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    math.max(0, constraints.maxWidth - _phoneControlGap) *
                    _phoneControlShare,
              ),
              child: slot,
            ),
          ],
        ),
      ),
    };
    if (onPressed == null) {
      return Semantics(container: true, child: row);
    }
    return Pressable(
      label: label,
      value: semanticsValue,
      hint: description,
      onPressed: onPressed,
      placement: FocusRingPlacement.edge,
      borderRadius: Shapes.buttonBorderRadius,
      excludeSemantics: false,
      child: Semantics(
        expanded: expanded,
        child: ExcludeSemantics(child: row),
      ),
    );
  }

  Widget _labelLine(BuildContext context, TextStyle style) {
    final Widget text = Text(label, style: style);
    final Widget? leading = this.leading;
    if (leading == null) {
      return text;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: _firstLineHeight(context, style),
          child: Center(widthFactor: 1, child: leading),
        ),
        const SizedBox(width: _leadingGap),
        Flexible(child: text),
      ],
    );
  }

  double _firstLineHeight(BuildContext context, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(style: DefaultTextStyle.of(context).style.merge(style)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    );
    final double height = painter.preferredLineHeight;
    painter.dispose();
    return height;
  }
}
