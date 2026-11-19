import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/tokens/field_notes_colors.dart';
import 'package:field_notes/design/tokens/theme_context.dart';

import 'opening_painter.dart';

class OpeningFrame extends StatelessWidget {
  const OpeningFrame({
    super.key,
    required this.seconds,
    this.paintsPaper = true,
    this.fade = 1,
  });

  final double seconds;
  final bool paintsPaper;
  final double fade;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final ThemeData theme = Theme.of(context);
    final ShellLayout shell = resolveShellLayout(theme.platform);
    final double topInset = switch (shell) {
      ShellLayout.bottomBar => MediaQuery.viewPaddingOf(context).top,
      ShellLayout.sidebar => 0,
    };
    return SizedBox.expand(
      child: CustomPaint(
        painter: OpeningPainter(
          plan: openingPlanFor(context),
          seconds: seconds,
          paper: colors.panelTop,
          ink: colors.ink,
          brightness: theme.brightness,
          shell: shell,
          topInset: topInset,
          paintsPaper: paintsPaper,
          fade: fade,
        ),
      ),
    );
  }
}
