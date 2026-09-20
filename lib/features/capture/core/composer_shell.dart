import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/art/art.dart';
import 'package:field_notes/design/tokens/tokens.dart';

const double composerPanelWidth = 640;

const double _panelBorderWidth = 2;
const double _scrimBlurSigma = 3.5;
const double _sprigTop = -10;
const double _sprigRight = -8;
const double _sprigOpacity = 0.4;

const RadialGradient _scrimGradient = RadialGradient(
  center: Alignment(0, -0.36),
  radius: 1.2,
  colors: <Color>[Color(0x5C2A2016), Color(0x9E1C140C)],
);

class ComposerShell extends StatelessWidget {
  const ComposerShell({
    super.key,
    required this.child,
    this.maxWidth = composerPanelWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const Positioned.fill(child: _ComposerScrim()),
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: Center(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SizedBox(
                    width: math.min(maxWidth, constraints.maxWidth),
                    child: _panel(),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel() {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Palette.composerPaper,
        border: Border.all(color: Palette.ink, width: _panelBorderWidth),
        borderRadius: BorderRadius.circular(Shapes.radiusXl),
        boxShadow: Shadows.panelLift,
      ),
      child: Stack(
        children: <Widget>[
          child,
          const Positioned(
            top: _sprigTop,
            right: _sprigRight,
            child: IgnorePointer(
              child: Opacity(opacity: _sprigOpacity, child: SprigArt()),
            ),
          ),
        ],
      ),
    );
  }
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
