import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';

const Duration _elapsed = Duration(minutes: 1, seconds: 5);
const String _elapsedText = '1:05';
const String _savingText = 'Saving your recording…';
const String _countdownWords = 'Breathe in… recording starts in';
const String _breathAnnouncement = 'Recording starts in 3';
const String _recordingText = 'I’m listening. Take your time.';
const String _pausedText = 'Paused. Nothing’s lost.';
const Color _numeralInk = Color(0xFFF3E6D1);

Future<void> _pumpLine(
  WidgetTester tester, {
  required StagePhase phase,
  required bool inline,
  TargetPlatform platform = TargetPlatform.macOS,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        backgroundColor: recorderStageColor,
        body: Center(
          child: RecorderStatusLine(
            phase: phase,
            elapsed: _elapsed,
            savingText: _savingText,
            inline: inline,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Widget _countdownApp({
  required StagePhase phase,
  required bool inline,
  TargetPlatform platform = TargetPlatform.macOS,
  bool still = false,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: fieldNotesTheme(platform: platform),
    home: Builder(
      builder: (BuildContext context) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: still),
          child: Scaffold(
            backgroundColor: recorderStageColor,
            body: Center(
              child: RecorderStatusLine(
                phase: phase,
                elapsed: _elapsed,
                savingText: _savingText,
                inline: inline,
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _recorderApp(TargetPlatform platform, Widget recorder) {
  return ProviderScope(
    overrides: <Override>[
      reflectionPromptsEnabledProvider.overrideWithValue(false),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(body: Center(child: recorder)),
    ),
  );
}

void _useWindow(WidgetTester tester, TargetPlatform platform) {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = platform == TargetPlatform.macOS
      ? const Size(1280, 800)
      : const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _useSize(WidgetTester tester, TargetPlatform platform, Size window) {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _numeral(String digit) => find.descendant(
  of: find.byType(RecorderStatusLine),
  matching: find.text(digit),
);

String _shownNumeral(WidgetTester tester) {
  final List<String> shown = <String>[
    for (final String digit in <String>['1', '2', '3'])
      if (_numeral(digit).evaluate().isNotEmpty) digit,
  ];
  expect(shown, hasLength(1));
  return shown.single;
}

double _numeralOpacity(WidgetTester tester) {
  final String digit = _shownNumeral(tester);
  return tester
      .widget<Opacity>(
        find
            .ancestor(of: _numeral(digit), matching: find.byType(Opacity))
            .first,
      )
      .opacity;
}

double _numeralScale(WidgetTester tester) {
  final String digit = _shownNumeral(tester);
  return tester
      .widget<Transform>(
        find
            .ancestor(of: _numeral(digit), matching: find.byType(Transform))
            .first,
      )
      .transform
      .entry(0, 0);
}

String? _words(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(recorderStatusTextKey)).data;

double _baselineOf(WidgetTester tester, Finder finder) {
  final Text text = tester.widget<Text>(finder);
  final BuildContext context = tester.element(finder);
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: text.data,
      style: DefaultTextStyle.of(context).style.merge(text.style),
    ),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final double baseline = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  painter.dispose();
  return tester.getTopLeft(finder).dy + baseline;
}

void _expectOneLine(WidgetTester tester, double windowWidth) {
  final Finder words = find.byKey(recorderStatusTextKey);
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(words);
  final List<double> caretTops = <double>[
    for (int offset = 0; offset <= _countdownWords.length; offset++)
      paragraph.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dy,
  ];
  final double spread = caretTops.reduce(math.max) - caretTops.reduce(math.min);
  expect(spread, lessThan(paragraph.preferredLineHeight / 2));
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(tester.getRect(words).width, closeTo(paragraph.size.width, 0.01));
  final Rect line = tester.getRect(find.byType(RecorderStatusLine));
  expect(line.left, greaterThanOrEqualTo(0));
  expect(line.right, lessThanOrEqualTo(windowWidth));
  expect(tester.takeException(), isNull);
}

VoiceRecorderSheet _breathingVoice() => VoiceRecorderSheet(
  phase: VoiceRecorderPhase.breathing,
  onStart: () {},
  onStop: () {},
  onCancel: () {},
);

VideoRecorderSheet _breathingVideo() => VideoRecorderSheet(
  phase: VideoRecorderPhase.breathing,
  onStart: () {},
  onStop: () {},
  onLeave: () {},
);

Future<void> _expectOneLineThroughTheBreath(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size window,
  required Widget recorder,
}) async {
  _useSize(tester, platform, window);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(_recorderApp(platform, recorder));
  await tester.pump();
  final List<String> numerals = <String>[];
  int at = 0;
  for (final int next in <int>[0, 1000, 2000, 2500]) {
    await tester.pump(Duration(milliseconds: next - at));
    at = next;
    numerals.add(_shownNumeral(tester));
    expect(_words(tester), _countdownWords);
    _expectOneLine(tester, window.width);
  }
  expect(numerals, <String>['3', '2', '1', '1']);
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  testWidgets('each stage phase shows its own status text and announcement', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS);
    final SemanticsHandle semantics = tester.ensureSemantics();
    const Map<StagePhase, String> expectedText = <StagePhase, String>{
      StagePhase.idle: 'Tap when you’re ready. There’s no wrong way to say it.',
      StagePhase.breathing: 'Breathe in… recording starts in',
      StagePhase.recording: 'I’m listening. Take your time.',
      StagePhase.paused: 'Paused. Nothing’s lost.',
      StagePhase.saving: _savingText,
    };
    const Map<StagePhase, String> expectedAnnouncement = <StagePhase, String>{
      StagePhase.idle: 'Ready to record',
      StagePhase.breathing: 'Recording starts in 3',
      StagePhase.recording: 'Recording',
      StagePhase.paused: 'Paused',
      StagePhase.saving: 'Saving',
    };

    final Set<String> shown = <String>{};
    for (final StagePhase phase in StagePhase.values) {
      await _pumpLine(tester, phase: phase, inline: false);
      final Text status = tester.widget<Text>(
        find.byKey(recorderStatusTextKey),
      );
      expect(status.data, expectedText[phase], reason: phase.name);
      shown.add(status.data!);
      expect(
        tester.getSemantics(find.byKey(recorderStatusTextKey)),
        isSemantics(
          label: expectedAnnouncement[phase],
          value: phase == StagePhase.breathing ? '' : expectedText[phase],
          isLiveRegion: true,
        ),
        reason: phase.name,
      );
    }
    expect(shown, hasLength(StagePhase.values.length));

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _pumpLine(
      tester,
      phase: StagePhase.idle,
      inline: false,
      platform: TargetPlatform.android,
    );
    expect(
      tester.widget<Text>(find.byKey(recorderStatusTextKey)).data,
      'Tap when you’re ready.',
    );

    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the soft timer shows only while recording or paused', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS);
    for (final bool inline in <bool>[false, true]) {
      for (final StagePhase phase in StagePhase.values) {
        await _pumpLine(tester, phase: phase, inline: inline);
        final bool shows =
            phase == StagePhase.recording || phase == StagePhase.paused;
        expect(
          find.text(_elapsedText),
          shows ? findsOneWidget : findsNothing,
          reason: '${phase.name} inline: $inline',
        );
      }
    }

    await _pumpLine(tester, phase: StagePhase.recording, inline: false);
    final Rect stackedStatus = tester.getRect(
      find.byKey(recorderStatusTextKey),
    );
    final Rect stackedTimer = tester.getRect(find.text(_elapsedText));
    expect(stackedTimer.top, greaterThanOrEqualTo(stackedStatus.bottom));

    await _pumpLine(tester, phase: StagePhase.paused, inline: true);
    final Rect inlineStatus = tester.getRect(find.byKey(recorderStatusTextKey));
    final Rect inlineTimer = tester.getRect(find.text(_elapsedText));
    expect(inlineTimer.left, greaterThanOrEqualTo(inlineStatus.right));
    expect(inlineTimer.center.dy, closeTo(inlineStatus.center.dy, 8));
    expect(find.byKey(recorderStatusDotKey), findsOneWidget);
    expect(
      tester.getRect(find.byKey(recorderStatusDotKey)).right,
      lessThanOrEqualTo(inlineStatus.left),
    );

    final Text timer = tester.widget<Text>(find.text(_elapsedText));
    expect(timer.style?.color, const Color(0xFFB7A58C));
    expect(timer.style?.fontSize, 12);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the timer is not inside the live region', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.android);
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpLine(
      tester,
      phase: StagePhase.recording,
      inline: false,
      platform: TargetPlatform.android,
    );

    final SemanticsNode status = tester.getSemantics(
      find.byKey(recorderStatusTextKey),
    );
    final SemanticsNode timer = tester.getSemantics(find.text(_elapsedText));
    expect(identical(status, timer), isFalse);
    expect(timer, isNot(isSemantics(isLiveRegion: true)));

    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the countdown reads 3, 2 then 1 a second apart', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS);
    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.breathing, inline: false),
    );
    await tester.pump();

    final List<String> numerals = <String>[];
    int at = 0;
    for (final int next in <int>[0, 500, 1000, 1500, 2000, 2900]) {
      await tester.pump(Duration(milliseconds: next - at));
      at = next;
      numerals.add(_shownNumeral(tester));
      expect(_words(tester), 'Breathe in… recording starts in');
    }
    expect(numerals, <String>['3', '3', '2', '2', '1', '1']);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the countdown stays at 1 when the breath runs long', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.android);
    await tester.pumpWidget(
      _countdownApp(
        phase: StagePhase.breathing,
        inline: false,
        platform: TargetPlatform.android,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3500));

    expect(_shownNumeral(tester), '1');
    expect(_words(tester), 'Breathe in… recording starts in');
    expect(
      tester.widget<Text>(find.byKey(recorderStatusTextKey)).style?.fontSize,
      18,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a new breath counts from 3 again', (WidgetTester tester) async {
    _useWindow(tester, TargetPlatform.macOS);
    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.breathing, inline: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));
    expect(_shownNumeral(tester), '1');

    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.recording, inline: true),
    );
    await tester.pump();
    expect(_words(tester), _recordingText);

    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.breathing, inline: true),
    );
    expect(_shownNumeral(tester), '3');
    expect(_words(tester), 'Breathe in… recording starts in');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the numeral is larger, light and boxed', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS);
    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.breathing, inline: false),
    );
    await tester.pump();

    final List<double> wordLefts = <double>[];
    final List<double> wordBaselines = <double>[];
    final List<String> numerals = <String>[];
    for (int step = 0; step < 3; step++) {
      if (step > 0) {
        await tester.pump(const Duration(milliseconds: 780));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 220));
      final String digit = _shownNumeral(tester);
      numerals.add(digit);
      final Text numeral = tester.widget<Text>(_numeral(digit));
      expect(numeral.style?.fontSize, 26.25);
      expect(numeral.style?.color?.toARGB32(), _numeralInk.toARGB32());
      final Size box = tester.getSize(
        find
            .ancestor(
              of: _numeral(digit),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(box.width, greaterThanOrEqualTo(12.6));
      expect(_numeralOpacity(tester), closeTo(1, 0.01));
      expect(_numeralScale(tester), closeTo(1, 0.01));

      final Text words = tester.widget<Text>(find.byKey(recorderStatusTextKey));
      expect(words.style?.fontSize, 21);
      final double wordsBaseline = _baselineOf(
        tester,
        find.byKey(recorderStatusTextKey),
      );
      wordLefts.add(tester.getTopLeft(find.byKey(recorderStatusTextKey)).dx);
      wordBaselines.add(wordsBaseline);
      expect(
        _baselineOf(tester, _numeral(digit)),
        closeTo(wordsBaseline, 0.01),
      );
    }
    expect(numerals, <String>['3', '2', '1']);
    expect(wordLefts.toSet(), hasLength(1));
    expect(wordBaselines.toSet(), hasLength(1));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('each numeral fades in, holds and fades out over a second', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS);
    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.breathing, inline: false),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2000));
    expect(_shownNumeral(tester), '1');
    await tester.pump();

    expect(_numeralOpacity(tester), closeTo(0, 0.01));
    expect(_numeralScale(tester), closeTo(1.3, 0.01));

    await tester.pump(const Duration(milliseconds: 110));
    expect(
      _numeralOpacity(tester),
      closeTo(Curves.easeOut.transform(0.5), 0.01),
    );

    await tester.pump(const Duration(milliseconds: 110));
    expect(_numeralOpacity(tester), closeTo(1, 0.01));
    expect(_numeralScale(tester), closeTo(1.0, 0.01));

    await tester.pump(const Duration(milliseconds: 280));
    expect(_numeralOpacity(tester), closeTo(1, 0.01));
    expect(_numeralScale(tester), lessThan(1.0));
    expect(_numeralScale(tester), greaterThan(0.98));

    await tester.pump(const Duration(milliseconds: 300));
    expect(_numeralOpacity(tester), closeTo(1, 0.01));
    expect(_numeralScale(tester), closeTo(0.98, 0.01));

    await tester.pump(const Duration(milliseconds: 200));
    expect(_numeralOpacity(tester), closeTo(0, 0.01));
    expect(_numeralScale(tester), closeTo(0.9, 0.01));
    expect(_shownNumeral(tester), '1');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('with reduced motion the numeral is steady', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS);
    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.breathing, inline: false, still: true),
    );
    await tester.pump();

    final List<String> numerals = <String>[];
    int at = 0;
    for (final int next in <int>[0, 500, 1000, 1500, 2000, 2500, 3000]) {
      await tester.pump(Duration(milliseconds: next - at));
      at = next;
      numerals.add(_shownNumeral(tester));
      expect(_numeralOpacity(tester), 1, reason: '$next ms');
      expect(_numeralScale(tester), 1, reason: '$next ms');
    }
    expect(numerals, <String>['3', '3', '2', '2', '1', '1', '1']);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('switching reduced motion mid-countdown steadies the numeral', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS);
    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.breathing, inline: false),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_shownNumeral(tester), '3');
    expect(_numeralScale(tester), lessThan(1));

    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.breathing, inline: false, still: true),
    );
    expect(_shownNumeral(tester), '3');
    expect(_numeralOpacity(tester), 1);
    expect(_numeralScale(tester), 1);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the breath is announced once and the numerals are silent', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS);
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.breathing, inline: false),
    );
    await tester.pump();

    final List<String> numerals = <String>[];
    int at = 0;
    for (final int next in <int>[0, 1100, 2100]) {
      await tester.pump(Duration(milliseconds: next - at));
      at = next;
      numerals.add(_shownNumeral(tester));
      final SemanticsNode node = tester.getSemantics(
        find.byKey(recorderStatusTextKey),
      );
      expect(
        node,
        isSemantics(
          label: 'Recording starts in 3',
          value: '',
          isLiveRegion: true,
        ),
        reason: '$next ms',
      );
      expect(node.label, 'Recording starts in 3');
      expect(node.value, '');
      expect(find.bySemanticsLabel(RegExp(r'^[123]$')), findsNothing);
    }
    expect(numerals, <String>['3', '2', '1']);
    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('recording is announced when it starts', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS);
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.breathing, inline: false),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(
      tester.getSemantics(find.byKey(recorderStatusTextKey)),
      isSemantics(label: _breathAnnouncement, value: '', isLiveRegion: true),
    );

    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.recording, inline: false),
    );
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(recorderStatusTextKey)),
      isSemantics(
        label: 'Recording',
        value: 'I’m listening. Take your time.',
        isLiveRegion: true,
      ),
    );
    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('paused and saving keep their announcements', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS);
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.breathing, inline: false),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(
      tester.getSemantics(find.byKey(recorderStatusTextKey)),
      isSemantics(label: _breathAnnouncement, value: '', isLiveRegion: true),
    );

    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.paused, inline: false),
    );
    await tester.pump();
    expect(_words(tester), _pausedText);
    expect(_numeral('2'), findsNothing);
    expect(
      tester.getSemantics(find.byKey(recorderStatusTextKey)),
      isSemantics(
        label: 'Paused',
        value: 'Paused. Nothing’s lost.',
        isLiveRegion: true,
      ),
    );

    await tester.pumpWidget(
      _countdownApp(phase: StagePhase.saving, inline: false),
    );
    await tester.pump();
    expect(_words(tester), _savingText);
    expect(
      tester.getSemantics(find.byKey(recorderStatusTextKey)),
      isSemantics(
        label: 'Saving',
        value: 'Saving your recording…',
        isLiveRegion: true,
      ),
    );
    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the countdown fits one line on a 384 px phone', (
    WidgetTester tester,
  ) async {
    await _expectOneLineThroughTheBreath(
      tester,
      platform: TargetPlatform.android,
      window: const Size(384, 832),
      recorder: _breathingVoice(),
    );
    await _expectOneLineThroughTheBreath(
      tester,
      platform: TargetPlatform.android,
      window: const Size(384, 832),
      recorder: _breathingVideo(),
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the countdown fits one line in the narrowest desktop window', (
    WidgetTester tester,
  ) async {
    await _expectOneLineThroughTheBreath(
      tester,
      platform: TargetPlatform.macOS,
      window: const Size(872.4, 600),
      recorder: _breathingVoice(),
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
