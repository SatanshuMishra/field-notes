import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/state/settings_providers.dart';

import 'stage_phase.dart';

const List<String> reflectionQuestions = <String>[
  'What’s been on your mind today?',
  'What felt heavier than it needed to?',
  'What would you tell a friend in your place?',
  'What do you want to remember about today?',
  'What haven’t you said out loud yet?',
  'What went well that you didn’t stop to notice?',
  'When did you feel most like yourself today?',
];

const String reflectionKicker = 'a question, if you want one';
const String reflectionShuffleLabel = 'Ask me something else';

const Key reflectionQuestionKey = ValueKey<String>('reflection-question');
const Key reflectionShuffleKey = ValueKey<String>('reflection-shuffle');

const double reflectionUnderwayOpacity = 0.45;
const Duration reflectionFadeDuration = Duration(milliseconds: 1400);

const Color _kickerInk = Color(0xFFD39A82);
const Color _questionInk = Color(0xFFF3E6D1);
const Color _shuffleInk = Color(0xFFB7A58C);

const double _kickerSize = 18;
const double _sidebarQuestionSize = 38;
const double _bottomBarQuestionSize = 22;
const double _sidebarQuestionLeading = 1.22;
const double _bottomBarQuestionLeading = 1.26;
const int _sidebarQuestionLines = 3;
const int _bottomBarQuestionLines = 4;
const double _sidebarKickerGap = 10;
const double _bottomBarKickerGap = 6;
const double _sidebarShuffleSize = 12;
const double _bottomBarShuffleSize = 11;
const double _shuffleBand = 48;
const EdgeInsets _shufflePadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 6,
);
const BorderRadius _shuffleRadius = BorderRadius.all(Radius.circular(14));
const int _balanceSteps = 16;

class ReflectionPrompt extends ConsumerStatefulWidget {
  const ReflectionPrompt({
    super.key,
    required this.phase,
    required this.showKicker,
    this.initialIndex,
  });

  final StagePhase phase;
  final bool showKicker;
  final int? initialIndex;

  @override
  ConsumerState<ReflectionPrompt> createState() => _ReflectionPromptState();
}

class _ReflectionPromptState extends ConsumerState<ReflectionPrompt> {
  late int _index = _startIndex();

  int _startIndex() {
    final int? initial = widget.initialIndex;
    return initial == null
        ? math.Random().nextInt(reflectionQuestions.length)
        : initial % reflectionQuestions.length;
  }

  void _shuffle() {
    setState(() => _index = (_index + 1) % reflectionQuestions.length);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(reflectionPromptsEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final bool sidebar = stageLayoutOf(context) == ShellLayout.sidebar;
    return AnimatedOpacity(
      opacity: widget.phase.isUnderway ? reflectionUnderwayOpacity : 1.0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : reflectionFadeDuration,
      curve: Curves.ease,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.showKicker) ...<Widget>[
            const Text(
              reflectionKicker,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TypographyTokens.accent,
                fontSize: _kickerSize,
                fontWeight: FontWeight.w600,
                color: _kickerInk,
              ),
            ),
            SizedBox(height: sidebar ? _sidebarKickerGap : _bottomBarKickerGap),
          ],
          _BalancedText(
            key: reflectionQuestionKey,
            text: reflectionQuestions[_index],
            maxLines: sidebar ? _sidebarQuestionLines : _bottomBarQuestionLines,
            style: TextStyle(
              fontFamily: TypographyTokens.serif,
              fontSize: sidebar ? _sidebarQuestionSize : _bottomBarQuestionSize,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              height: sidebar
                  ? _sidebarQuestionLeading
                  : _bottomBarQuestionLeading,
              color: _questionInk,
            ),
          ),
          SizedBox(
            height: _shuffleBand,
            child: widget.phase == StagePhase.idle
                ? Center(child: _shuffleButton(sidebar))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _shuffleButton(bool sidebar) {
    return Semantics(
      button: true,
      label: reflectionShuffleLabel,
      child: GestureDetector(
        key: reflectionShuffleKey,
        behavior: HitTestBehavior.opaque,
        onTap: _shuffle,
        child: FocusRing(
          onPressed: _shuffle,
          surface: FocusRingSurface.dark,
          borderRadius: _shuffleRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _shuffleBand,
              minHeight: _shuffleBand,
            ),
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: _shufflePadding,
                child: ExcludeSemantics(
                  child: Text(
                    reflectionShuffleLabel,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: TypographyTokens.sans,
                      fontSize: sidebar
                          ? _sidebarShuffleSize
                          : _bottomBarShuffleSize,
                      fontWeight: FontWeight.w500,
                      color: _shuffleInk,
                    ),
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

class _BalancedText extends StatelessWidget {
  const _BalancedText({
    super.key,
    required this.text,
    required this.style,
    required this.maxLines,
  });

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final TextStyle painted = DefaultTextStyle.of(context).style.merge(style);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget label = Text(
          text,
          textAlign: TextAlign.center,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
        if (!constraints.maxWidth.isFinite) {
          return label;
        }
        return SizedBox(
          width: _balancedWidth(
            painted: painted,
            scaler: scaler,
            direction: direction,
            maxWidth: constraints.maxWidth,
          ),
          child: label,
        );
      },
    );
  }

  double _balancedWidth({
    required TextStyle painted,
    required TextScaler scaler,
    required TextDirection direction,
    required double maxWidth,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: painted),
      textAlign: TextAlign.center,
      textDirection: direction,
      textScaler: scaler,
      maxLines: maxLines,
    );
    try {
      painter.layout(maxWidth: maxWidth);
      final int lines = painter.computeLineMetrics().length;
      if (lines <= 1 || painter.didExceedMaxLines) {
        return maxWidth;
      }
      double narrow = 0;
      double wide = maxWidth;
      for (int step = 0; step < _balanceSteps; step++) {
        final double probe = (narrow + wide) / 2;
        painter.layout(maxWidth: probe);
        final bool spills =
            painter.didExceedMaxLines ||
            painter.computeLineMetrics().length > lines;
        if (spills) {
          narrow = probe;
        } else {
          wide = probe;
        }
      }
      return math.min(wide.ceilToDouble(), maxWidth);
    } finally {
      painter.dispose();
    }
  }
}
