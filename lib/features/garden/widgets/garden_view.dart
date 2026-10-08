import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/windows_caption_buttons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/garden/model/meadow_focus.dart';
import 'package:field_notes/features/garden/model/meadow_time_of_day.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:field_notes/features/garden/widgets/meadow_desktop_page.dart';
import 'package:field_notes/features/garden/widgets/meadow_focus_stepper.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_phone_page.dart';
import 'package:field_notes/features/garden/widgets/meadow_study_controls.dart';
import 'package:field_notes/features/garden/widgets/meadow_tabs.dart';

import '../model/garden_motion.dart';
import '../sky/sky_astronomy.dart';
import '../sky/sky_location.dart';
import '../sky/sky_scene.dart';
import '../sky/sky_time.dart';
import 'garden_header.dart';

const String meadowWaitingMessage =
    'Your meadow is waiting. Every day you journal plants a bloom here.';
const double meadowSceneAspectRatio = meadowWorldWidth / meadowWorldHeight;
const Color meadowLoadingBackdrop = Color.fromRGBO(201, 207, 166, 1);
const double meadowPhoneDockLift = 12;
const double meadowPhoneOverlayLift = 60;

const Alignment _waitingAlignment = Alignment(0, 0.29);
const EdgeInsets _waitingPadding = EdgeInsets.symmetric(horizontal: 24);

bool meadowIsCompact(BuildContext context) =>
    resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar;

double meadowPhoneDockBottom(MediaQueryData media) =>
    media.viewPadding.bottom + phoneBottomBarZone + meadowPhoneDockLift;

int _minutesOf(DateTime instant) {
  final DateTime local = instant.toLocal();
  return local.hour * 60 + local.minute;
}

enum MeadowPopover { none, year, time }

@immutable
class MeadowChrome {
  const MeadowChrome({
    required this.year,
    required this.years,
    required this.current,
    required this.fullScreen,
    required this.scene,
    required this.header,
    required this.details,
    required this.stepper,
    required this.clock,
    required this.shownMinutes,
    required this.popover,
    required this.detailsOpen,
    required this.dragging,
    required this.onPopover,
    required this.onTime,
    required this.onPickYear,
    required this.onBack,
    required this.onDetails,
    required this.onFullScreen,
  });

  final MeadowYear year;
  final List<MeadowYear> years;
  final bool current;
  final bool fullScreen;
  final Widget scene;
  final Widget header;
  final Widget details;
  final Widget? stepper;
  final Widget? clock;
  final int? shownMinutes;
  final MeadowPopover popover;
  final bool detailsOpen;
  final bool dragging;
  final ValueChanged<MeadowPopover> onPopover;
  final ValueChanged<MeadowTimeOfDay> onTime;
  final ValueChanged<int> onPickYear;
  final VoidCallback onBack;
  final VoidCallback onDetails;
  final VoidCallback onFullScreen;

  bool get study => !current;

  String get timeLabel => meadowTimeOfDayLabel(shownMinutes);
}

class MeadowPage extends StatefulWidget {
  const MeadowPage({
    super.key,
    required this.year,
    required this.years,
    required this.currentYear,
    required this.seed,
    required this.moment,
    required this.today,
    required this.location,
    required this.onPickYear,
    required this.onBack,
    required this.onFullScreen,
    this.onNow,
    this.onFastForward,
    this.motion,
    this.fullScreen,
    this.pausesWhenInactive = true,
  });

  final MeadowYear year;
  final List<MeadowYear> years;
  final int currentYear;
  final int seed;
  final SkyMoment moment;
  final DateTime today;
  final SkyLocation location;
  final ValueChanged<int> onPickYear;
  final VoidCallback onBack;
  final ValueChanged<MeadowFullScreenRequest> onFullScreen;
  final VoidCallback? onNow;
  final VoidCallback? onFastForward;
  final GardenMotionProfile? motion;
  final MeadowFullScreenRequest? fullScreen;
  final bool pausesWhenInactive;

  bool get isCurrentYear => year.year == currentYear;

  @override
  State<MeadowPage> createState() => _MeadowPageState();
}

class _MeadowPageState extends State<MeadowPage> {
  final GlobalKey _stageKey = GlobalKey(debugLabel: 'meadow stage');
  final FocusNode _keys = FocusNode(debugLabel: 'meadow keys');
  MeadowRange? _highlight;
  int? _hourMinutes;
  int? _chosenMinutes;
  int? _growthPoint;
  bool _growAnimated = false;
  MeadowPopover _popover = MeadowPopover.none;
  bool _detailsOpen = false;
  MeadowDetailsTab _tab = MeadowDetailsTab.days;
  MeadowFocus? _focus;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    final MeadowFullScreenRequest? request = widget.fullScreen;
    if (request != null) {
      if (widget.isCurrentYear) {
        _chosenMinutes = request.hourMinutes;
      } else {
        _hourMinutes = request.hourMinutes;
        _growthPoint = request.growthPoint;
      }
    }
  }

  @override
  void didUpdateWidget(MeadowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year.year != widget.year.year) {
      _highlight = null;
      _hourMinutes = null;
      _chosenMinutes = null;
      _growthPoint = null;
      _growAnimated = false;
      _focus = null;
      _popover = MeadowPopover.none;
    }
  }

  @override
  void dispose() {
    _keys.dispose();
    super.dispose();
  }

  bool get _compact => meadowIsCompact(context);

  void _setHighlight(MeadowRange? range) {
    setState(() => _highlight = range);
  }

  void _setHour(int? minutes) {
    setState(() => _hourMinutes = minutes);
  }

  void _setGrowth(int point, bool growAnimated) {
    setState(() {
      _growthPoint = point;
      _growAnimated = growAnimated;
    });
  }

  void _setPopover(MeadowPopover popover) {
    setState(() => _popover = popover);
  }

  void _chooseTime(MeadowTimeOfDay time) {
    final int? minutes = time.minutes;
    setState(() {
      _chosenMinutes = minutes;
      _popover = MeadowPopover.none;
    });
    if (minutes == null) {
      widget.onNow?.call();
    } else if (widget.moment.fastForwarding) {
      widget.onFastForward?.call();
    }
  }

  void _toggleDetails() {
    if (_focus != null) {
      _leaveFocus();
      return;
    }
    setState(() {
      _detailsOpen = !_detailsOpen;
      _popover = MeadowPopover.none;
      if (!_detailsOpen) {
        _highlight = null;
      }
    });
  }

  void _setTab(MeadowDetailsTab tab) {
    setState(() => _tab = tab);
  }

  void _enterFocus(MeadowFocus? focus) {
    if (focus == null) {
      return;
    }
    setState(() {
      _focus = focus;
      _highlight = focus.range;
      _detailsOpen = false;
      _popover = MeadowPopover.none;
    });
  }

  void _focusMonth(int index) =>
      _enterFocus(MeadowFocus.month(widget.year, index));

  void _focusLandmark(int index) => _enterFocus(
    MeadowFocus.landmark(
      widget.year,
      index,
      isCurrentYear: widget.isCurrentYear,
    ),
  );

  void _stepFocus(int delta) {
    final MeadowFocus? focus = _focus;
    if (focus == null) {
      return;
    }
    final MeadowFocus next = focus.step(
      widget.year,
      delta,
      isCurrentYear: widget.isCurrentYear,
    );
    if (next != focus) {
      _enterFocus(next);
    }
  }

  void _leaveFocus() {
    setState(() {
      _focus = null;
      _highlight = null;
      _detailsOpen = true;
    });
  }

  void _dragStarted() {
    if (!_dragging) {
      setState(() => _dragging = true);
    }
  }

  void _dragEnded() {
    if (_dragging) {
      setState(() => _dragging = false);
    }
  }

  int? get _shownMinutes {
    if (!widget.isCurrentYear) {
      return _hourMinutes;
    }
    final int? chosen = _chosenMinutes;
    if (chosen != null) {
      return chosen;
    }
    return widget.moment.shifted ? _minutesOf(widget.moment.instant) : null;
  }

  int get _shownGrowth => widget.isCurrentYear
      ? widget.year.limit
      : _growthPoint ?? widget.year.limit;

  void _toggleFullScreen() {
    if (_popover != MeadowPopover.none) {
      setState(() => _popover = MeadowPopover.none);
    }
    widget.onFullScreen(
      MeadowFullScreenRequest(
        year: widget.year.year,
        hourMinutes: _shownMinutes,
        growthPoint: _shownGrowth,
      ),
    );
  }

  void _stepYear(int delta) {
    final List<MeadowYear> years = widget.years;
    final int at = years.indexWhere(
      (MeadowYear year) => year.year == widget.year.year,
    );
    final int next = at + delta;
    if (at < 0 || next < 0 || next >= years.length) {
      return;
    }
    widget.onPickYear(years[next].year);
  }

  bool get _layered =>
      _popover != MeadowPopover.none || _detailsOpen || _focus != null;

  void _closeTop() {
    if (_popover != MeadowPopover.none) {
      setState(() => _popover = MeadowPopover.none);
      return;
    }
    if (_focus != null) {
      _leaveFocus();
      return;
    }
    if (_detailsOpen) {
      setState(() {
        _detailsOpen = false;
        _highlight = null;
      });
    }
  }

  KeyEventResult _onPhoneKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _layered) {
      _closeTop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    if (keyboard.isMetaPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    final bool repeat = event is KeyRepeatEvent;
    if (_focus != null) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _stepFocus(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _stepFocus(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape && !repeat) {
        _leaveFocus();
        return KeyEventResult.handled;
      }
    }
    if (repeat) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.keyD) {
      _toggleDetails();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      _toggleFullScreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _stepYear(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _stepYear(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_popover != MeadowPopover.none || _detailsOpen) {
        setState(() {
          _popover = MeadowPopover.none;
          _detailsOpen = false;
          _highlight = null;
        });
        return KeyEventResult.handled;
      }
      if (widget.fullScreen != null) {
        _toggleFullScreen();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = _compact;
    final MeadowYear year = widget.year;
    final bool current = widget.isCurrentYear;
    final bool full = widget.fullScreen != null;
    final SkyLocation location = widget.location;
    final SkyMoment moment = widget.moment;
    final int? hour = current ? _chosenMinutes : _hourMinutes;
    final int growthPoint = _shownGrowth;
    final DateTime instant = hour == null
        ? moment.instant
        : meadowTodayAt(widget.today, hour);
    final SkyScene sky = skySceneAt(
      instant,
      location.latitude,
      location.longitude,
    );
    final bool morning =
        sunPosition(instant, location.latitude, location.longitude).azimuth < 0;
    final MeadowSceneMode mode = full
        ? MeadowSceneMode.full
        : current
        ? MeadowSceneMode.page
        : MeadowSceneMode.study;
    final SkyMoment shown = hour == null ? moment : SkyMoment(instant: instant);
    final bool empty = year.blooms + year.sprouts == 0;
    final MeadowFocus? focus = _focus;
    final Widget scene = MeadowStage(
      key: _stageKey,
      year: year,
      seed: widget.seed,
      sky: sky,
      morning: morning,
      mode: mode,
      compact: compact,
      growthPoint: current ? null : growthPoint,
      growAnimated: _growAnimated,
      highlight: _highlight,
      motion: widget.motion,
      cover: true,
      glassTips: true,
      overlayBottom: compact
          ? meadowPhoneDockBottom(MediaQuery.of(context)) +
                meadowPhoneOverlayLift
          : null,
      panTo: focus?.range,
      pausesWhenInactive: widget.pausesWhenInactive,
      onDragged: compact ? null : _dragStarted,
      onDragEnd: compact ? null : _dragEnded,
      readyOverlay: empty
          ? _WaitingMessage(
              colour: MeadowPalette.from(
                sky: sky,
                morning: morning,
                heavyShare: year.heavyShare,
              ).captionColour,
            )
          : null,
    );
    final MeadowChrome chrome = MeadowChrome(
      year: year,
      years: widget.years,
      current: current,
      fullScreen: full,
      scene: scene,
      header: MeadowHeader(
        compact: compact,
        mode: current ? MeadowSceneMode.page : MeadowSceneMode.study,
        year: year.year,
        blooms: year.blooms,
        sprouts: year.sprouts,
        weather: year.weather,
        onBack: current ? null : widget.onBack,
      ),
      details: MeadowTabs(
        key: ValueKey<int>(year.year),
        year: year,
        isCurrentYear: current,
        compact: compact,
        growthPoint: growthPoint,
        highlight: _highlight,
        onHighlight: _setHighlight,
        tab: _tab,
        onTab: _setTab,
        onClose: _toggleDetails,
        onFocusMonth: _focusMonth,
        onFocusLandmark: _focusLandmark,
      ),
      stepper: focus == null
          ? null
          : MeadowFocusStepper(
              focus: focus,
              counts: focus.countsIn(year, growthPoint: growthPoint).label,
              compact: compact,
              onStep: _stepFocus,
              onClose: _leaveFocus,
            ),
      clock: current && !compact
          ? GardenSkyClock(
              moment: shown,
              sunEvent: nextSkyEvent(
                SkyBody.sun,
                instant,
                location.latitude,
                location.longitude,
              ),
            )
          : null,
      shownMinutes: _shownMinutes,
      popover: _popover,
      detailsOpen: _detailsOpen,
      dragging: _dragging,
      onPopover: _setPopover,
      onTime: _chooseTime,
      onPickYear: widget.onPickYear,
      onBack: widget.onBack,
      onDetails: _toggleDetails,
      onFullScreen: _toggleFullScreen,
    );
    Widget layout(MeadowStudyParts? parts) => compact
        ? MeadowPhonePage(chrome: chrome, study: parts)
        : MeadowDesktopPage(chrome: chrome, study: parts);
    final Widget page = current
        ? layout(null)
        : MeadowStudyControls(
            compact: compact,
            hourMinutes: hour,
            onHour: _setHour,
            limit: year.limit,
            daysInYear: year.daysInYear,
            year: year.year,
            growthPoint: growthPoint,
            onGrowth: _setGrowth,
            moment: shown,
            builder: (BuildContext context, MeadowStudyParts parts) =>
                layout(parts),
          );
    if (compact) {
      return Focus(
        focusNode: _keys,
        autofocus: true,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _onPhoneKey,
        child: page,
      );
    }
    return Focus(
      focusNode: _keys,
      autofocus: true,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (PointerDownEvent event) {
          if (!_keys.hasFocus) {
            _keys.requestFocus();
          }
        },
        child: full
            ? DarkCaptionSurface(
                dark: meadowSkyDarkensCaptions(sky.skyTop),
                child: page,
              )
            : page,
      ),
    );
  }
}

class MeadowPageNotice extends StatelessWidget {
  const MeadowPageNotice({
    super.key,
    required this.year,
    required this.study,
    required this.child,
  });

  final int year;
  final bool study;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool compact = meadowIsCompact(context);
    final double top = compact ? MediaQuery.paddingOf(context).top : 0;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: meadowLoadingBackdrop),
        Center(child: child),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: top + (compact ? 150 : 170),
          child: const IgnorePointer(child: MeadowScrim()),
        ),
        Positioned(
          left: compact ? 18 : 26,
          right: compact ? 18 : 26,
          top: top + (compact ? 12 : 22),
          child: MeadowTitle(compact: compact, study: study, year: year),
        ),
      ],
    );
  }
}

class MeadowScrim extends StatelessWidget {
  const MeadowScrim({super.key, this.opacity = 0.5});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.fromRGBO(20, 14, 8, opacity),
            const Color.fromRGBO(20, 14, 8, 0),
          ],
        ),
      ),
    );
  }
}

class _WaitingMessage extends StatelessWidget {
  const _WaitingMessage({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _waitingAlignment,
      child: Padding(
        padding: _waitingPadding,
        child: IgnorePointer(
          child: Text(
            meadowWaitingMessage,
            textAlign: TextAlign.center,
            style: context.textStyles.bodySerif.copyWith(color: colour),
          ),
        ),
      ),
    );
  }
}
