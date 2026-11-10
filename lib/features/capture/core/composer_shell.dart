import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/app/shell/windows_caption_buttons.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/immersive/immersive_route.dart'
    show immersiveFadeFor;
import 'package:field_notes/features/capture/immersive/stage_phase.dart'
    show stageLayoutOf;

const double composerPanelWidth = 640;
const double composerPanelMaxWidth = 1000;
const double composerPanelWidthShare = 0.6;

const Key composerPanelKey = ValueKey<String>('composer-panel');
const Key composerTopBandKey = ValueKey<String>('composer-top-band');

const double composerPanelBorderWidth = 2;

const double composerPanelMargin = 28;

const double composerPanelRoomyHeight = 560;

double composerPanelMarginFor(double available) =>
    available.isFinite && available < composerPanelRoomyHeight
    ? 0
    : composerPanelMargin;
const double _scrimBlurSigma = 3.5;

const RadialGradient _scrimGradient = RadialGradient(
  center: Alignment(0, -0.36),
  radius: 1.2,
  colors: <Color>[Color(0x5C2A2016), Color(0x9E1C140C)],
);

double composerPanelWidthFor(double window) => clampDouble(
  window * composerPanelWidthShare,
  composerPanelWidth,
  composerPanelMaxWidth,
);

const Color _clearBarrier = Color(0x00000000);

const Color _paperChrome = Color(0xFF554737);
const Color _paperMote = Color(0xFFB8566A);
const Color _paperCaret = Color(0xFFB8566A);
const Color _roomChrome = Color(0xFFB7A58C);
const Color _roomStatus = Color(0xFFDCCAB0);
const Color _roomMote = Color(0xFFF3D8BE);
const Color _roomCaret = Color(0xFFE3889A);
const double _paperGlowAlpha = 0.16;
const double _roomGlowAlpha = 0.17;
const double _paperLineAlpha = 0.32;
const double _roomLineAlpha = 0.28;
const double _groundFocusY = 0.38;
const double _groundWidthReach = 1.2;
const double _groundHeightReach = 0.9;
const Size _glowSize = Size(760, 520);

@immutable
final class ComposerStageInks {
  const ComposerStageInks._({
    required this.ground,
    required this.groundEdge,
    required this.ink,
    required this.chrome,
    required this.status,
    required this.line,
    required this.glow,
    required this.mote,
    required this.caret,
    required this.focus,
  });

  factory ComposerStageInks.of(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = colors.mediaCta;
    return ComposerStageInks._(
      ground: colors.viewerStage,
      groundEdge: colors.viewerStageEdge,
      ink: ink,
      chrome: dark ? _roomChrome : _paperChrome,
      status: dark ? _roomStatus : ink,
      line: ink.withValues(alpha: dark ? _roomLineAlpha : _paperLineAlpha),
      glow: Palette.coral.withValues(
        alpha: dark ? _roomGlowAlpha : _paperGlowAlpha,
      ),
      mote: dark ? _roomMote : _paperMote,
      caret: dark ? _roomCaret : _paperCaret,
      focus: dark ? Palette.focusRingOnDark : ink,
    );
  }

  final Color ground;
  final Color groundEdge;
  final Color ink;
  final Color chrome;
  final Color status;
  final Color line;
  final Color glow;
  final Color mote;
  final Color caret;
  final Color focus;
}

Future<T?> showComposerRoute<T>(
  BuildContext context, {
  required String barrierLabel,
  required Widget child,
}) {
  final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: barrierLabel,
    barrierColor: _clearBarrier,
    transitionDuration: still
        ? Duration.zero
        : immersiveFadeFor(stageLayoutOf(context)),
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return DialogHost(
            child: ComposerShell(responsive: true, child: child),
          );
        },
    transitionBuilder: _fadeIn,
  );
}

Widget _fadeIn(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.ease),
    child: child,
  );
}

class ComposerShell extends StatelessWidget {
  const ComposerShell({
    super.key,
    required this.child,
    this.maxWidth = composerPanelWidth,
    this.closeOnScrimTap = false,
    this.responsive = false,
  });

  final Widget child;
  final double maxWidth;
  final bool closeOnScrimTap;
  final bool responsive;

  @override
  Widget build(BuildContext context) {
    if (responsive) {
      return _room(context);
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(child: _scrim(context)),
        Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top,
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: MediaQuery(
            data: MediaQuery.of(context)
                .removeViewInsets(removeBottom: true)
                .removePadding(removeTop: true),
            child: Center(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: composerPanelMarginFor(constraints.maxHeight),
                    ),
                    child: SizedBox(
                      width: math.min(maxWidth, constraints.maxWidth),
                      child: _panel(context),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scrim(BuildContext context) {
    if (!closeOnScrimTap) {
      return const _ComposerScrim();
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: () => Navigator.maybePop(context),
      child: const _ComposerScrim(),
    );
  }

  Widget _room(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool sidebar = stageLayoutOf(context) == ShellLayout.sidebar;
    final Widget room = ColoredBox(
      key: composerPanelKey,
      color: context.colors.viewerStage,
      child: sidebar ? _belowDragBand(context) : child,
    );
    if (sidebar) {
      return DarkCaptionSurface(dark: dark, child: room);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: room,
    );
  }

  Widget _belowDragBand(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(top: shellTitleBarHeight),
            ),
            child: child,
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: WindowDragBand(
            key: composerTopBandKey,
            height: shellTitleBarHeight,
          ),
        ),
      ],
    );
  }

  Widget _panel(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Container(
      key: composerPanelKey,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: colors.composerPaper,
        border: Border.all(color: colors.line, width: composerPanelBorderWidth),
        borderRadius: BorderRadius.circular(Shapes.radiusXl),
        boxShadow: Shadows.panelLift,
      ),
      child: child,
    );
  }
}

class ComposerStageGround extends StatelessWidget {
  const ComposerStageGround({super.key, required this.typing});

  final Listenable typing;

  @override
  Widget build(BuildContext context) {
    final ComposerStageInks inks = ComposerStageInks.of(context);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RepaintBoundary(
            child: CustomPaint(painter: _GroundPainter(inks: inks)),
          ),
          RepaintBoundary(
            child: _Motes(typing: typing, color: inks.mote),
          ),
        ],
      ),
    );
  }
}

class _GroundPainter extends CustomPainter {
  const _GroundPainter({required this.inks});

  final ComposerStageInks inks;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final Rect bounds = Offset.zero & size;
    final Offset focus = Offset(size.width / 2, size.height * _groundFocusY);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = _ellipse(
          focus,
          size.width * _groundWidthReach,
          size.height * _groundHeightReach,
          inks.ground,
          inks.groundEdge,
        ),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = _ellipse(
          size.center(Offset.zero),
          _glowSize.width / 2,
          _glowSize.height / 2,
          inks.glow,
          inks.glow.withValues(alpha: 0),
        ),
    );
  }

  ui.Shader _ellipse(
    Offset centre,
    double reachX,
    double reachY,
    Color inner,
    Color outer,
  ) {
    return ui.Gradient.radial(
      Offset.zero,
      1,
      <Color>[inner, outer],
      const <double>[0, 1],
      TileMode.clamp,
      Matrix4.translationValues(
        centre.dx,
        centre.dy,
        0,
      ).multiplied(Matrix4.diagonal3Values(reachX, reachY, 1)).storage,
    );
  }

  @override
  bool shouldRepaint(_GroundPainter oldDelegate) => oldDelegate.inks != inks;
}

const int _moteCount = 14;
const double _moteRadius = 2;
const double _moteRestOpacity = 0.15;
const double _moteTypingOpacity = 0.75;
const double _moteEnergyPerKey = 0.22;
const double _moteEnergyFadePerSecond = 0.5;
const double _moteLowOffset = 12;
const double _moteTravel = 26;

class _Motes extends StatefulWidget {
  const _Motes({required this.typing, required this.color});

  final Listenable typing;
  final Color color;

  @override
  State<_Motes> createState() => _MotesState();
}

class _MotesState extends State<_Motes> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<int> _frames = ValueNotifier<int>(0);
  bool _still = false;
  double _energy = 0;
  double _seconds = 0;
  Duration _lastFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.typing.addListener(_pulse);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _settle();
    }
  }

  @override
  void didUpdateWidget(_Motes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.typing, widget.typing)) {
      oldWidget.typing.removeListener(_pulse);
      widget.typing.addListener(_pulse);
    }
  }

  @override
  void dispose() {
    widget.typing.removeListener(_pulse);
    _ticker.dispose();
    _frames.dispose();
    super.dispose();
  }

  void _pulse() {
    if (_still) {
      return;
    }
    _energy = math.min(1, _energy + _moteEnergyPerKey);
    if (!_ticker.isActive) {
      _lastFrame = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final double delta =
        (elapsed - _lastFrame).inMicroseconds / Duration.microsecondsPerSecond;
    _lastFrame = elapsed;
    _seconds += delta;
    _energy = math.max(0, _energy - delta * _moteEnergyFadePerSecond);
    _frames.value += 1;
    if (_energy == 0) {
      _ticker.stop();
    }
  }

  void _settle() {
    _ticker.stop();
    _energy = 0;
    _frames.value += 1;
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MotesPainter(
        repaint: _frames,
        color: widget.color,
        energy: () => _energy,
        seconds: () => _seconds,
      ),
    );
  }
}

class _MotesPainter extends CustomPainter {
  _MotesPainter({
    required super.repaint,
    required this.color,
    required this.energy,
    required this.seconds,
  });

  final Color color;
  final ValueGetter<double> energy;
  final ValueGetter<double> seconds;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color.withValues(
        alpha: _moteRestOpacity + energy() * _moteTypingOpacity,
      );
    final double now = seconds();
    for (int index = 0; index < _moteCount; index++) {
      final double x = ((index * 53 + 7) % 100) / 100 * size.width;
      final double y = ((index * 37 + 19) % 100) / 100 * size.height;
      final double period = 5.0 + index % 5;
      final double swing =
          (1 - math.cos(math.pi * (now + index * 0.9) / period)) / 2;
      canvas.drawCircle(
        Offset(x, y + _moteLowOffset - _moteTravel * swing),
        _moteRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MotesPainter oldDelegate) => oldDelegate.color != color;
}

class _ComposerScrim extends StatelessWidget {
  const _ComposerScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
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
