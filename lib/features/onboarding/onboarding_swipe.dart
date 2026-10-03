import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

const double onboardingSwipeStart = 12;
const double onboardingSwipeCommit = 60;
const Duration onboardingSwipeSettle = Duration(milliseconds: 300);
const Cubic onboardingSwipeCurve = Cubic(0.2, 0.8, 0.2, 1);

const double _swipeDominance = 1.4;
const double _verticalGiveUp = 16;
const double _allowedFollow = 0.6;
const double _blockedFollow = 0.18;
const double _fadeReach = 260;
const double _fadeFloor = 0.25;

@immutable
class OnboardingSwipePose {
  const OnboardingSwipePose({required this.shift, required this.opacity});

  factory OnboardingSwipePose.dragged(double dx, {required bool allowed}) =>
      OnboardingSwipePose(
        shift: dx * (allowed ? _allowedFollow : _blockedFollow),
        opacity: math.max(_fadeFloor, 1 - dx.abs() / _fadeReach),
      );

  static const OnboardingSwipePose rest = OnboardingSwipePose(
    shift: 0,
    opacity: 1,
  );

  final double shift;
  final double opacity;

  bool get atRest => shift == 0 && opacity == 1;

  OnboardingSwipePose toward(OnboardingSwipePose target, double t) =>
      OnboardingSwipePose(
        shift: shift + (target.shift - shift) * t,
        opacity: opacity + (target.opacity - opacity) * t,
      );

  @override
  bool operator ==(Object other) =>
      other is OnboardingSwipePose &&
      other.shift == shift &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(shift, opacity);

  @override
  String toString() => 'OnboardingSwipePose(shift: $shift, opacity: $opacity)';
}

class NoSwipe extends SingleChildRenderObjectWidget {
  const NoSwipe({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderNoSwipe();
}

class _RenderNoSwipe extends RenderProxyBoxWithHitTestBehavior {
  _RenderNoSwipe() : super(behavior: HitTestBehavior.translucent);
}

bool _startsOutsideSwipes(HitTestResult result) => !result.path.any(
  (HitTestEntry entry) =>
      entry.target is _RenderNoSwipe || entry.target is RenderEditable,
);

class OnboardingSwipeArea extends StatefulWidget {
  const OnboardingSwipeArea({
    super.key,
    required this.enabled,
    required this.step,
    required this.canForward,
    required this.canBack,
    required this.onForward,
    required this.onBack,
    required this.onBlocked,
    required this.child,
  });

  final bool enabled;
  final Object step;
  final ValueGetter<bool> canForward;
  final ValueGetter<bool> canBack;
  final VoidCallback onForward;
  final VoidCallback onBack;
  final VoidCallback onBlocked;
  final Widget child;

  @override
  State<OnboardingSwipeArea> createState() => _OnboardingSwipeAreaState();
}

class _OnboardingSwipeAreaState extends State<OnboardingSwipeArea>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<OnboardingSwipePose> _pose =
      ValueNotifier<OnboardingSwipePose>(OnboardingSwipePose.rest);
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: onboardingSwipeSettle,
  )..addListener(_onSettle);
  OnboardingSwipePose _released = OnboardingSwipePose.rest;
  bool _allowed = false;

  @override
  void didUpdateWidget(OnboardingSwipeArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step || !widget.enabled) {
      _rest();
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    _pose.dispose();
    super.dispose();
  }

  void _rest() {
    _settle.stop();
    _released = OnboardingSwipePose.rest;
    _pose.value = OnboardingSwipePose.rest;
  }

  void _onSettle() {
    _pose.value = _released.toward(
      OnboardingSwipePose.rest,
      onboardingSwipeCurve.transform(_settle.value),
    );
  }

  bool _startsHere(PointerDownEvent event) {
    final HitTestResult result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    return _startsOutsideSwipes(result);
  }

  void _onStart() {
    _settle.stop();
  }

  void _onUpdate(double dx) {
    _allowed = dx < 0 ? widget.canForward() : widget.canBack();
    _pose.value = OnboardingSwipePose.dragged(dx, allowed: _allowed);
  }

  void _onEnd(double dx) {
    _springBack();
    if (dx < -onboardingSwipeCommit) {
      if (widget.canForward()) {
        widget.onForward();
      } else {
        widget.onBlocked();
      }
    } else if (dx > onboardingSwipeCommit && widget.canBack()) {
      widget.onBack();
    }
  }

  void _springBack() {
    _released = _pose.value;
    if (_released.atRest || MediaQuery.disableAnimationsOf(context)) {
      _rest();
      return;
    }
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: widget.enabled
          ? <Type, GestureRecognizerFactory>{
              _PageSwipeRecognizer:
                  GestureRecognizerFactoryWithHandlers<_PageSwipeRecognizer>(
                    () => _PageSwipeRecognizer(debugOwner: this),
                    (_PageSwipeRecognizer recognizer) => recognizer
                      ..startsHere = _startsHere
                      ..onStart = _onStart
                      ..onUpdate = _onUpdate
                      ..onEnd = _onEnd
                      ..onCancel = _springBack,
                  ),
            }
          : const <Type, GestureRecognizerFactory>{},
      child: _SwipeScope(pose: _pose, child: widget.child),
    );
  }
}

class _PageSwipeRecognizer extends OneSequenceGestureRecognizer {
  _PageSwipeRecognizer({super.debugOwner});

  bool Function(PointerDownEvent event)? startsHere;
  VoidCallback? onStart;
  ValueChanged<double>? onUpdate;
  ValueChanged<double>? onEnd;
  VoidCallback? onCancel;

  int? _pointer;
  Offset _origin = Offset.zero;
  bool _swiping = false;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      _pointer == null &&
      super.isPointerAllowed(event) &&
      (startsHere?.call(event) ?? true);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _pointer = event.pointer;
    _origin = event.position;
    _swiping = false;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    final Offset moved = event.position - _origin;
    switch (event) {
      case PointerMoveEvent():
        if (!_swiping) {
          if (moved.dx.abs() > onboardingSwipeStart &&
              moved.dx.abs() > moved.dy.abs() * _swipeDominance) {
            _swiping = true;
            resolve(GestureDisposition.accepted);
            onStart?.call();
          } else {
            if (moved.dy.abs() > _verticalGiveUp) {
              _giveUp(event.pointer);
            }
            return;
          }
        }
        onUpdate?.call(moved.dx);
      case PointerUpEvent():
        final bool swiping = _swiping;
        _swiping = false;
        if (swiping) {
          stopTrackingPointer(event.pointer);
          onEnd?.call(moved.dx);
        } else {
          _giveUp(event.pointer);
        }
      case PointerCancelEvent():
        final bool swiping = _swiping;
        _giveUp(event.pointer);
        if (swiping) {
          onCancel?.call();
        }
      default:
        return;
    }
  }

  void _giveUp(int pointer) {
    _swiping = false;
    resolve(GestureDisposition.rejected);
    stopTrackingPointer(pointer);
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    if (pointer != _pointer) {
      return;
    }
    final bool swiping = _swiping;
    _swiping = false;
    stopTrackingPointer(pointer);
    if (swiping) {
      onCancel?.call();
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointer = null;
  }

  @override
  String get debugDescription => 'onboarding page swipe';
}

class _SwipeScope extends InheritedWidget {
  const _SwipeScope({required this.pose, required super.child});

  final ValueListenable<OnboardingSwipePose> pose;

  static _SwipeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SwipeScope>();

  @override
  bool updateShouldNotify(_SwipeScope oldWidget) => pose != oldWidget.pose;
}

class _SwipeMarks extends InheritedWidget {
  const _SwipeMarks({required this.marked, required super.child});

  final Set<Object> marked;

  static _SwipeMarks? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SwipeMarks>();

  @override
  bool updateShouldNotify(_SwipeMarks oldWidget) => marked != oldWidget.marked;
}

Widget _posed(OnboardingSwipePose pose, Widget child) => Opacity(
  opacity: pose.opacity,
  alwaysIncludeSemantics: true,
  child: Transform.translate(offset: Offset(pose.shift, 0), child: child),
);

class OnboardingSwipeContent extends StatefulWidget {
  const OnboardingSwipeContent({super.key, required this.child});

  final Widget child;

  @override
  State<OnboardingSwipeContent> createState() => _OnboardingSwipeContentState();
}

class _OnboardingSwipeContentState extends State<OnboardingSwipeContent> {
  final Set<Object> _marked = <Object>{};

  @override
  Widget build(BuildContext context) {
    final _SwipeScope? scope = _SwipeScope.maybeOf(context);
    final Widget marks = _SwipeMarks(marked: _marked, child: widget.child);
    if (scope == null) {
      return _posed(OnboardingSwipePose.rest, marks);
    }
    return ValueListenableBuilder<OnboardingSwipePose>(
      valueListenable: scope.pose,
      child: marks,
      builder: (
        BuildContext context,
        OnboardingSwipePose pose,
        Widget? child,
      ) => _posed(_marked.isEmpty ? pose : OnboardingSwipePose.rest, child!),
    );
  }
}

class OnboardingSwipeLayer extends StatefulWidget {
  const OnboardingSwipeLayer({super.key, required this.child});

  final Widget child;

  @override
  State<OnboardingSwipeLayer> createState() => _OnboardingSwipeLayerState();
}

class _OnboardingSwipeLayerState extends State<OnboardingSwipeLayer> {
  final Object _mark = Object();
  Set<Object>? _marked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Set<Object>? marked = _SwipeMarks.maybeOf(context)?.marked;
    if (!identical(marked, _marked)) {
      _marked?.remove(_mark);
      marked?.add(_mark);
      _marked = marked;
    }
  }

  @override
  void dispose() {
    _marked?.remove(_mark);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _SwipeScope? scope = _SwipeScope.maybeOf(context);
    if (scope == null) {
      return _posed(OnboardingSwipePose.rest, widget.child);
    }
    return ValueListenableBuilder<OnboardingSwipePose>(
      valueListenable: scope.pose,
      child: widget.child,
      builder: (
        BuildContext context,
        OnboardingSwipePose pose,
        Widget? child,
      ) => _posed(pose, child!),
    );
  }
}
