import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/art/art.dart';
import 'package:field_notes/design/tokens/tokens.dart';

const double composerPanelWidth = 640;
const double composerPanelMaxWidth = 1000;
const double composerPanelWidthShare = 0.6;

const Key composerPanelKey = ValueKey<String>('composer-panel');

const double composerPanelBorderWidth = 2;
const double _scrimBlurSigma = 3.5;
const double _sprigTop = -10;
const double _sprigRight = -8;
const double _sprigOpacity = 0.4;

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
    return Stack(
      children: <Widget>[
        Positioned.fill(child: _scrim(context)),
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
                  final double width = responsive
                      ? composerPanelWidthFor(constraints.maxWidth)
                      : maxWidth;
                  return SizedBox(
                    width: math.min(width, constraints.maxWidth),
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

  Widget _panel() {
    return Container(
      key: composerPanelKey,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Palette.composerPaper,
        border: Border.all(color: Palette.ink, width: composerPanelBorderWidth),
        borderRadius: BorderRadius.circular(Shapes.radiusXl),
        boxShadow: Shadows.panelLift,
      ),
      child: Stack(
        children: <Widget>[
          const Positioned(
            top: _sprigTop,
            right: _sprigRight,
            child: IgnorePointer(
              child: Opacity(opacity: _sprigOpacity, child: SprigArt()),
            ),
          ),
          child,
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
