import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/motion/motion_tokens.dart';

const Key cameraPictureKey = ValueKey<String>('camera-picture');
const Key cameraPictureFillKey = ValueKey<String>('camera-picture-fill');

const Key _pictureSlotKey = ValueKey<String>('camera-picture-slot');
const double _fillBlurSigma = 32;
const double _bandThreshold = 1;
const Color _fillScrim = Color(0x66140F0C);

class CameraPictureStage extends StatefulWidget {
  const CameraPictureStage({
    super.key,
    required this.pictureAspect,
    required this.picture,
    this.ambient,
    this.ready = true,
  });

  final double pictureAspect;
  final Widget picture;
  final Widget? ambient;
  final bool ready;

  @override
  State<CameraPictureStage> createState() => _CameraPictureStageState();
}

class _CameraPictureStageState extends State<CameraPictureStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: Motion.fade,
  );
  late final CurvedAnimation _opacity = CurvedAnimation(
    parent: _reveal,
    curve: Motion.fadeCurve,
  );
  bool _reduceMotion = false;
  bool _settled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _reveal.duration = _reduceMotion ? Duration.zero : Motion.fade;
    if (!_settled) {
      _settled = true;
      if (widget.ready) {
        _show();
      }
    }
  }

  @override
  void didUpdateWidget(CameraPictureStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready == oldWidget.ready) {
      return;
    }
    if (widget.ready) {
      _show();
    } else {
      _reveal.value = 0;
    }
  }

  void _show() {
    if (_reduceMotion) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size area = constraints.biggest;
        final Rect rect = _containedRect(area);
        final Widget? ambient = widget.ambient;
        final bool leavesBand =
            (area.width - rect.width) / 2 > _bandThreshold ||
            (area.height - rect.height) / 2 > _bandThreshold;
        final bool showFill = ambient != null && leavesBand && !_reduceMotion;
        return FadeTransition(
          opacity: _opacity,
          child: Stack(
            children: <Widget>[
              if (showFill)
                Positioned.fill(
                  key: cameraPictureFillKey,
                  child: _AmbientFill(pictureSize: rect.size, ambient: ambient),
                ),
              Positioned.fromRect(
                key: _pictureSlotKey,
                rect: rect,
                child: KeyedSubtree(
                  key: cameraPictureKey,
                  child: widget.picture,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Rect _containedRect(Size area) {
    final double aspect = widget.pictureAspect;
    if (area.isEmpty || !aspect.isFinite || aspect <= 0) {
      return Offset.zero & area;
    }
    final Size fitted = applyBoxFit(
      BoxFit.contain,
      Size(aspect, 1),
      area,
    ).destination;
    return Alignment.center.inscribe(fitted, Offset.zero & area);
  }
}

class _AmbientFill extends StatelessWidget {
  const _AmbientFill({required this.pictureSize, required this.ambient});

  final Size pictureSize;
  final Widget ambient;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: _fillBlurSigma,
                  sigmaY: _fillBlurSigma,
                ),
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox.fromSize(size: pictureSize, child: ambient),
                ),
              ),
              const ColoredBox(color: _fillScrim),
            ],
          ),
        ),
      ),
    );
  }
}
