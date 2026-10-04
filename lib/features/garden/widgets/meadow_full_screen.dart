import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/app/shell/system_bars.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/typography.dart';
import 'package:field_notes/features/garden/garden_screen.dart';
import 'package:field_notes/features/garden/model/meadow_time_of_day.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/sky/sky_astronomy.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/garden_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_study_controls.dart';
import 'package:field_notes/features/settings/settings_providers.dart';

const Duration meadowFullScreenFade = Duration(milliseconds: 350);
const String meadowFullScreenCloseLabel = 'Leave full screen';
const String meadowFullScreenPlayLabel = meadowPlayTheDayLabel;
const String meadowFullScreenPauseLabel = meadowPauseLabel;
const ValueKey<String> meadowFullScreenCloseKey = ValueKey<String>(
  'meadow-full-screen-close',
);
const ValueKey<String> meadowFullScreenPlayKey = ValueKey<String>(
  'meadow-full-screen-play',
);
const ValueKey<String> meadowFullScreenRowKey = ValueKey<String>(
  'meadow-full-screen-row',
);
const Key meadowFullScreenTitleKey = ValueKey<String>(
  'meadow-full-screen-title',
);
const Color meadowFullScreenBackdrop = Color(0xFF1C1713);

const Color _labelShadow = Color.fromRGBO(0, 0, 0, 0.35);
const double _labelLeft = 14;
const double _labelTop = 40;
const double _rowInset = 12;
const double _rowLift = 12;
const double _rowGap = 8;
const double _overlayGap = 12;
const TextStyle _labelStyle = TextStyle(
  fontFamily: TypographyTokens.accent,
  fontSize: 22,
  fontWeight: FontWeight.w700,
  color: meadowCream,
  shadows: <Shadow>[
    Shadow(color: _labelShadow, offset: Offset(0, 1), blurRadius: 8),
  ],
);

int _minutesOf(DateTime instant) {
  final DateTime local = instant.toLocal();
  return local.hour * 60 + local.minute;
}

Future<void> openMeadowFullScreen(
  BuildContext context, {
  required MeadowFullScreenRequest request,
  required MeadowYear year,
  required int seed,
  required bool compact,
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
          ) => _FullScreenRoute(
            child: compact
                ? _PhoneFullScreen(request: request, year: year, seed: seed)
                : GardenScreen(fullScreen: request),
          ),
      transitionsBuilder: (
        BuildContext routeContext,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) => FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _FullScreenRoute extends ConsumerStatefulWidget {
  const _FullScreenRoute({required this.child});

  final Widget child;

  @override
  ConsumerState<_FullScreenRoute> createState() => _FullScreenRouteState();
}

class _FullScreenRouteState extends ConsumerState<_FullScreenRoute> {
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
    return PopScope<Object?>(
      onPopInvokedWithResult: _popped,
      child: DialogHost(
        child: ColoredBox(color: meadowFullScreenBackdrop, child: widget.child),
      ),
    );
  }
}

class _PhoneFullScreen extends ConsumerStatefulWidget {
  const _PhoneFullScreen({
    required this.request,
    required this.year,
    required this.seed,
  });

  final MeadowFullScreenRequest request;
  final MeadowYear year;
  final int seed;

  @override
  ConsumerState<_PhoneFullScreen> createState() => _PhoneFullScreenState();
}

class _PhoneFullScreenState extends ConsumerState<_PhoneFullScreen>
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
    final SkyMoment moment = ref.watch(skyTimeProvider);
    final SkyLocation location =
        ref.watch(skyLocationProvider).value ??
        resolveSkyLocation(null, DateTime.now().timeZoneOffset);
    final int? hour = _hour;
    final DateTime instant = hour == null
        ? moment.instant
        : meadowTodayAt(ref.watch(skyClockProvider)(), hour);
    final SkyScene sky = skySceneAt(
      instant,
      location.latitude,
      location.longitude,
    );
    final bool morning =
        sunPosition(instant, location.latitude, location.longitude).azimuth < 0;
    final bool pausesWhenInactive = ref.watch(meadowPausesWhenInactiveProvider);
    final bool playing = _player.playing;
    final String playLabel = playing
        ? meadowFullScreenPauseLabel
        : meadowFullScreenPlayLabel;
    final double gesture = MediaQuery.viewPaddingOf(context).bottom;
    final double rowBottom = gesture + _rowLift;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarsOverColor(sky.skyTop),
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _handleKey,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            MeadowStage(
              year: widget.year,
              seed: widget.seed,
              sky: sky,
              morning: morning,
              mode: MeadowSceneMode.full,
              compact: true,
              growthPoint: widget.request.growthPoint,
              overlayBottom: rowBottom + meadowPhoneControlHeight + _overlayGap,
              pausesWhenInactive: pausesWhenInactive,
            ),
            Positioned(
              left: _labelLeft,
              top: _labelTop,
              right: _labelLeft,
              child: IgnorePointer(
                child: Text(
                  key: meadowFullScreenTitleKey,
                  '${widget.year.year}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle,
                ),
              ),
            ),
            Positioned(
              left: _rowInset,
              right: _rowInset,
              bottom: rowBottom,
              child: MeadowChromeBlock(
                child: Row(
                  key: meadowFullScreenRowKey,
                  children: <Widget>[
                    Expanded(
                      child: MeadowGlassButton(
                        key: meadowFullScreenPlayKey,
                        label: playLabel,
                        tooltip: meadowFullScreenPlayLabel,
                        onPressed: () =>
                            _togglePlay(hour ?? _minutesOf(moment.instant)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            CustomPaint(
                              size: const Size.square(12),
                              painter: MeadowPlayGlyphPainter(
                                glyph: playing
                                    ? MeadowPlayGlyph.pause
                                    : MeadowPlayGlyph.play,
                                color: meadowCream,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              playLabel,
                              maxLines: 1,
                              softWrap: false,
                              style: meadowSans(13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: _rowGap),
                    MeadowGlassButton(
                      key: meadowFullScreenCloseKey,
                      label: meadowFullScreenCloseLabel,
                      tooltip: meadowFullScreenCloseLabel,
                      width: meadowPhoneControlHeight,
                      onPressed: _close,
                      child: MeadowGlyph(
                        path: meadowCross,
                        size: 16,
                        stroke: 2.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
