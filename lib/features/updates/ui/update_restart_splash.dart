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
