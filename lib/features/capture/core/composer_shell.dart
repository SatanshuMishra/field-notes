import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/art/art.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart'
    show phoneSheetCurve, phoneSheetEntrance;

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

const Color composerFullScreenBarrierColor = Color(0x612A241D);
const Duration composerSlideDuration = phoneSheetEntrance;
const Cubic composerSlideCurve = phoneSheetCurve;
const double _popInScale = 0.92;

bool composerFillsScreen(BuildContext context) =>
    resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar;

Future<T?> showComposerRoute<T>(
  BuildContext context, {
  required String barrierLabel,
  required Widget child,
}) {
  final bool fullScreen = composerFillsScreen(context);
  final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: barrierLabel,
    barrierColor: fullScreen
        ? composerFullScreenBarrierColor
        : const Color(0x00000000),
    transitionDuration: fullScreen
        ? (still ? Duration.zero : composerSlideDuration)
        : Motion.modalPop,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return DialogHost(
        child: ComposerShell(
          closeOnScrimTap: true,
          responsive: true,
          sprig: ComposerSprigPlacement.rightEdge,
          child: child,
        ),
      );
    },
    transitionBuilder: fullScreen ? _slideUp : _popIn,
  );
}

Widget _slideUp(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return SlideTransition(
    position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: animation, curve: composerSlideCurve)),
    child: child,
  );
}

Widget _popIn(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final Animation<double> curved = CurvedAnimation(
    parent: animation,
    curve: Motion.entranceCurve,
  );
  return FadeTransition(
    opacity: curved,
    child: ScaleTransition(
      scale: Tween<double>(begin: _popInScale, end: 1.0).animate(curved),
      child: child,
    ),
  );
}

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
    if (responsive && composerFillsScreen(context)) {
      return _fullScreen(context);
    }
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
                      child: _panel(context),
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

  Widget _fullScreen(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    return Container(
      key: composerPanelKey,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: context.colors.composerPaper),
      padding: EdgeInsets.only(
        top: math.max(media.padding.top, media.viewPadding.top),
        bottom: math.max(
          math.max(media.padding.bottom, media.viewPadding.bottom),
          media.viewInsets.bottom,
        ),
      ),
      child: MediaQuery(
        data: media
            .removeViewInsets(removeBottom: true)
            .removeViewPadding(removeTop: true, removeBottom: true),
        child: Stack(
          children: <Widget>[_sprig(), child],
        ),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Container(
      key: composerPanelKey,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: colors.composerPaper,
        border: Border.all(color: colors.line, width: composerPanelBorderWidth),
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
