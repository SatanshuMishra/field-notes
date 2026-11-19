import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/tokens/field_notes_colors.dart';
import 'package:field_notes/design/tokens/theme_context.dart';
import 'package:field_notes/features/onboarding/onboarding_gate.dart';

import 'opening_frame.dart';
import 'opening_painter.dart';
import 'opening_plan.dart';
import 'opening_providers.dart';

const Key openingPaperKey = ValueKey<String>('opening-paper');

const Duration _decisionWait = Duration(seconds: 1);
const Duration _exitFade = Duration(milliseconds: 250);
const Duration _paperEase = Duration(milliseconds: 200);

final Set<LogicalKeyboardKey> _passingKeys =
    Set<LogicalKeyboardKey>.unmodifiable(<LogicalKeyboardKey>{
      LogicalKeyboardKey.audioVolumeUp,
      LogicalKeyboardKey.audioVolumeDown,
      LogicalKeyboardKey.audioVolumeMute,
      LogicalKeyboardKey.mediaPlayPause,
      LogicalKeyboardKey.mediaPlay,
      LogicalKeyboardKey.mediaPause,
      LogicalKeyboardKey.mediaStop,
      LogicalKeyboardKey.mediaTrackNext,
      LogicalKeyboardKey.mediaTrackPrevious,
      LogicalKeyboardKey.mediaFastForward,
      LogicalKeyboardKey.mediaRewind,
    });

double _seconds(Duration duration) =>
    duration.inMicroseconds / Duration.microsecondsPerSecond;

double _share(Duration elapsed, Duration span) =>
    (elapsed.inMicroseconds / span.inMicroseconds).clamp(0.0, 1.0).toDouble();

class OpeningCover extends ConsumerStatefulWidget {
  const OpeningCover({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OpeningCover> createState() => _OpeningCoverState();
}

class _OpeningCoverState extends ConsumerState<OpeningCover>
    with SingleTickerProviderStateMixin {
  bool? _plays;
  bool _gone = false;
  Ticker? _ticker;
  Duration _now = Duration.zero;
  Duration? _openingAt;
  Duration? _exitAt;
  bool _decided = false;
  ProviderSubscription<AsyncValue<OnboardingVisibility>>? _gate;
  bool _handlesKeys = false;
  Set<PhysicalKeyboardKey> _heldKeys = const <PhysicalKeyboardKey>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool screenReader = MediaQuery.accessibleNavigationOf(context);
    final bool? plays = _plays;
    if (plays == null) {
      _decideOnce(ref.read(playsOpeningProvider) && !screenReader);
      return;
    }
    if (plays && screenReader && !_gone) {
      _skip();
    }
  }

  void _decideOnce(bool plays) {
    _plays = plays;
    _gone = !plays;
    if (!plays) {
      return;
    }
    FocusManager.instance.addEarlyKeyEventHandler(_onKey);
    _handlesKeys = true;
    _gate = ref.listenManual<AsyncValue<OnboardingVisibility>>(
      onboardingGateProvider,
      (
        AsyncValue<OnboardingVisibility>? previous,
        AsyncValue<OnboardingVisibility> next,
      ) => _onGate(next),
      fireImmediately: true,
    );
  }

  void _onGate(AsyncValue<OnboardingVisibility> next) {
    if (_decided) {
      return;
    }
    switch (next) {
      case AsyncData<OnboardingVisibility>(:final OnboardingVisibility value):
        _decide(value);
      case AsyncError<OnboardingVisibility>():
        _decide(OnboardingVisibility.shown);
      case AsyncLoading<OnboardingVisibility>():
        return;
    }
  }

  void _decide(OnboardingVisibility visibility) {
    _decided = true;
    _gate?.close();
    _gate = null;
    if (_exitAt != null || _gone) {
      return;
    }
    switch (visibility) {
      case OnboardingVisibility.hidden when _now < _decisionWait:
        _openingAt = _now;
      case OnboardingVisibility.hidden:
        _exitAt = _decisionWait;
      case OnboardingVisibility.shown:
        _exitAt = _now;
    }
  }

  void _skip() {
    if (_exitAt != null || _gone) {
      return;
    }
    _exitAt = _now;
  }

  OpeningPlan get _plan => openingPlanFor(context);

  Duration? get _openingElapsed {
    final Duration? openingAt = _openingAt;
    return openingAt == null ? null : _now - openingAt;
  }

  bool get _takesInput {
    if (_gone || _plays != true) {
      return false;
    }
    final Duration? opening = _openingElapsed;
    return opening == null ||
        _exitAt != null ||
        _seconds(opening) < _plan.reveal.end;
  }

  void _onTick(Duration elapsed) {
    _now = elapsed;
    final Duration? exitAt = _exitAt;
    final Duration? opening = _openingElapsed;
    if (exitAt == null && !_decided && _now >= _decisionWait) {
      _exitAt = _decisionWait;
    }
    final Duration? exit = _exitAt;
    final bool exited = exit != null && _now >= exit + _exitFade;
    final bool finished =
        exit == null && opening != null && _seconds(opening) >= _plan.total;
    if (exited || finished) {
      _leave();
    }
    _releaseKeysWhenDone();
    setState(() {});
  }

  void _leave() {
    _gone = true;
    _gate?.close();
    _gate = null;
    final Ticker? ticker = _ticker;
    _ticker = null;
    ticker?.dispose();
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (_passingKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    final PhysicalKeyboardKey key = event.physicalKey;
    if (_heldKeys.contains(key)) {
      if (event is KeyUpEvent) {
        _heldKeys = <PhysicalKeyboardKey>{
          for (final PhysicalKeyboardKey held in _heldKeys)
            if (held != key) held,
        };
        _releaseKeysWhenDone();
      }
      return KeyEventResult.handled;
    }
    if (!_takesInput) {
      return KeyEventResult.ignored;
    }
    switch (event) {
      case KeyDownEvent() || KeyRepeatEvent():
        _heldKeys = <PhysicalKeyboardKey>{..._heldKeys, key};
        _skip();
        return KeyEventResult.handled;
      case KeyUpEvent():
        return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  void _releaseKeysWhenDone() {
    if (_handlesKeys && _heldKeys.isEmpty && !_takesInput) {
      _removeKeyHandler();
    }
  }

  void _removeKeyHandler() {
    if (!_handlesKeys) {
      return;
    }
    _handlesKeys = false;
    FocusManager.instance.removeEarlyKeyEventHandler(_onKey);
  }

  @override
  void dispose() {
    _removeKeyHandler();
    _gate?.close();
    _gate = null;
    final Ticker? ticker = _ticker;
    _ticker = null;
    ticker?.dispose();
    super.dispose();
  }

  Color _paperColour(FieldNotesColors colors) {
    final Color system = switch (MediaQuery.platformBrightnessOf(context)) {
      Brightness.dark => FieldNotesColors.dark.panelTop,
      Brightness.light => FieldNotesColors.light.panelTop,
    };
    final Color app = colors.panelTop;
    if (system == app) {
      return app;
    }
    final double share = _share(_now, _paperEase);
    return switch (share) {
      <= 0 => system,
      >= 1 => app,
      _ => Color.lerp(system, app, Curves.easeInOut.transform(share))!,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool showing = _plays == true && !_gone;
    if (showing && _ticker == null) {
      _ticker = createTicker(_onTick)..start();
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[widget.child, if (showing) _cover(context)],
    );
  }

  Widget _cover(BuildContext context) {
    final OpeningPlan plan = _plan;
    final Duration? exitAt = _exitAt;
    final double fade = exitAt == null
        ? 1
        : 1 - Curves.easeOut.transform(_share(_now - exitAt, _exitFade));
    final Duration? opening = _openingElapsed;
    final double reveal = opening == null
        ? 1
        : openingRevealAlpha(plan, _seconds(opening));
    final Color paper = _paperColour(context.colors);
    final double top = switch (resolveShellLayout(Theme.of(context).platform)) {
      ShellLayout.sidebar => shellTitleBarHeight,
      ShellLayout.bottomBar => 0,
    };
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_takesInput,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (PointerDownEvent _) => _skip(),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(
                key: openingPaperKey,
                color: paper.withValues(alpha: paper.a * reveal * fade),
              ),
              if (opening != null)
                OpeningFrame(
                  seconds: _seconds(opening),
                  paintsPaper: false,
                  fade: fade,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
