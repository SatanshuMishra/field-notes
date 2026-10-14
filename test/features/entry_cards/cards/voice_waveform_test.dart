import 'dart:io';

import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/voice_body.dart';
import 'package:field_notes/features/entry_cards/cards/voice_waveform.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/audio_playback.dart';

import '../support/entry_cards_harness.dart';
import '../support/fake_audio_player.dart';

const double _barsHeight = 28;
const int _durationMs = 65000;
const Duration _settle = Duration(milliseconds: 200);

const List<double> _peaks = <double>[
  0.1,
  0.3,
  0.8,
  1.0,
  0.6,
  0.2,
  0.05,
  0.4,
  0.9,
  0.5,
  0.15,
  0.7,
];

class _SeekingPlayer extends FakeEntryAudioPlayer {
  final List<Duration> seekCalls = <Duration>[];

  @override
  Future<void> seek(Duration position) async => seekCalls.add(position);
}

FakeMediaResolver _resolver() => FakeMediaResolver()
  ..set(
    'aud',
    ResolvedMedia.available(
      blob: blobOf(id: 'aud', relPath: 'a.m4a', kind: MediaKind.audio),
      file: File('/tmp/a.m4a'),
    ),
  );

Entry _voiceEntry({String id = 'e1', List<double>? peaks = _peaks}) => Entry(
  id: id,
  dayId: 'd1',
  type: EntryType.voice,
  mediaId: 'aud',
  durationMs: _durationMs,
  createdAt: 0,
  updatedAt: 0,
  peaks: peaks,
);

Future<void> _pumpVoice(
  WidgetTester tester,
  EntryAudioPlayer player, {
  Entry? entry,
  MediaQueryData data = const MediaQueryData(),
  Widget Function(Widget card)? wrap,
}) async {
  final Widget card = cardHarness(
    VoiceBody(
      entry: entry ?? _voiceEntry(),
      resolver: _resolver(),
      playerFactory: () => player,
    ),
    data: data,
  );
  await tester.pumpWidget(wrap == null ? card : wrap(card));
  await tester.pump();
}

Future<void> _pumpWaveform(
  WidgetTester tester, {
  required List<double>? peaks,
  required double width,
}) async {
  await tester.pumpWidget(
    cardHarness(
      VoiceWaveform(peaks: peaks, active: false, progress: 0),
      width: width,
    ),
  );
}

int _barCount() => find
    .byWidgetPredicate(
      (Widget widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('voice-wave-bar-'),
    )
    .evaluate()
    .length;

List<Rect> _barRects(WidgetTester tester) => List<Rect>.generate(
  _barCount(),
  (int index) => tester.getRect(find.byKey(voiceWaveformBarKey(index))),
);

List<double> _heights(WidgetTester tester) => <double>[
  for (final Rect bar in _barRects(tester)) bar.height / _barsHeight,
];

void _expectHeights(WidgetTester tester, List<double> expected) {
  final List<double> heights = _heights(tester);
  expect(heights, hasLength(expected.length));
  for (int index = 0; index < expected.length; index++) {
    expect(
      heights[index],
      closeTo(expected[index], 1e-9),
      reason: 'bar $index height',
    );
  }
}

BoxDecoration _decorationIn(WidgetTester tester, Key key) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(
                of: find.byKey(key),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

int _barArgb(WidgetTester tester, int index) =>
    _decorationIn(tester, voiceWaveformBarKey(index)).color!.toARGB32();

List<SemanticsNode> _sliders() => find.semantics
    .byPredicate(
      (SemanticsNode node) => node.getSemanticsData().flagsCollection.isSlider,
    )
    .evaluate()
    .toList();

void _expectFixedBars(WidgetTester tester, int count) {
  final Rect wave = tester.getRect(find.byType(VoiceWaveform));
  final List<Rect> bars = _barRects(tester);
  expect(bars, hasLength(count));
  expect(bars.first.left, closeTo(wave.left, 1e-6));
  expect(bars.last.right, closeTo(wave.right, 1e-6));
  for (int index = 0; index < count; index++) {
    final Rect bar = bars[index];
    expect(bar.width, closeTo(3, 1e-9), reason: 'bar $index width');
    expect(
      bar.height,
      inInclusiveRange(_barsHeight * 0.07 - 1e-9, _barsHeight + 1e-9),
      reason: 'bar $index height',
    );
    expect(bar.center.dy, closeTo(wave.center.dy, 1e-6));
    if (index > 0) {
      final double gap = bar.left - bars[index - 1].right;
      expect(gap, greaterThanOrEqualTo(2 - 1e-9), reason: 'gap before $index');
      expect(gap, lessThan(2.1), reason: 'gap before $index');
    }
  }
}

void main() {
  testWidgets('bars are 3 wide with 2 gaps and the count follows the width', (
    WidgetTester tester,
  ) async {
    await _pumpWaveform(tester, peaks: _peaks, width: 300);
    _expectFixedBars(tester, 60);
    final List<double> wide = _heights(tester);

    await _pumpWaveform(tester, peaks: _peaks, width: 160);
    _expectFixedBars(tester, 32);

    await tester.pumpWidget(const SizedBox());
    await _pumpWaveform(tester, peaks: _peaks, width: 300);
    expect(_heights(tester), wide);

    await _pumpWaveform(tester, peaks: _peaks, width: 30);
    expect(_barRects(tester), hasLength(8));
    expect(tester.takeException(), isNull);

    await _pumpVoice(tester, _SeekingPlayer());
    final VoiceWaveform onCard = tester.widget<VoiceWaveform>(
      find.byType(VoiceWaveform),
    );
    expect(onCard.peaks, _peaks);
    expect(
      _barRects(tester),
      hasLength(
        voiceWaveformBarCount(tester.getSize(find.byType(VoiceWaveform)).width),
      ),
    );
  });

  testWidgets(
    'bars take 0.65 of the highest and 0.35 of the mean of their share',
    (WidgetTester tester) async {
      await _pumpWaveform(
        tester,
        peaks: const <double>[
          0.2,
          0.4,
          0.6,
          0.8,
          1.0,
          0.0,
          0.0,
          0.0,
          0.5,
          0.5,
          0.1,
          0.3,
          0.9,
          0.7,
          0.2,
          0.2,
        ],
        width: 38,
      );
      _expectHeights(tester, const <double>[
        0.365 / 0.865,
        0.765 / 0.865,
        0.825 / 0.865,
        0.07,
        0.5 / 0.865,
        0.265 / 0.865,
        1,
        0.2 / 0.865,
      ]);
    },
  );

  testWidgets('with few peaks each bar uses its nearest one or two', (
    WidgetTester tester,
  ) async {
    await _pumpWaveform(tester, peaks: const <double>[0.2, 1.0], width: 38);
    _expectHeights(tester, const <double>[0.2, 0.86, 0.86, 0.86, 1, 1, 1, 1]);
  });

  testWidgets('with as many peaks as bars each bar is one peak', (
    WidgetTester tester,
  ) async {
    await _pumpWaveform(
      tester,
      peaks: const <double>[0.5, 1.0, 0.25, 0.75, 0, 0, 0, 1],
      width: 38,
    );
    _expectHeights(tester, const <double>[
      0.5,
      1,
      0.25,
      0.75,
      0.07,
      0.07,
      0.07,
      1,
    ]);
  });

  testWidgets('no peaks draws a flat waveform', (WidgetTester tester) async {
    for (final List<double>? peaks in <List<double>?>[
      null,
      const <double>[],
      const <double>[0, 0, 0, 0, 0, 0],
    ]) {
      await tester.pumpWidget(const SizedBox());
      await _pumpVoice(
        tester,
        _SeekingPlayer(),
        entry: _voiceEntry(peaks: peaks),
      );
      final List<double> heights = _heights(tester);
      expect(heights, isNotEmpty, reason: 'peaks $peaks');
      for (int index = 0; index < heights.length; index++) {
        expect(
          heights[index],
          closeTo(0.07, 1e-9),
          reason: 'peaks $peaks bar $index',
        );
      }
    }
  });

  testWidgets('card bars from peaks spread across the card', (
    WidgetTester tester,
  ) async {
    final List<double> peaks = List<double>.filled(40, 0.5);

    await _pumpWaveform(tester, peaks: peaks, width: 30);
    final Rect narrowWave = tester.getRect(find.byType(VoiceWaveform));
    final List<Rect> narrow = _barRects(tester);
    expect(narrow, hasLength(8));
    const List<double> narrowLefts = <double>[0, 5, 10, 15, 20, 25, 30, 35];
    for (int index = 0; index < 8; index++) {
      expect(
        narrow[index].left - narrowWave.left,
        closeTo(narrowLefts[index], 1e-9),
        reason: 'bar $index left',
      );
      expect(narrow[index].width, closeTo(3, 1e-9), reason: 'bar $index');
      expect(
        narrow[index].height,
        closeTo(_barsHeight, 1e-9),
        reason: 'bar $index height',
      );
    }

    await _pumpWaveform(tester, peaks: peaks, width: 200);
    final Rect wideWave = tester.getRect(find.byType(VoiceWaveform));
    final List<Rect> wide = _barRects(tester);
    expect(wide, hasLength(40));
    for (int index = 0; index < 40; index++) {
      expect(
        wide[index].left - wideWave.left,
        closeTo(index * 197 / 39, 1e-9),
        reason: 'bar $index left',
      );
      expect(wide[index].width, closeTo(3, 1e-9), reason: 'bar $index');
      expect(
        wide[index].height,
        closeTo(_barsHeight, 1e-9),
        reason: 'bar $index height',
      );
    }
  });

  testWidgets('two entries with the same peaks draw the same bars', (
    WidgetTester tester,
  ) async {
    await _pumpVoice(
      tester,
      _SeekingPlayer(),
      entry: _voiceEntry(id: 'e1', peaks: <double>[0.1, 0.9, 0.4, 0.6, 0.2]),
    );
    final List<double> first = _heights(tester);
    expect(first, isNotEmpty);

    await tester.pumpWidget(const SizedBox());
    await _pumpVoice(
      tester,
      _SeekingPlayer(),
      entry: _voiceEntry(
        id: 'another-entry',
        peaks: <double>[0.1, 0.9, 0.4, 0.6, 0.2],
      ),
    );
    final List<double> second = _heights(tester);
    expect(second, first);

    await tester.pumpWidget(const SizedBox());
    await _pumpVoice(
      tester,
      _SeekingPlayer(),
      entry: _voiceEntry(
        id: 'another-entry',
        peaks: <double>[0.9, 0.1, 0.6, 0.4, 1.0],
      ),
    );
    final List<double> changed = _heights(tester);
    expect(changed, hasLength(first.length));
    expect(changed, isNot(first));
  });

  testWidgets(
    'playback colours played bars, shows a playhead and tapping seeks',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final _SeekingPlayer player = _SeekingPlayer();
      await _pumpVoice(tester, player);
      expect(find.byKey(voiceWaveformPlayheadKey), findsNothing);

      player.emitState(AudioPlaybackState.playing);
      player.emitPosition(const Duration(seconds: 26));
      await tester.pump();
      await tester.pump(_settle);

      final Rect wave = tester.getRect(find.byType(VoiceWaveform));
      final int count = _barRects(tester).length;
      expect(count, voiceWaveformBarCount(wave.width));
      final List<bool> played = <bool>[
        for (int index = 0; index < count; index++)
          _barArgb(tester, index) == Palette.coral.toARGB32(),
      ];
      for (int index = 0; index < count; index++) {
        expect(
          _barArgb(tester, index),
          (index + 0.5) / count <= 0.4
              ? Palette.coral.toARGB32()
              : FieldNotesColors.light.ink22.toARGB32(),
          reason: 'bar $index',
        );
      }
      final int playedCount = played.where((bool bar) => bar).length;
      expect(playedCount / count, closeTo(0.4, 1 / count));
      expect(played.sublist(0, playedCount), everyElement(isTrue));

      final Rect playhead = tester.getRect(
        find.byKey(voiceWaveformPlayheadKey),
      );
      expect(playhead.width, 2);
      expect(playhead.height, _barsHeight + 4);
      expect(playhead.center.dx, closeTo(wave.left + wave.width * 0.4, 1e-6));
      expect(playhead.center.dy, closeTo(wave.center.dy, 1e-6));
      final BoxDecoration line = _decorationIn(
        tester,
        voiceWaveformPlayheadKey,
      );
      expect(
        line.color!.toARGB32(),
        FieldNotesColors.light.accentInk.toARGB32(),
      );
      expect(line.boxShadow!.single.spreadRadius, 2);
      expect(
        line.boxShadow!.single.color.toARGB32(),
        Palette.coral.withValues(alpha: 0.18).toARGB32(),
      );

      final Finder label = find.text('0:26 / 1:05');
      expect(label, findsOneWidget);
      final Text text = tester.widget<Text>(label);
      expect(
        text.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(text.textAlign, TextAlign.right);
      expect(tester.getSize(label).width, greaterThanOrEqualTo(62));

      final List<SemanticsNode> sliders = _sliders();
      expect(sliders, hasLength(1));
      final SemanticsData slider = sliders.single.getSemanticsData();
      expect(slider.label, 'Playback position');
      expect(slider.value, '0:26 of 1:05');
      expect(slider.increasedValue, '0:31 of 1:05');
      expect(slider.decreasedValue, '0:21 of 1:05');
      expect(slider.hasAction(SemanticsAction.increase), isTrue);
      expect(slider.hasAction(SemanticsAction.decrease), isTrue);
      expect(sliders.single.childrenCount, 0);
      expect(sliders.single.rect.height, greaterThanOrEqualTo(44));
      expect(wave.height, greaterThanOrEqualTo(44));

      await tester.tapAt(Offset(wave.left + wave.width * 0.75, wave.center.dy));
      await tester.pump();
      expect(player.seekCalls, <Duration>[const Duration(milliseconds: 48750)]);
      expect(player.playCalls, 0);

      await tester.tapAt(
        Offset(wave.left + wave.width * 0.2, wave.center.dy - 21),
      );
      await tester.pump();
      expect(player.seekCalls.last, const Duration(milliseconds: 13000));
      expect(player.playCalls, 0);

      await tester.pump(_settle);
      final List<Rect> settled = _barRects(tester);
      await tester.pump(const Duration(milliseconds: 700));
      expect(_barRects(tester), settled);
      expect(find.byType(WaveformBars), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);

      handle.dispose();
    },
  );

  testWidgets(
    'tapping an idle log seeks and plays, a paused log stays paused',
    (WidgetTester tester) async {
      final _SeekingPlayer player = _SeekingPlayer();
      await _pumpVoice(tester, player);
      final Rect wave = tester.getRect(find.byType(VoiceWaveform));

      await tester.tapAt(Offset(wave.left + wave.width * 0.5, wave.center.dy));
      await tester.pump();
      expect(player.seekCalls, <Duration>[const Duration(milliseconds: 32500)]);
      expect(player.playCalls, 1);

      player.emitState(AudioPlaybackState.paused);
      player.emitPosition(const Duration(milliseconds: 32500));
      await tester.pump();
      await tester.pump(_settle);
      expect(
        tester.getRect(find.byKey(voiceWaveformPlayheadKey)).center.dx,
        closeTo(wave.left + wave.width * 0.5, 1e-6),
      );
      expect(_barArgb(tester, 0), Palette.coral.toARGB32());

      await tester.tapAt(Offset(wave.left + wave.width * 0.25, wave.center.dy));
      await tester.pump();
      expect(player.seekCalls.last, const Duration(milliseconds: 16250));
      expect(player.playCalls, 1);
      expect(player.pauseCalls, 0);

      player.emitState(AudioPlaybackState.completed);
      await tester.pump();
      await tester.pump(_settle);
      expect(find.byKey(voiceWaveformPlayheadKey), findsNothing);
      final List<double> heights = _heights(tester);
      for (int index = 0; index < heights.length; index++) {
        expect(
          _barArgb(tester, index),
          heights[index] > 0.62
              ? FieldNotesColors.light.waveMid.toARGB32()
              : FieldNotesColors.light.waveLight.toARGB32(),
          reason: 'bar $index',
        );
      }
    },
  );

  testWidgets('the slider steps five seconds without starting playback', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final _SeekingPlayer player = _SeekingPlayer();
    await _pumpVoice(tester, player);

    player.emitState(AudioPlaybackState.paused);
    player.emitPosition(const Duration(seconds: 20));
    await tester.pump();

    final SemanticsFinder slider = find.semantics.byPredicate(
      (SemanticsNode node) => node.getSemanticsData().flagsCollection.isSlider,
    );
    tester.semantics.increase(slider);
    await tester.pump();
    expect(player.seekCalls, <Duration>[const Duration(seconds: 25)]);
    expect(_sliders().single.getSemanticsData().value, '0:25 of 1:05');

    tester.semantics.decrease(slider);
    await tester.pump();
    expect(player.seekCalls.last, const Duration(seconds: 20));

    player.emitPosition(const Duration(seconds: 63));
    await tester.pump();
    tester.semantics.increase(slider);
    await tester.pump();
    expect(player.seekCalls.last, const Duration(seconds: 65));

    player.emitPosition(const Duration(seconds: 2));
    await tester.pump();
    tester.semantics.decrease(slider);
    await tester.pump();
    expect(player.seekCalls.last, Duration.zero);
    expect(player.playCalls, 0);

    handle.dispose();
  });

  testWidgets('dark theme colours apply at once when motion is reduced', (
    WidgetTester tester,
  ) async {
    final _SeekingPlayer player = _SeekingPlayer();
    await _pumpVoice(
      tester,
      player,
      data: const MediaQueryData(disableAnimations: true),
      wrap: (Widget card) => Theme(
        data: fieldNotesTheme(brightness: Brightness.dark),
        child: card,
      ),
    );

    final List<double> heights = _heights(tester);
    for (int index = 0; index < heights.length; index++) {
      expect(
        _barArgb(tester, index),
        heights[index] > 0.62
            ? FieldNotesColors.dark.waveMid.toARGB32()
            : FieldNotesColors.dark.waveLight.toARGB32(),
        reason: 'bar $index',
      );
    }

    player.emitState(AudioPlaybackState.playing);
    player.emitPosition(const Duration(seconds: 26));
    await tester.pump();
    final int count = heights.length;
    for (int index = 0; index < count; index++) {
      expect(
        _barArgb(tester, index),
        (index + 0.5) / count <= 0.4
            ? Palette.coral.toARGB32()
            : FieldNotesColors.dark.ink22.toARGB32(),
        reason: 'bar $index',
      );
    }
    expect(
      _decorationIn(tester, voiceWaveformPlayheadKey).color!.toARGB32(),
      FieldNotesColors.dark.accentInk.toARGB32(),
    );
  });
}
