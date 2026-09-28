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

const double composerPanelMargin = 28;

const double composerPanelRoomyHeight = 560;

double composerPanelMarginFor(double available) =>
    available.isFinite && available < composerPanelRoomyHeight
        ? 0
        : composerPanelMargin;
const double _scrimBlurSigma = 3.5;
const double _sprigTop = -10;
const double _sprigRight = -8;
const double _sprigOpacity = 0.4;
const double _sprigEdgeOverhang = 8;

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

enum ComposerSprigPlacement { headerCorner, rightEdge }

class ComposerShell extends StatelessWidget {
  const ComposerShell({
    super.key,
    required this.child,
    this.maxWidth = composerPanelWidth,
    this.closeOnScrimTap = false,
    this.responsive = false,
    this.sprig = ComposerSprigPlacement.headerCorner,
  });

  final Widget child;
  final double maxWidth;
  final bool closeOnScrimTap;
  final bool responsive;
  final ComposerSprigPlacement sprig;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: _scrim(context)),
        Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top,
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: MediaQuery(
            data: MediaQuery.of(context)
                .removeViewInsets(removeBottom: true)
                .removePadding(removeTop: true),
            child: Center(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double width = responsive
                      ? composerPanelWidthFor(constraints.maxWidth)
                      : maxWidth;
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: composerPanelMarginFor(constraints.maxHeight),
                    ),
                    child: SizedBox(
                      width: math.min(width, constraints.maxWidth),
                      child: _panel(),
                    ),
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

  Widget _sprig() => _sprigLayerFor(sprig);

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
        children: <Widget>[_sprig(), child],
      ),
    );
  }
}

Widget _sprigLayerFor(ComposerSprigPlacement placement) {
  switch (placement) {
    case ComposerSprigPlacement.headerCorner:
      return const Positioned(
        top: _sprigTop,
        right: _sprigRight,
        child: IgnorePointer(
          child: Opacity(opacity: _sprigOpacity, child: SprigArt()),
        ),
      );
    case ComposerSprigPlacement.rightEdge:
      return Positioned.fill(
        child: IgnorePointer(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double panelHeight =
                  constraints.maxHeight + 2 * composerPanelBorderWidth;
              if (panelHeight < composerPanelRoomyHeight) {
                return const SizedBox.shrink();
              }
              return Align(
                alignment: Alignment.centerRight,
                child: Transform.translate(
                  offset: const Offset(_sprigEdgeOverhang, 0),
                  child: const Opacity(
                    opacity: _sprigOpacity,
                    child: SprigArt(),
                  ),
                ),
              );
            },
          ),
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
