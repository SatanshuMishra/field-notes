import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/tokens/tokens.dart';

const String windowsMinimizeLabel = 'Minimize';
const String windowsMaximizeLabel = 'Maximize';
const String windowsRestoreLabel = 'Restore Down';
const String windowsCloseLabel = 'Close';

const Key windowsMinimizeButtonKey = ValueKey<String>('windows-minimize');
const Key windowsMaximizeButtonKey = ValueKey<String>('windows-maximize');
const Key windowsCloseButtonKey = ValueKey<String>('windows-close');

const double windowsCaptionGlyphSize = 10;

const Color _black = Color(0xFF000000);
const Color _white = Color(0xFFFFFFFF);
const Color _closeRed = Color(0xFFC42B1C);
const double _lightHoverAlpha = 0.0373;
const double _darkHoverAlpha = 0.0605;
const double _lightPressedAlpha = 0.0241;
const double _darkPressedAlpha = 0.0419;
const double _closePressedAlpha = 0.9;
const double _closePressedGlyphAlpha = 0.7;
const double _inactiveGlyphAlpha = 0.4;
const double _glyphStroke = 1;
const double _halfStroke = _glyphStroke / 2;
const double _restoreSquare = 8;
const double _restoreOffset = windowsCaptionGlyphSize - _restoreSquare;

enum WindowsCaptionGlyphKind { minimize, maximize, restore, close }

class WindowsWindowFrame extends StatefulWidget {
  const WindowsWindowFrame({super.key, required this.child});

  final Widget child;

  @override
  State<WindowsWindowFrame> createState() => _WindowsWindowFrameState();
}

class _WindowsWindowFrameState extends State<WindowsWindowFrame> {
  final ValueNotifier<int> _darkSurfaces = ValueNotifier<int>(0);

  @override
  void dispose() {
    _darkSurfaces.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DarkCaptionScope(
      surfaces: _darkSurfaces,
      child: ValueListenableBuilder<WindowState>(
        valueListenable: WindowStateChannel.instance.state,
        builder: (BuildContext context, WindowState state, Widget? child) {
          return Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              child!,
              const Positioned(
                top: 0,
                right: 0,
                child: WindowsCaptionButtons(),
              ),
              if (!state.maximized)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: windowsCaptionButtonsWidth,
                  height: windowResizeBandHeight,
                  child: _TopResizeBand(),
                ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _DarkCaptionScope extends InheritedWidget {
  const _DarkCaptionScope({required this.surfaces, required super.child});

  final ValueNotifier<int> surfaces;

  @override
  bool updateShouldNotify(_DarkCaptionScope oldWidget) =>
      surfaces != oldWidget.surfaces;
}

class DarkCaptionSurface extends StatefulWidget {
  const DarkCaptionSurface({super.key, this.dark = true, required this.child});

  final bool dark;
  final Widget child;

  @override
  State<DarkCaptionSurface> createState() => _DarkCaptionSurfaceState();
}

class _DarkCaptionSurfaceState extends State<DarkCaptionSurface> {
  ValueNotifier<int>? _surfaces;
  bool _counted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _surfaces ??= context
        .getInheritedWidgetOfExactType<_DarkCaptionScope>()
        ?.surfaces;
    _sync();
  }

  @override
  void didUpdateWidget(DarkCaptionSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final ValueNotifier<int>? surfaces = _surfaces;
    if (surfaces == null || widget.dark == _counted) {
      return;
    }
    _counted = widget.dark;
    surfaces.value += _counted ? 1 : -1;
  }

  @override
  void dispose() {
    final ValueNotifier<int>? surfaces = _surfaces;
    if (surfaces != null && _counted) {
      surfaces.value -= 1;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TopResizeBand extends StatelessWidget {
  const _TopResizeBand();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onPanStart: (DragStartDetails _) => unawaited(startWindowResize('top')),
      ),
    );
  }
}

class WindowsCaptionButtons extends StatefulWidget {
  const WindowsCaptionButtons({super.key, this.channel});

  final WindowStateChannel? channel;

  @override
  State<WindowsCaptionButtons> createState() => _WindowsCaptionButtonsState();
}

class _WindowsCaptionButtonsState extends State<WindowsCaptionButtons> {
  ValueNotifier<int>? _surfaces;
  bool _overDark = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ValueNotifier<int>? surfaces = context
        .getInheritedWidgetOfExactType<_DarkCaptionScope>()
        ?.surfaces;
    if (identical(surfaces, _surfaces)) {
      return;
    }
    _surfaces?.removeListener(_surfacesChanged);
    surfaces?.addListener(_surfacesChanged);
    _surfaces = surfaces;
    _overDark = (surfaces?.value ?? 0) > 0;
  }

  @override
  void dispose() {
    _surfaces?.removeListener(_surfacesChanged);
    super.dispose();
  }

  void _surfacesChanged() {
    SchedulerBinding.instance.addPostFrameCallback(
      (Duration _) => _syncSurfaces(),
    );
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _syncSurfaces() {
    if (!mounted) {
      return;
    }
    final bool overDark = (_surfaces?.value ?? 0) > 0;
    if (overDark != _overDark) {
      setState(() => _overDark = overDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final _CaptionPalette palette = _CaptionPalette.of(
      context,
      overDark: _overDark,
    );
    return ValueListenableBuilder<WindowState>(
      valueListenable: (widget.channel ?? WindowStateChannel.instance).state,
      builder: (BuildContext context, WindowState state, Widget? _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _CaptionButton(
              key: windowsMinimizeButtonKey,
              glyph: WindowsCaptionGlyphKind.minimize,
              label: windowsMinimizeLabel,
              onTap: minimizeWindow,
              palette: palette,
              active: state.active,
            ),
            _CaptionButton(
              key: windowsMaximizeButtonKey,
              glyph: state.maximized
                  ? WindowsCaptionGlyphKind.restore
                  : WindowsCaptionGlyphKind.maximize,
              label: state.maximized
                  ? windowsRestoreLabel
                  : windowsMaximizeLabel,
              onTap: maximizeOrRestoreWindow,
              palette: palette,
              active: state.active,
            ),
            _CaptionButton(
              key: windowsCloseButtonKey,
              glyph: WindowsCaptionGlyphKind.close,
              label: windowsCloseLabel,
              onTap: closeWindow,
              palette: palette,
              active: state.active,
              close: true,
            ),
          ],
        );
      },
    );
  }
}

@immutable
final class _CaptionPalette {
  const _CaptionPalette({
    required this.glyph,
    required this.hover,
    required this.pressed,
  });

  factory _CaptionPalette.of(BuildContext context, {required bool overDark}) {
    final bool dark =
        overDark || Theme.of(context).brightness == Brightness.dark;
    return _CaptionPalette(
      glyph: overDark ? Palette.mediaInk : context.colors.ink,
      hover: dark
          ? _white.withValues(alpha: _darkHoverAlpha)
          : _black.withValues(alpha: _lightHoverAlpha),
      pressed: dark
          ? _white.withValues(alpha: _darkPressedAlpha)
          : _black.withValues(alpha: _lightPressedAlpha),
    );
  }

  final Color glyph;
  final Color hover;
  final Color pressed;
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    super.key,
    required this.glyph,
    required this.label,
    required this.onTap,
    required this.palette,
    required this.active,
    this.close = false,
  });

  final WindowsCaptionGlyphKind glyph;
  final String label;
  final Future<void> Function() onTap;
  final _CaptionPalette palette;
  final bool active;
  final bool close;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovered = false;
  bool _pressed = false;

  void _hover(bool hovered) {
    if (mounted && hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  void _press(bool pressed) {
    if (mounted && pressed != _pressed) {
      setState(() => _pressed = pressed);
    }
  }

  Color get _background {
    if (widget.close) {
      if (_pressed) {
        return _closeRed.withValues(alpha: _closePressedAlpha);
      }
      return _hovered ? _closeRed : const Color(0x00000000);
    }
    if (_pressed) {
      return widget.palette.pressed;
    }
    return _hovered ? widget.palette.hover : const Color(0x00000000);
  }

  Color get _glyph {
    if (widget.close && _pressed) {
      return _white.withValues(alpha: _closePressedGlyphAlpha);
    }
    if (widget.close && _hovered) {
      return _white;
    }
    if (!widget.active && !_hovered) {
      return widget.palette.glyph.withValues(alpha: _inactiveGlyphAlpha);
    }
    return widget.palette.glyph;
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: Semantics(
        container: true,
        button: true,
        label: widget.label,
        child: MouseRegion(
          onEnter: (PointerEnterEvent _) => _hover(true),
          onExit: (PointerExitEvent _) => _hover(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails _) => _press(true),
            onTapUp: (TapUpDetails _) => _press(false),
            onTapCancel: () => _press(false),
            onTap: () => unawaited(widget.onTap()),
            child: ColoredBox(
              color: _background,
              child: SizedBox(
                width: windowsCaptionButtonWidth,
                height: shellTitleBarHeight,
                child: Center(
                  child: WindowsCaptionGlyph(kind: widget.glyph, color: _glyph),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WindowsCaptionGlyph extends StatelessWidget {
  const WindowsCaptionGlyph({
    super.key,
    required this.kind,
    required this.color,
  });

  final WindowsCaptionGlyphKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: windowsCaptionGlyphSize,
      child: CustomPaint(
        painter: _CaptionGlyphPainter(kind: kind, color: color),
      ),
    );
  }
}

final class _CaptionGlyphPainter extends CustomPainter {
  const _CaptionGlyphPainter({required this.kind, required this.color});

  final WindowsCaptionGlyphKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _glyphStroke;
    switch (kind) {
      case WindowsCaptionGlyphKind.minimize:
        canvas.drawLine(
          Offset(0, size.height / 2 + _halfStroke),
          Offset(size.width, size.height / 2 + _halfStroke),
          stroke,
        );
      case WindowsCaptionGlyphKind.maximize:
        canvas.drawRect(
          Rect.fromLTRB(
            _halfStroke,
            _halfStroke,
            size.width - _halfStroke,
            size.height - _halfStroke,
          ),
          stroke,
        );
      case WindowsCaptionGlyphKind.restore:
        canvas.drawRect(
          Rect.fromLTRB(
            _halfStroke,
            _restoreOffset + _halfStroke,
            _restoreSquare - _halfStroke,
            size.height - _halfStroke,
          ),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(_restoreOffset, _halfStroke)
            ..lineTo(size.width - _halfStroke, _halfStroke)
            ..lineTo(size.width - _halfStroke, _restoreSquare),
          stroke,
        );
      case WindowsCaptionGlyphKind.close:
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), stroke);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), stroke);
    }
  }

  @override
  bool shouldRepaint(_CaptionGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
