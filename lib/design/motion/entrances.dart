import 'package:flutter/widgets.dart';

import 'motion_tokens.dart';

class _EntranceController {
  static AnimationController create(
    TickerProvider vsync,
    Duration duration, {
    required bool animate,
  }) {
    final AnimationController controller =
        AnimationController(vsync: vsync, duration: duration);
    if (animate) {
      controller.forward();
    } else {
      controller.value = 1.0;
    }
    return controller;
  }
}

class ToastEntrance extends StatefulWidget {
  const ToastEntrance({
    super.key,
    required this.child,
    this.duration = Motion.toastRise,
    this.animate = true,
  });

  final Widget child;
  final Duration duration;
  final bool animate;

  @override
  State<ToastEntrance> createState() => _ToastEntranceState();
}

class _ToastEntranceState extends State<ToastEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = _EntranceController.create(
      this,
      widget.duration,
      animate: widget.animate,
    );
    _curved = CurvedAnimation(parent: _controller, curve: Motion.entranceCurve);
    _slide = Tween<Offset>(
      begin: const Offset(0.0, 0.4),
      end: Offset.zero,
    ).animate(_curved);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(opacity: _curved, child: widget.child),
    );
  }
}

class ModalEntrance extends StatefulWidget {
  const ModalEntrance({
    super.key,
    required this.child,
    this.duration = Motion.modalPop,
    this.animate = true,
  });

  final Widget child;
  final Duration duration;
  final bool animate;

  @override
  State<ModalEntrance> createState() => _ModalEntranceState();
}

class _ModalEntranceState extends State<ModalEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = _EntranceController.create(
      this,
      widget.duration,
      animate: widget.animate,
    );
    _curved = CurvedAnimation(parent: _controller, curve: Motion.entranceCurve);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(_curved);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(opacity: _curved, child: widget.child),
    );
  }
}

class SheetEntrance extends StatefulWidget {
  const SheetEntrance({
    super.key,
    required this.child,
    this.duration = Motion.sheetSlide,
    this.animate = true,
  });

  final Widget child;
  final Duration duration;
  final bool animate;

  @override
  State<SheetEntrance> createState() => _SheetEntranceState();
}

class _SheetEntranceState extends State<SheetEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = _EntranceController.create(
      this,
      widget.duration,
      animate: widget.animate,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Motion.entranceCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _slide, child: widget.child);
  }
}
