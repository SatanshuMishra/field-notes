import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/feedback/toast.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/settings_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String appearanceToggleDarkLabel = 'Switch to dark';
const String appearanceToggleLightLabel = 'Switch to light';

const Key appearanceToggleKey = ValueKey<String>('appearance-toggle');
const Key appearanceToggleMoonKey = ValueKey<String>('appearance-toggle-moon');
const Key appearanceToggleSunKey = ValueKey<String>('appearance-toggle-sun');

const double _iconViewBox = 24;
const double _iconStroke = 1.9;
const double _hoverWashAlpha = 0.08;

class _ToggleMetrics {
  const _ToggleMetrics({
    required this.targetHeight,
    required this.face,
    required this.icon,
    required this.radius,
    required this.restOpacity,
  });

  final double targetHeight;
  final double face;
  final double icon;
  final BorderRadius radius;
  final double restOpacity;
}

const _ToggleMetrics _sidebarMetrics = _ToggleMetrics(
  targetHeight: shellTitleBarHeight,
  face: 30,
  icon: 16,
  radius: BorderRadius.all(Radius.circular(9)),
  restOpacity: 0.75,
);

const _ToggleMetrics _bottomBarMetrics = _ToggleMetrics(
  targetHeight: kMinInteractiveDimension,
  face: 30,
  icon: 18,
  radius: BorderRadius.all(Radius.circular(15)),
  restOpacity: 0.8,
);

Brightness appearanceShowing(Appearance appearance, Brightness platform) =>
    switch (appearance) {
      Appearance.light => Brightness.light,
      Appearance.dark => Brightness.dark,
      Appearance.system => platform,
    };

class AppearanceToggle extends ConsumerStatefulWidget {
  const AppearanceToggle({super.key, this.ink});

  final Color? ink;

  @override
  ConsumerState<AppearanceToggle> createState() => _AppearanceToggleState();
}

class _AppearanceToggleState extends ConsumerState<AppearanceToggle> {
  bool _hovered = false;

  Brightness get _showing => appearanceShowing(
    ref.read(appearanceProvider),
    MediaQuery.platformBrightnessOf(context),
  );

  Future<void> _toggle() async {
    final Appearance next = switch (_showing) {
      Brightness.light => Appearance.dark,
      Brightness.dark => Appearance.light,
    };
    final SettingsWriteResult result = await ref
        .read(settingsControllerProvider)
        .setAppearance(next);
    if (result case SettingsWriteFailed(:final String message) when mounted) {
      showTransientToast(context, message, glyph: IconStickerGlyph.close);
    }
  }

  void _hover(bool hovered) {
    if (hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final _ToggleMetrics metrics = switch (resolveShellLayout(
      Theme.of(context).platform,
    )) {
      ShellLayout.sidebar => _sidebarMetrics,
      ShellLayout.bottomBar => _bottomBarMetrics,
    };
    final bool dark =
        appearanceShowing(
          ref.watch(appearanceProvider),
          MediaQuery.platformBrightnessOf(context),
        ) ==
        Brightness.dark;
    final String label = dark
        ? appearanceToggleLightLabel
        : appearanceToggleDarkLabel;
    final Color ink = widget.ink ?? colors.ink;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: GestureDetector(
          key: appearanceToggleKey,
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: SizedBox(
            width: kMinInteractiveDimension,
            height: metrics.targetHeight,
            child: Center(
              child: FocusRing(
                onPressed: _toggle,
                borderRadius: metrics.radius,
                child: MouseRegion(
                  onEnter: (PointerEnterEvent _) => _hover(true),
                  onExit: (PointerExitEvent _) => _hover(false),
                  child: ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: metrics.face,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _hovered
                              ? ink.withValues(alpha: _hoverWashAlpha)
                              : null,
                          borderRadius: metrics.radius,
                        ),
                        child: Center(
                          child: Opacity(
                            opacity: _hovered ? 1 : metrics.restOpacity,
                            child: SizedBox.square(
                              dimension: metrics.icon,
                              child: CustomPaint(
                                key: dark
                                    ? appearanceToggleSunKey
                                    : appearanceToggleMoonKey,
                                painter: _ModeGlyphPainter(
                                  sun: dark,
                                  color: ink,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeGlyphPainter extends CustomPainter {
  const _ModeGlyphPainter({required this.sun, required this.color});

  final bool sun;
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
    if (sun) {
      canvas
        ..drawCircle(const Offset(12, 12), 4, stroke)
        ..drawPath(_rays(), stroke);
    } else {
      canvas.drawPath(_moon(), stroke);
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

  @override
  bool shouldRepaint(_ModeGlyphPainter oldDelegate) =>
      oldDelegate.sun != sun || oldDelegate.color != color;
}
