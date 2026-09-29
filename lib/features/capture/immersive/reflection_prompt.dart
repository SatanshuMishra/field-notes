import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
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
const double _sidebarQuestionFloor = _bottomBarQuestionSize;
const double _bottomBarQuestionFloor = 18;
const double _kickerFloor = 12;
const double _readableQuestion = 12;
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
const int _fitSteps = 12;

typedef _FitKey = ({
  double width,
  double height,
  int index,
  bool sidebar,
  bool showKicker,
  TextScaler scaler,
  TextStyle base,
  bool bold,
  TextDirection direction,
  TextHeightBehavior? heightBehavior,
  Locale? locale,
});

typedef _Fit = ({double question, double? kicker, double gap});

typedef _FitMemo = ({_FitKey key, _Fit? fit});

const _Fit _unfitted = (question: 1, kicker: 1, gap: 1);

double _questionSize(bool sidebar) {
  return sidebar ? _sidebarQuestionSize : _bottomBarQuestionSize;
}

int _questionLines(bool sidebar) {
  return sidebar ? _sidebarQuestionLines : _bottomBarQuestionLines;
}

TextStyle _kickerStyle(double scale) {
  return TextStyle(
    fontFamily: TypographyTokens.accent,
    fontSize: _kickerSize * scale,
    fontWeight: FontWeight.w600,
    color: _kickerInk,
  );
}

double _kickerGap(bool sidebar, double scale) {
  return (sidebar ? _sidebarKickerGap : _bottomBarKickerGap) * scale;
}

TextStyle _questionStyle(bool sidebar, double scale) {
  return TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: _questionSize(sidebar) * scale,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    height: sidebar ? _sidebarQuestionLeading : _bottomBarQuestionLeading,
    color: _questionInk,
  );
}

TextStyle _rendered(TextStyle base, TextStyle style, {required bool bold}) {
  final TextStyle merged = base.merge(style);
  return bold
      ? merged.merge(const TextStyle(fontWeight: FontWeight.bold))
      : merged;
}

double _search(double pass, double fail, bool Function(double) passes) {
  if (passes(fail)) {
    return fail;
  }
  double good = pass;
  double bad = fail;
  for (int step = 0; step < _fitSteps; step++) {
    final double probe = (good + bad) / 2;
    if (passes(probe)) {
      good = probe;
    } else {
      bad = probe;
    }
  }
  return good;
}

double _floorFactor(TextScaler scaler, double size, double floor) {
  final double full = scaler.scale(size);
  if (full <= floor) {
    return 1;
  }
  final double linear = floor / full;
  final double atLinear = scaler.scale(size * linear);
  if ((atLinear - floor).abs() <= precisionErrorTolerance) {
    return linear;
  }
  bool holds(double factor) => scaler.scale(size * factor) >= floor;
  return atLinear > floor
      ? _search(linear, 0, holds)
      : _search(1, linear, holds);
}

_Fit? _searchFit(_FitKey key) {
  double measure(String text, TextStyle style, int? maxLines) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: _rendered(key.base, style, bold: key.bold),
      ),
      textAlign: TextAlign.center,
      textDirection: key.direction,
      textScaler: key.scaler,
      textHeightBehavior: key.heightBehavior,
      locale: key.locale,
      maxLines: maxLines,
    );
    try {
      painter.layout(maxWidth: key.width);
      return painter.height;
    } finally {
      painter.dispose();
    }
  }

  double heightOf(_Fit fit) {
    final double question = measure(
      reflectionQuestions[key.index],
      _questionStyle(key.sidebar, fit.question),
      _questionLines(key.sidebar),
    );
    final double? kicker = key.showKicker ? fit.kicker : null;
    if (kicker == null) {
      return question;
    }
    return measure(reflectionKicker, _kickerStyle(kicker), null) +
        _kickerGap(key.sidebar, fit.gap) +
        question;
  }

  bool fits(_Fit fit) => heightOf(fit) <= key.height;

  if (fits(_unfitted)) {
    return _unfitted;
  }
  final double questionFloor = _floorFactor(
    key.scaler,
    _questionSize(key.sidebar),
    key.sidebar ? _sidebarQuestionFloor : _bottomBarQuestionFloor,
  );
  final double kickerFloor = _floorFactor(
    key.scaler,
    _kickerSize,
    _kickerFloor,
  );
  _Fit proportional(double scale) {
    return (question: scale, kicker: math.max(scale, kickerFloor), gap: scale);
  }

  final _Fit floored = proportional(questionFloor);
  if (fits(floored)) {
    return proportional(
      _search(questionFloor, 1, (double scale) => fits(proportional(scale))),
    );
  }
  if (key.showKicker) {
    _Fit shrunk({required double kicker, required double gap}) {
      return (question: questionFloor, kicker: kicker, gap: gap);
    }

    final double kickerCeiling = math.max(questionFloor, kickerFloor);
    if (fits(shrunk(kicker: kickerFloor, gap: questionFloor))) {
      return shrunk(
        kicker: _search(
          kickerFloor,
          kickerCeiling,
          (double kicker) => fits(shrunk(kicker: kicker, gap: questionFloor)),
        ),
        gap: questionFloor,
      );
    }
    if (fits(shrunk(kicker: kickerFloor, gap: 0))) {
      return shrunk(
        kicker: kickerFloor,
        gap: _search(
          0,
          questionFloor,
          (double gap) => fits(shrunk(kicker: kickerFloor, gap: gap)),
        ),
      );
    }
  }
  _Fit alone(double scale) {
    return (question: scale, kicker: null, gap: 0);
  }

  final _Fit last = alone(questionFloor);
  final double lastHeight = heightOf(last);
  if (lastHeight <= key.height) {
    return alone(
      _search(questionFloor, 1, (double scale) => fits(alone(scale))),
    );
  }
  final double readable =
      key.scaler.scale(_questionSize(key.sidebar) * questionFloor) *
      key.height /
      lastHeight;
  return readable < _readableQuestion ? null : last;
}

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
  _FitMemo? _fitMemo;

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
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxHeight < _shuffleBand) {
            return const SizedBox.shrink();
          }
          final _Fit? fit = _fitFor(context, sidebar, constraints);
          if (fit == null) {
            return const SizedBox.shrink();
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _fitted(_words(sidebar, fit), constraints),
              SizedBox(
                height: _shuffleBand,
                child: widget.phase == StagePhase.idle
                    ? Center(child: _shuffleButton(sidebar))
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _fitted(Widget words, BoxConstraints constraints) {
    if (!constraints.maxWidth.isFinite) {
      return words;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: constraints.maxHeight - _shuffleBand,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(width: constraints.maxWidth, child: words),
      ),
    );
  }

  _Fit? _fitFor(
    BuildContext context,
    bool sidebar,
    BoxConstraints constraints,
  ) {
    final double width = constraints.maxWidth;
    final double height = constraints.maxHeight - _shuffleBand;
    if (!width.isFinite || !height.isFinite) {
      return _unfitted;
    }
    final DefaultTextStyle ambient = DefaultTextStyle.of(context);
    final _FitKey key = (
      width: width,
      height: height,
      index: _index,
      sidebar: sidebar,
      showKicker: widget.showKicker,
      scaler: MediaQuery.textScalerOf(context),
      base: ambient.style,
      bold: MediaQuery.boldTextOf(context),
      direction: Directionality.of(context),
      heightBehavior:
          ambient.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );
    final _FitMemo? memo = _fitMemo;
    if (memo != null && memo.key == key) {
      return memo.fit;
    }
    final _Fit? fit = _searchFit(key);
    _fitMemo = (key: key, fit: fit);
    return fit;
  }

  Widget _words(bool sidebar, _Fit fit) {
    final double? kicker = widget.showKicker ? fit.kicker : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (kicker != null) ...<Widget>[
          Text(
            reflectionKicker,
            textAlign: TextAlign.center,
            style: _kickerStyle(kicker),
          ),
          SizedBox(height: _kickerGap(sidebar, fit.gap)),
        ],
        _BalancedText(
          key: reflectionQuestionKey,
          text: reflectionQuestions[_index],
          maxLines: _questionLines(sidebar),
          style: _questionStyle(sidebar, fit.question),
        ),
      ],
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
    final DefaultTextStyle ambient = DefaultTextStyle.of(context);
    final TextStyle painted = _rendered(
      ambient.style,
      style,
      bold: MediaQuery.boldTextOf(context),
    );
    final TextHeightBehavior? heightBehavior =
        ambient.textHeightBehavior ??
        DefaultTextHeightBehavior.maybeOf(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);
    final Locale? locale = Localizations.maybeLocaleOf(context);
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
            heightBehavior: heightBehavior,
            locale: locale,
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
    required TextHeightBehavior? heightBehavior,
    required Locale? locale,
    required double maxWidth,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: painted),
      textAlign: TextAlign.center,
      textDirection: direction,
      textScaler: scaler,
      textHeightBehavior: heightBehavior,
      locale: locale,
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
