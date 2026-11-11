import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/app/shell/windows_caption_buttons.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/outlined_surface.dart';
import 'package:field_notes/features/capture/core/night_sky.dart';
import 'package:field_notes/features/capture/immersive/immersive_route.dart'
    show immersiveFadeFor;
import 'package:field_notes/features/capture/immersive/stage_phase.dart'
    show stageLayoutOf;

const double composerPanelWidth = 640;
const double composerPanelMaxWidth = 1000;
const double composerPanelWidthShare = 0.6;

const Key composerPanelKey = ValueKey<String>('composer-panel');
const Key composerTopBandKey = ValueKey<String>('composer-top-band');

const double composerPanelBorderWidth = 2;

const double composerPanelMargin = 28;

const double composerPanelRoomyHeight = 560;

double composerPanelMarginFor(double available) =>
    available.isFinite && available < composerPanelRoomyHeight
    ? 0
    : composerPanelMargin;
const double _scrimBlurSigma = 3.5;

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

const Color _clearBarrier = Color(0x00000000);

const Color _paperChrome = Color(0xFF554737);
const Color _paperCaret = Color(0xFFB8566A);
const Color _roomChrome = Color(0xFFB7A58C);
const Color _roomStatus = Color(0xFFDCCAB0);
const Color _roomCaret = Color(0xFFE3889A);
const double _paperLineAlpha = 0.32;
const double _roomLineAlpha = 0.28;

@immutable
final class ComposerStageInks {
  const ComposerStageInks._({
    required this.ground,
    required this.ink,
    required this.chrome,
    required this.status,
    required this.line,
    required this.caret,
    required this.focus,
  });

  factory ComposerStageInks.of(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = colors.mediaCta;
    return ComposerStageInks._(
      ground: colors.viewerStage,
      ink: ink,
      chrome: dark ? _roomChrome : _paperChrome,
      status: dark ? _roomStatus : ink,
      line: ink.withValues(alpha: dark ? _roomLineAlpha : _paperLineAlpha),
      caret: dark ? _roomCaret : _paperCaret,
      focus: dark ? Palette.focusRingOnDark : ink,
    );
  }

  final Color ground;
  final Color ink;
  final Color chrome;
  final Color status;
  final Color line;
  final Color caret;
  final Color focus;
}

Future<T?> showComposerRoute<T>(
  BuildContext context, {
  required String barrierLabel,
  required Widget child,
}) {
  final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: barrierLabel,
    barrierColor: _clearBarrier,
    transitionDuration: still
        ? Duration.zero
        : immersiveFadeFor(stageLayoutOf(context)),
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return DialogHost(
            child: ComposerShell(responsive: true, child: child),
          );
        },
    transitionBuilder: _fadeIn,
  );
}

Widget _fadeIn(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.ease),
    child: child,
  );
}

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
    if (responsive) {
      return _room(context);
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
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: composerPanelMarginFor(constraints.maxHeight),
                    ),
                    child: SizedBox(
                      width: math.min(maxWidth, constraints.maxWidth),
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

  Widget _room(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool sidebar = stageLayoutOf(context) == ShellLayout.sidebar;
    final Widget room = ColoredBox(
      key: composerPanelKey,
      color: context.colors.viewerStage,
      child: sidebar ? _belowDragBand(context) : child,
    );
    if (sidebar) {
      return DarkCaptionSurface(dark: dark, child: room);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: room,
    );
  }

  Widget _belowDragBand(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(top: shellTitleBarHeight),
            ),
            child: child,
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: WindowDragBand(
            key: composerTopBandKey,
            height: shellTitleBarHeight,
          ),
        ),
      ],
    );
  }

  Widget _panel(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return OutlinedSurface(
      key: composerPanelKey,
      color: colors.composerPaper,
      borderColor: colors.line,
      borderWidth: composerPanelBorderWidth,
      borderRadius: BorderRadius.circular(Shapes.radiusXl),
      boxShadow: Shadows.panelLift,
      padding: const EdgeInsets.all(composerPanelBorderWidth),
      child: child,
    );
  }
}

class ComposerStageGround extends StatelessWidget {
  const ComposerStageGround({super.key, this.seed});

  final int? seed;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ComposerStageInks.of(context).ground,
      child: NightSky(kind: NightSkyKind.note, seed: seed),
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
