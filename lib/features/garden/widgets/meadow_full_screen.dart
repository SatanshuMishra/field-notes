import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/typography.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/sky/sky_astronomy.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_study_controls.dart';

const Duration meadowFullScreenFade = Duration(milliseconds: 350);
const String meadowFullScreenCloseLabel = 'Leave full screen';
const String meadowFullScreenPlayLabel = 'Play the day';
const String meadowFullScreenPauseLabel = 'Pause';
const ValueKey<String> meadowFullScreenCloseKey = ValueKey<String>(
  'meadow-full-screen-close',
);
const ValueKey<String> meadowFullScreenPlayKey = ValueKey<String>(
  'meadow-full-screen-play',
);
const Color meadowFullScreenBackdrop = Color(0xFF1C1713);

const Color _glassFill = Color.fromRGBO(28, 22, 16, 0.45);
const Color _glassEdge = Color.fromRGBO(251, 243, 228, 0.55);
const Color _glassInk = Color.fromRGBO(251, 243, 228, 1);
const Color _labelShadow = Color.fromRGBO(0, 0, 0, 0.35);
const double _glassRadius = 11;
const double _glassBorder = 1.5;
const double _glassBlurSigma = 3;
const double _minTapTarget = 48;
const double _closeSize = 34;
const double _closeGlyphSize = 14;
const double _closeStroke = 2.4;
const double _playGlyphSize = 11;
const double _playGlyphGap = 6;
const double _labelGap = 10;
const double _buttonGap = 8;
const double _targetSlack = (_minTapTarget - _closeSize) / 2;
const EdgeInsets _sidebarBarPadding = EdgeInsets.fromLTRB(
  18,
  16 - _targetSlack,
  18 - _targetSlack,
  0,
);
const EdgeInsets _compactBarPadding = EdgeInsets.fromLTRB(
  14,
  40 - _targetSlack,
  14 - _targetSlack,
  0,
);
const EdgeInsets _playPadding = EdgeInsets.symmetric(
  horizontal: 11 + _glassBorder,
  vertical: 7 + _glassBorder,
);
const BorderRadius _glassCorners = BorderRadius.all(
  Radius.circular(_glassRadius),
);
const TextStyle _labelStyle = TextStyle(
  fontFamily: TypographyTokens.accent,
  fontSize: 22,
  fontWeight: FontWeight.w700,
  color: _glassInk,
  shadows: <Shadow>[
    Shadow(color: _labelShadow, offset: Offset(0, 1), blurRadius: 8),
  ],
);
const TextStyle _buttonStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: _glassInk,
);

String _labelOf({
  required int year,
  required bool compact,
  required bool isCurrentYear,
  required bool growing,
}) {
  if (compact) {
    return '$year';
  }
  if (!isCurrentYear) {
    return 'Meadow study · $year';
  }
  return growing
      ? 'Your meadow · $year · still growing'
      : 'Your meadow · $year';
}

int _minutesOf(DateTime instant) {
  final DateTime local = instant.toLocal();
  return local.hour * 60 + local.minute;
}

DateTime _todayAt(DateTime today, int minutes) {
  final DateTime local = today.toLocal();
  return DateTime(
    local.year,
    local.month,
    local.day,
    minutes ~/ 60,
    minutes % 60,
  );
}

Future<void> openMeadowFullScreen(
  BuildContext context, {
  required MeadowFullScreenRequest request,
  required MeadowYear year,
  required int seed,
  required bool compact,
  required bool isCurrentYear,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: meadowFullScreenFade,
      reverseTransitionDuration: meadowFullScreenFade,
      pageBuilder:
          (
            BuildContext routeContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) => _MeadowFullScreen(
            request: request,
            year: year,
            seed: seed,
            compact: compact,
            isCurrentYear: isCurrentYear,
          ),
      transitionsBuilder:
          (
            BuildContext routeContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) => FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _MeadowFullScreen extends ConsumerStatefulWidget {
  const _MeadowFullScreen({
    required this.request,
    required this.year,
    required this.seed,
    required this.compact,
    required this.isCurrentYear,
  });

  final MeadowFullScreenRequest request;
  final MeadowYear year;
  final int seed;
  final bool compact;
  final bool isCurrentYear;

  @override
  ConsumerState<_MeadowFullScreen> createState() => _MeadowFullScreenState();
}

class _MeadowFullScreenState extends ConsumerState<_MeadowFullScreen>
    with SingleTickerProviderStateMixin {
  late final MeadowDayPlayer _player;
  late int? _hour = widget.request.hourMinutes;

  @override
  void initState() {
    super.initState();
    _player = MeadowDayPlayer(vsync: this, onHour: _showHour);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _showHour(int? minutes) => setState(() => _hour = minutes);

  void _togglePlay(int fromMinutes) {
    setState(() => _player.toggle(fromMinutes));
  }

  void _close() {
    if (ModalRoute.isCurrentOf(context) ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _dismissed() {
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (route == null || !route.isActive) {
      return;
    }
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  void _popped(bool didPop, Object? result) {
    if (!didPop || ref.read(meadowViewStateProvider).fullScreen == null) {
      return;
    }
    ref.read(meadowViewStateProvider.notifier).closeFullScreen();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MeadowFullScreenRequest?>(
      meadowViewStateProvider.select((MeadowView view) => view.fullScreen),
      (MeadowFullScreenRequest? previous, MeadowFullScreenRequest? next) {
        if (previous != null && next == null) {
          _dismissed();
        }
      },
    );
    ref.listen<bool>(skyDebugControlsProvider, (bool? previous, bool next) {
      if (!next && _player.playing) {
        setState(_player.pause);
      }
    });
    final SkyMoment moment = ref.watch(skyTimeProvider);
    final SkyLocation location =
        ref.watch(skyLocationProvider).value ??
        resolveSkyLocation(null, DateTime.now().timeZoneOffset);
    final bool debugControls = ref.watch(skyDebugControlsProvider);
    final int? hour = _hour;
    final DateTime instant = hour == null
        ? moment.instant
        : _todayAt(ref.watch(skyClockProvider)(), hour);
    final SkyScene sky = skySceneAt(
      instant,
      location.latitude,
      location.longitude,
    );
    final bool morning =
        sunPosition(instant, location.latitude, location.longitude).azimuth < 0;
    final bool playing = _player.playing;
    final String label = _labelOf(
      year: widget.year.year,
      compact: widget.compact,
      isCurrentYear: widget.isCurrentYear,
      growing: widget.request.growthPoint < widget.year.daysInYear,
    );
    return PopScope<Object?>(
      onPopInvokedWithResult: _popped,
      child: DialogHost(
        child: Focus(
          autofocus: true,
          skipTraversal: true,
          includeSemantics: false,
          onKeyEvent: _handleKey,
          child: ColoredBox(
            color: meadowFullScreenBackdrop,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                MeadowStage(
                  year: widget.year,
                  seed: widget.seed,
                  sky: sky,
                  morning: morning,
                  mode: MeadowSceneMode.full,
                  compact: widget.compact,
                  growthPoint: widget.request.growthPoint,
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  child: Padding(
                    padding: widget.compact
                        ? _compactBarPadding
                        : _sidebarBarPadding,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: IgnorePointer(
                            child: Text(
                              label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: _labelStyle,
                            ),
                          ),
                        ),
                        const SizedBox(width: _labelGap),
                        if (debugControls) ...<Widget>[
                          _GlassButton(
                            key: meadowFullScreenPlayKey,
                            label: playing
                                ? meadowFullScreenPauseLabel
                                : meadowFullScreenPlayLabel,
                            onPressed: () =>
                                _togglePlay(hour ?? _minutesOf(moment.instant)),
                            child: Padding(
                              padding: _playPadding,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  CustomPaint(
                                    size: const Size.square(_playGlyphSize),
                                    painter: _PlayGlyphPainter(pause: playing),
                                  ),
                                  const SizedBox(width: _playGlyphGap),
                                  Text(
                                    playing
                                        ? meadowFullScreenPauseLabel
                                        : meadowFullScreenPlayLabel,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: _buttonStyle,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: _buttonGap - _targetSlack),
                        ],
                        _GlassButton(
                          key: meadowFullScreenCloseKey,
                          label: meadowFullScreenCloseLabel,
                          onPressed: _close,
                          child: const SizedBox.square(
                            dimension: _closeSize,
                            child: Center(
                              child: CustomPaint(
                                size: Size.square(_closeGlyphSize),
                                painter: _CloseGlyphPainter(),
                              ),
                            ),
                          ),
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
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.child,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
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
                onPressed: onPressed,
                surface: FocusRingSurface.dark,
                borderRadius: _glassCorners,
                child: ClipRRect(
                  borderRadius: _glassCorners,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: _glassBlurSigma,
                      sigmaY: _glassBlurSigma,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _glassFill,
                        border: Border.all(
                          color: _glassEdge,
                          width: _glassBorder,
                        ),
                        borderRadius: _glassCorners,
                      ),
                      child: ExcludeSemantics(child: child),
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

class _CloseGlyphPainter extends CustomPainter {
  const _CloseGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 24;
    final Paint stroke = Paint()
      ..color = _glassInk
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _closeStroke;
    canvas.save();
    canvas.scale(scale);
    canvas.drawLine(const Offset(6, 6), const Offset(18, 18), stroke);
    canvas.drawLine(const Offset(18, 6), const Offset(6, 18), stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CloseGlyphPainter oldDelegate) => false;
}

class _PlayGlyphPainter extends CustomPainter {
  const _PlayGlyphPainter({required this.pause});

  final bool pause;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 24;
    final Paint fill = Paint()..color = _glassInk;
    canvas.save();
    canvas.scale(scale);
    if (pause) {
      canvas.drawRRect(
        RRect.fromLTRBR(6, 5, 10, 19, const Radius.circular(1)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromLTRBR(14, 5, 18, 19, const Radius.circular(1)),
        fill,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(3, 5.5)
          ..lineTo(12, 12)
          ..lineTo(3, 18.5)
          ..close()
          ..moveTo(12, 5.5)
          ..lineTo(21, 12)
          ..lineTo(12, 18.5)
          ..close(),
        fill,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlayGlyphPainter oldDelegate) =>
      pause != oldDelegate.pause;
}
