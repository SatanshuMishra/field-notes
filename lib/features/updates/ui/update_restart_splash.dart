import 'dart:math' as math;

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/updates/update_controller.dart';
import 'package:field_notes/features/updates/update_wording.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Key updateRestartSplashKey = ValueKey<String>('update-restart-splash');

const double updateRestartLogoSize = 84;

const double _titleSize = 24;
const double _lineSize = 17;
const double _logoGap = 18;
const double _lineGap = 6;
const double _swayDegrees = 4;
const Duration _swayPeriod = Duration(milliseconds: 2400);

class UpdateRestartCover extends ConsumerStatefulWidget {
  const UpdateRestartCover({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateRestartCover> createState() => _UpdateRestartCoverState();
}

class _UpdateRestartCoverState extends ConsumerState<UpdateRestartCover> {
  FocusNode? _returnFocus;

  @override
  void initState() {
    super.initState();
    ref.listenManual<UpdateStatus>(updateControllerProvider, _onStatus);
  }

  @override
  void dispose() {
    _returnFocus = null;
    super.dispose();
  }

  void _onStatus(UpdateStatus? previous, UpdateStatus next) {
    final bool wasRestarting = previous is UpdateRestarting;
    final bool restarting = next is UpdateRestarting;
    if (restarting && !wasRestarting) {
      _returnFocus = FocusManager.instance.primaryFocus;
      return;
    }
    if (!restarting && wasRestarting) {
      final FocusNode? node = _returnFocus;
      _returnFocus = null;
      if (node == null) {
        return;
      }
      WidgetsBinding.instance
        ..addPostFrameCallback((Duration _) => _giveFocusBack(node))
        ..ensureVisualUpdate();
    }
  }

  void _giveFocusBack(FocusNode node) {
    if (!mounted) {
      return;
    }
    final BuildContext? nodeContext = node.context;
    if (nodeContext == null || !nodeContext.mounted) {
      return;
    }
    if (!node.canRequestFocus) {
      return;
    }
    node.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final bool restarting =
        ref.watch(updateControllerProvider) is UpdateRestarting;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ExcludeFocus(
          excluding: restarting,
          child: ExcludeSemantics(
            excluding: restarting,
            child: Offstage(offstage: restarting, child: widget.child),
          ),
        ),
        const UpdateRestartSplash(),
      ],
    );
  }
}

class UpdateRestartSplash extends ConsumerWidget {
  const UpdateRestartSplash({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UpdateStatus status = ref.watch(updateControllerProvider);
    if (status is! UpdateRestarting) {
      return const SizedBox.shrink();
    }
    final FieldNotesColors colors = context.colors;
    final String version = status.release.version.toString();
    final String title = restartingTitle;
    final String line = openingVersionLine(version);
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title, $line',
      child: ExcludeSemantics(
        child: AbsorbPointer(
          child: DecoratedBox(
            key: updateRestartSplashKey,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[colors.pageGradientInner, colors.page],
              ),
            ),
            child: DefaultTextStyle(
              style: context.textStyles.bodySans,
              child: SizedBox.expand(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const _SwayingLogo(),
                      const SizedBox(height: _logoGap),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: context.textStyles.headlineSerif.copyWith(
                          fontSize: _titleSize,
                          fontWeight: FontWeight.w500,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: _lineGap),
                      Text(
                        line,
                        textAlign: TextAlign.center,
                        style: context.textStyles.sectionHeaderAccent.copyWith(
                          fontSize: _lineSize,
                          color: colors.accentInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwayingLogo extends StatefulWidget {
  const _SwayingLogo();

  @override
  State<_SwayingLogo> createState() => _SwayingLogoState();
}

class _SwayingLogoState extends State<_SwayingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: _swayPeriod,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sway.stop();
      _sway.value = 0.5;
    } else if (!_sway.isAnimating) {
      _sway.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sway,
      builder: (BuildContext context, Widget? child) {
        final double eased = Curves.easeInOut.transform(_sway.value);
        final double degrees = (eased * 2 - 1) * _swayDegrees;
        return Transform.rotate(
          angle: degrees * math.pi / 180,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
      child: const FlowerBloom(
        kind: FlowerKind.peony,
        size: updateRestartLogoSize,
      ),
    );
  }
}
