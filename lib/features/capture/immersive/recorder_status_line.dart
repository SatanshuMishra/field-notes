import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/entry_cards/util/duration_format.dart';

import 'stage_phase.dart';

const Key recorderStatusTextKey = ValueKey<String>('recorder-status-text');
const Key recorderTimerKey = ValueKey<String>('recorder-timer');
const Key recorderStatusDotKey = ValueKey<String>('recorder-status-dot');

const Color _statusInk = Color(0xFFDCCAB0);
const Color _timerInk = Color(0xFFB7A58C);
const Color _pausedDot = Color(0xFFD9B36B);

const double _sidebarStatusSize = 21;
const double _bottomBarStatusSize = 18;
const double _timerSize = 12;
const double _timerTracking = 0.08 * _timerSize;
const double _sidebarTimerBand = 22;
const double _bottomBarTimerBand = 18;
const double _stackedTimerGap = 4;
const double _inlineGap = 9;
const double _dotSize = 8;
const double _dotMinOpacity = 0.45;
const double _dotGlowAlpha = 0.6;
const Duration _dotGlowHalfCycle = Duration(milliseconds: 1500);

class RecorderStatusLine extends StatelessWidget {
  const RecorderStatusLine({
    super.key,
    required this.phase,
    required this.elapsed,
    this.savingText,
    required this.inline,
  });

  final StagePhase phase;
  final Duration elapsed;
  final String? savingText;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final ShellLayout layout = stageLayoutOf(context);
    final Widget status = _status(layout);
    final Widget? timer = phase.showsTimer ? _timer() : null;
    if (inline) {
      final Widget? dot = _dot(context);
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (dot != null) ...<Widget>[dot, const SizedBox(width: _inlineGap)],
          Flexible(child: status),
          if (timer != null) ...<Widget>[
            const SizedBox(width: _inlineGap),
            timer,
          ],
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        status,
        const SizedBox(height: _stackedTimerGap),
        SizedBox(
          height: layout == ShellLayout.sidebar
              ? _sidebarTimerBand
              : _bottomBarTimerBand,
          child: Center(child: timer),
        ),
      ],
    );
  }

  Widget _status(ShellLayout layout) {
    final String text = phase.statusText(
      layout: layout,
      savingText: savingText,
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: phase.announcement,
      value: text,
      child: ExcludeSemantics(
        child: Text(
          text,
          key: recorderStatusTextKey,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TypographyTokens.accent,
            fontSize: layout == ShellLayout.sidebar
                ? _sidebarStatusSize
                : _bottomBarStatusSize,
            fontWeight: FontWeight.w600,
            color: _statusInk,
          ),
        ),
      ),
    );
  }

  Widget _timer() {
    return Semantics(
      container: true,
      child: Text(
        formatMediaDuration(elapsed.inMilliseconds),
        key: recorderTimerKey,
        maxLines: 1,
        style: const TextStyle(
          fontFamily: TypographyTokens.sans,
          fontSize: _timerSize,
          fontWeight: FontWeight.w500,
          letterSpacing: _timerTracking,
          color: _timerInk,
        ),
      ),
    );
  }

  Widget? _dot(BuildContext context) {
    if (phase == StagePhase.recording) {
      return Blink(
        key: recorderStatusDotKey,
        minOpacity: _dotMinOpacity,
        duration: _dotGlowHalfCycle,
        animate: !MediaQuery.disableAnimationsOf(context),
        child: _Dot(color: context.colors.accentBright, glow: true),
      );
    }
    if (phase == StagePhase.paused) {
      return const _Dot(
        key: recorderStatusDotKey,
        color: _pausedDot,
        glow: false,
      );
    }
    return null;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.color, required this.glow});

  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _dotSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glow
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withValues(alpha: _dotGlowAlpha),
                    blurRadius: _dotSize,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
