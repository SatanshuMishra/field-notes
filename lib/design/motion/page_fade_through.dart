import 'package:flutter/widgets.dart';

import 'motion_tokens.dart';

typedef _Timing = ({double outShare, double rise});
typedef _Departure = ({double opacity, double rise});

class PageFadeThrough<T extends Object> extends StatefulWidget {
  const PageFadeThrough({super.key, required this.page, required this.builder});

  final T page;
  final Widget Function(BuildContext context, T page) builder;

  @override
  State<PageFadeThrough<T>> createState() => _PageFadeThroughState<T>();
}

class _PageFadeThroughState<T extends Object> extends State<PageFadeThrough<T>>
    with SingleTickerProviderStateMixin {
  static const _Timing _crossFade = (outShare: 0, rise: 0);
  static final _Timing _fadeThrough = (
    outShare:
        Motion.pageOut.inMicroseconds /
        (Motion.pageOut + Motion.pageIn).inMicroseconds,
    rise: Motion.pageRise,
  );

  late final AnimationController _progress;
  late final Animation<double> _opacity;
  late T _shown;
  _Timing _timing = _crossFade;
  _Departure _departure = (opacity: 1, rise: 0);

  @override
  void initState() {
    super.initState();
    _shown = widget.page;
    _progress = AnimationController(
      vsync: this,
      value: 1,
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(_showArrivalOnceFaded);
    _opacity = _progress.drive(Animatable<double>.fromCallback(_opacityAt));
  }

  @override
  void didUpdateWidget(PageFadeThrough<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.page == oldWidget.page || _fadingOut) {
      return;
    }
    _begin(still: MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  bool get _fadingOut =>
      _progress.isAnimating && _progress.value < _timing.outShare;

  void _begin({required bool still}) {
    final double now = _progress.value;
    _departure = (opacity: _opacityAt(now), rise: _riseAt(now));
    _timing = still ? _crossFade : _fadeThrough;
    if (still) {
      _shown = widget.page;
    }
    _progress
      ..duration = still
          ? Motion.pageFadeReduced
          : Motion.pageOut + Motion.pageIn
      ..forward(from: 0);
  }

  void _showArrivalOnceFaded() {
    if (_shown == widget.page || _progress.value < _timing.outShare) {
      return;
    }
    setState(() => _shown = widget.page);
  }

  double _arrivalAt(double progress) {
    final double outShare = _timing.outShare;
    return outShare >= 1
        ? 1
        : ((progress - outShare) / (1 - outShare)).clamp(0.0, 1.0);
  }

  double _opacityAt(double progress) {
    final double outShare = _timing.outShare;
    if (progress < outShare) {
      return _departure.opacity *
          (1 - Motion.pageOutCurve.transform(progress / outShare));
    }
    return Motion.pageInCurve.transform(_arrivalAt(progress));
  }

  double _riseAt(double progress) {
    if (progress < _timing.outShare) {
      return _departure.rise;
    }
    return _timing.rise *
        (1 - Motion.pageInCurve.transform(_arrivalAt(progress)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: FadeTransition(
        opacity: _opacity,
        child: widget.builder(context, _shown),
      ),
      builder: (BuildContext context, Widget? page) => Transform.translate(
        offset: Offset(0, _riseAt(_progress.value)),
        child: IgnorePointer(ignoring: _fadingOut, child: page),
      ),
    );
  }
}
