import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/dialog_host.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/voice_waveform.dart';
import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/audio_playback.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/transport/transport_bar.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';
import 'package:field_notes/features/log_viewer/viewer_waveform.dart';
import 'package:field_notes/features/log_viewer/voice_player_view.dart';

import '../entry_cards/support/entry_cards_harness.dart';
import '../entry_cards/support/fake_audio_player.dart';

const Color _played = Color(0xFFE3889A);
const Color _ink = Color(0xFFF3E6D1);

const double _statusBar = 34;
const double _gestureBar = 24;
const int _durationMs = 98000;
const String _mediaId = 'voice-media';
const String _dayTitle = 'Thursday 2 October';
const String _totalTime = '1:38';

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

class _SeekingAudioPlayer extends FakeEntryAudioPlayer {
  final List<Duration> seeks = <Duration>[];

  @override
  Future<void> seek(Duration position) async => seeks.add(position);
}

final class _Calls {
  int back = 0;
  int earlier = 0;
  int later = 0;
  int delete = 0;
  final List<String?> titles = <String?>[];
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(384, 832);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  addTearDown(tester.view.reset);
}

void _mac(WidgetTester tester, {Size size = const Size(1440, 900)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

File _recording() {
  final Directory folder = Directory.systemTemp.createTempSync(
    'voice-player-view',
  );
  addTearDown(() => folder.deleteSync(recursive: true));
  return File('${folder.path}/voice.m4a')..writeAsBytesSync(const <int>[0]);
}

FakeMediaResolver _resolverFor(File file) {
  return FakeMediaResolver()..set(
    _mediaId,
    ResolvedMedia.available(
      blob: blobOf(id: _mediaId, relPath: 'voice.m4a', kind: MediaKind.audio),
      file: file,
    ),
  );
}

Entry _voiceEntry({List<double>? peaks = _peaks, String? title}) {
  return Entry(
    id: 'voice-entry',
    dayId: 'd1',
    type: EntryType.voice,
    title: title,
    mediaId: _mediaId,
    durationMs: _durationMs,
    createdAt: 0,
    updatedAt: 0,
    peaks: peaks,
  );
}

LogViewerScene _scene(
  _Calls calls, {
  bool earlier = true,
  bool later = true,
  LogViewerExit exit = LogViewerExit.close,
  Entry? entry,
}) {
  return LogViewerScene(
    entry: entry ?? _voiceEntry(),
    date: '2025-10-02',
    dayTitle: _dayTitle,
    mood: Mood.calm,
    index: earlier ? 1 : 0,
    count: 4,
    earlier: null,
    later: null,
    exit: exit,
    onBack: () => calls.back++,
    onEarlier: earlier ? () => calls.earlier++ : null,
    onLater: later ? () => calls.later++ : null,
    onDelete: () => calls.delete++,
    onEdit: null,
    onRename: calls.titles.add,
  );
}

Widget _host(
  LogViewerScene scene, {
  required MediaResolver resolver,
  required EntryAudioPlayer player,
  required TargetPlatform platform,
  Brightness brightness = Brightness.dark,
  bool embedded = false,
}) {
  return MaterialApp(
    key: ValueKey<String>('$platform-$brightness'),
    debugShowCheckedModeBanner: false,
    theme: fieldNotesTheme(platform: platform, brightness: brightness),
    home: DialogHost(
      child: VoicePlayerView(
        scene: scene,
        resolver: resolver,
        playerFactory: () => player,
        focus: PlaybackFocus(),
        embedded: embedded,
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Finder _inStage(Finder matching) =>
    find.descendant(of: find.byType(ViewerStage), matching: matching);

Finder get _play => find.byType(TransportPlayButton);

Finder get _wave => find.byType(VoiceWaveform);

Finder _groundBox() {
  return _inStage(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).gradient is RadialGradient &&
          widget.key == null,
    ),
  ).first;
}

Finder _wavePaint() => find.descendant(
  of: find.byType(ViewerWaveform),
  matching: find.byType(CustomPaint),
);

List<RecordedInvocation> _drawnRRects(WidgetTester tester) {
  final Finder paint = _wavePaint();
  final CustomPaint custom = tester.widget<CustomPaint>(paint);
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  custom.painter!.paint(canvas, tester.getSize(paint));
  return <RecordedInvocation>[
    for (final RecordedInvocation call in canvas.invocations)
      if (call.invocation.memberName == #drawRRect) call,
  ];
}

List<int> _barColours(WidgetTester tester) => <int>[
  for (final RecordedInvocation call in _drawnRRects(tester))
    (call.invocation.positionalArguments[1] as Paint).color.toARGB32(),
];

List<RRect> _barShapes(WidgetTester tester) => <RRect>[
  for (final RecordedInvocation call in _drawnRRects(tester))
    call.invocation.positionalArguments[0] as RRect,
];

void main() {
  testWidgets('the phone voice player follows the shared dock', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    _phone(tester);
    final File file = _recording();

    for (final (Brightness brightness, FieldNotesColors colors)
        in <(Brightness, FieldNotesColors)>[
          (Brightness.light, FieldNotesColors.light),
          (Brightness.dark, FieldNotesColors.dark),
        ]) {
      final _SeekingAudioPlayer player = _SeekingAudioPlayer();
      await tester.pumpWidget(
        _host(
          _scene(_Calls()),
          resolver: _resolverFor(file),
          player: player,
          platform: TargetPlatform.android,
          brightness: brightness,
        ),
      );
      await _settle(tester);
      expect(player.loadCalls, <String>[file.path]);

      final Finder ground = _groundBox();
      expect(tester.getRect(ground), const Rect.fromLTWH(0, 0, 384, 832));
      final RadialGradient radial =
          (tester.widget<DecoratedBox>(ground).decoration as BoxDecoration)
                  .gradient!
              as RadialGradient;
      expect(radial.colors.first, colors.viewerStage);
      expect(
        radial.colors.last,
        Color.lerp(colors.viewerStage, colors.viewerStageEdge, 0.4),
      );

      expect(find.byType(TransportDock), findsOneWidget);
      expect(find.byType(ViewerDock), findsNothing);
      expect(find.byType(ViewerTopBar), findsNothing);
      expect(find.byType(ViewerWaveform), findsNothing);
      expect(find.byKey(logActionsDeleteKey), findsNothing);

      final Rect wave = tester.getRect(_wave);
      expect(wave.height, 112);
      expect(wave.left, 20);
      expect(wave.right, 384 - 20);

      expect(find.textContaining(_dayTitle), findsOneWidget);
      expect(find.text('2 of 4'), findsOneWidget);
      expect(
        tester.widget<Text>(find.textContaining(_dayTitle)).style!.color,
        colors.ink,
      );
      expect(find.text(_totalTime), findsOneWidget);

      final List<Rect> dock = <Rect>[
        tester.getRect(find.byKey(transportDockBackKey)),
        tester.getRect(find.byKey(transportBack10Key)),
        tester.getRect(_play),
        tester.getRect(find.byKey(transportForward10Key)),
        tester.getRect(find.byKey(transportDockMoreKey)),
      ];
      for (final Rect control in dock) {
        expect(control.width.round(), greaterThanOrEqualTo(48));
        expect(control.height.round(), greaterThanOrEqualTo(48));
        expect(control.top, greaterThan(wave.bottom));
      }

      expect(tester.getRect(find.byKey(logViewerEarlierKey)).left, 4);
      expect(tester.getRect(find.byKey(logViewerLaterKey)).right, 384 - 4);
      for (final String label in <String>[
        'Close',
        logViewerEarlierLabel,
        'Play',
        logViewerLaterLabel,
        'More',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    }

    handle.dispose();
  });

  testWidgets('tapping or dragging the waveform seeks without changing log', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final File file = _recording();
    final _SeekingAudioPlayer player = _SeekingAudioPlayer();
    final _Calls calls = _Calls();
    await tester.pumpWidget(
      _host(
        _scene(calls),
        resolver: _resolverFor(file),
        player: player,
        platform: TargetPlatform.android,
      ),
    );
    await _settle(tester);

    final Rect wave = tester.getRect(_wave);
    await tester.tapAt(Offset(wave.left + wave.width * 0.75, wave.center.dy));
    await tester.pump();
    expect(player.seeks, hasLength(1));
    expect(
      player.seeks.single.inMilliseconds,
      closeTo(_durationMs * 3 / 4, 500),
    );
    expect(calls.earlier, 0);
    expect(calls.later, 0);

    final int tapped = player.seeks.length;
    await tester.dragFrom(
      Offset(wave.right - 20, wave.center.dy),
      Offset(100 - wave.width, 0),
    );
    await tester.pump();
    expect(player.seeks.length, greaterThan(tapped));
    expect(calls.later, 0);
    expect(calls.earlier, 0);

    final int dragged = player.seeks.length;
    await tester.flingFrom(
      Offset(wave.center.dx + 100, wave.top - 80),
      const Offset(-200, 0),
      1000,
    );
    await tester.pump();
    expect(calls.later, 1);
    expect(calls.earlier, 0);
    await tester.flingFrom(
      Offset(wave.center.dx - 100, wave.top - 80),
      const Offset(200, 0),
      1000,
    );
    await tester.pump();
    expect(calls.earlier, 1);
    expect(player.seeks, hasLength(dragged));
  });

  testWidgets('the embedded waveform draws 4 px bars with 3 px gaps', (
    WidgetTester tester,
  ) async {
    _mac(tester, size: const Size(756, 900));
    await tester.pumpWidget(
      _host(
        _scene(
          _Calls(),
          entry: _voiceEntry(peaks: List<double>.filled(40, 0.5)),
        ),
        resolver: _resolverFor(_recording()),
        player: _SeekingAudioPlayer(),
        platform: TargetPlatform.macOS,
        embedded: true,
      ),
    );
    await _settle(tester);

    expect(tester.getSize(_wavePaint()), const Size(700, 140));
    final List<RRect> bars = _barShapes(tester);
    expect(bars, hasLength(100));
    for (int index = 0; index < 100; index++) {
      final RRect bar = bars[index];
      expect(bar.left, closeTo(1.5 + 7 * index, 1e-9), reason: 'bar $index');
      expect(bar.width, closeTo(4, 1e-9), reason: 'bar $index width');
      expect(bar.height, closeTo(140, 1e-9), reason: 'bar $index height');
      expect(bar.top, closeTo(0, 1e-9), reason: 'bar $index top');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets("the viewer hands the entry's own peaks to the waveform", (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        _scene(_Calls()),
        resolver: _resolverFor(_recording()),
        player: _SeekingAudioPlayer(),
        platform: TargetPlatform.android,
      ),
    );
    await _settle(tester);

    expect(tester.widget<VoiceWaveform>(_wave).peaks, _peaks);
  });

  testWidgets('the embedded player colours what has played', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final _SeekingAudioPlayer player = _SeekingAudioPlayer();
    await tester.pumpWidget(
      _host(
        _scene(_Calls()),
        resolver: _resolverFor(_recording()),
        player: player,
        platform: TargetPlatform.android,
        embedded: true,
      ),
    );
    await _settle(tester);

    player.emitState(AudioPlaybackState.playing);
    player.emitPosition(const Duration(milliseconds: _durationMs ~/ 2));
    await tester.pump();

    final Set<int> playing = _barColours(tester).toSet();
    expect(playing, contains(_played.toARGB32()));
    expect(playing, contains(_ink.toARGB32()));
    expect(playing, contains(_ink.withValues(alpha: 0.28).toARGB32()));
  });

  testWidgets('the Mac voice player keeps steps at the window edges', (
    WidgetTester tester,
  ) async {
    _mac(tester);
    final File file = _recording();
    final FakeMediaResolver resolver = _resolverFor(file);
    final _SeekingAudioPlayer player = _SeekingAudioPlayer();
    final _Calls calls = _Calls();
    await tester.pumpWidget(
      _host(
        _scene(calls, exit: LogViewerExit.back),
        resolver: resolver,
        player: player,
        platform: TargetPlatform.macOS,
      ),
    );
    await _settle(tester);

    expect(
      tester.getRect(_groundBox()),
      const Rect.fromLTWH(0, 42, 1440, 900 - 42),
    );

    expect(find.byType(TransportBar), findsOneWidget);
    expect(find.byType(ViewerCapsule), findsNothing);
    final Rect wave = tester.getRect(_wave);
    expect(wave.size.width, 880);
    expect(wave.center.dx, 720);

    expect(tester.getRect(find.byKey(logViewerBackKey)).left, 16);
    expect(tester.getRect(find.byKey(logActionsDeleteKey)).right, 1440 - 16);
    expect(tester.getRect(find.byKey(logViewerEarlierKey)).left, 16);
    expect(tester.getRect(find.byKey(logViewerLaterKey)).right, 1440 - 16);
    expect(find.byKey(viewerTitleFieldKey), findsOneWidget);
    expect(find.text(viewerTitleHint), findsOneWidget);

    final Rect play = tester.getRect(_play);
    await tester.pumpWidget(
      _host(
        _scene(calls, earlier: false, exit: LogViewerExit.back),
        resolver: resolver,
        player: player,
        platform: TargetPlatform.macOS,
      ),
    );
    await _settle(tester);

    expect(find.byKey(logViewerEarlierKey), findsNothing);
    expect(find.byKey(logViewerLaterKey), findsOneWidget);
    expect(tester.getRect(_play), play);
  });

  testWidgets('Space plays, arrows seek and Page keys step on Mac', (
    WidgetTester tester,
  ) async {
    _mac(tester);
    final File file = _recording();
    final _SeekingAudioPlayer player = _SeekingAudioPlayer();
    final _Calls calls = _Calls();
    await tester.pumpWidget(
      _host(
        _scene(calls),
        resolver: _resolverFor(file),
        player: player,
        platform: TargetPlatform.macOS,
      ),
    );
    await _settle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(player.playCalls, 1);

    player.emitState(AudioPlaybackState.playing);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(player.pauseCalls, 1);
    player.emitPosition(const Duration(seconds: 20));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(player.seeks.last, const Duration(seconds: 15));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(player.seeks.last, greaterThan(const Duration(seconds: 15)));
    expect(calls.earlier, 0);
    expect(calls.later, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pump();
    expect(calls.earlier, 1);
    expect(calls.later, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(calls.later, 1);
    expect(calls.earlier, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(calls.back, 1);
    expect(calls.delete, 0);
  });

  testWidgets('a title shows in the top bar and renames from the phone sheet', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final _Calls calls = _Calls();
    await tester.pumpWidget(
      _host(
        _scene(calls, entry: _voiceEntry(title: 'Kitchen radio')),
        resolver: _resolverFor(_recording()),
        player: _SeekingAudioPlayer(),
        platform: TargetPlatform.android,
      ),
    );
    await _settle(tester);
    expect(find.text('Kitchen radio'), findsOneWidget);

    await tester.tap(find.byKey(transportDockMoreKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(viewerRenameRowKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(viewerTitleFieldKey), ' ');
    await tester.tap(find.byKey(viewerSaveTitleKey));
    await tester.pumpAndSettle();
    expect(calls.titles, <String?>[null]);
  });

  testWidgets('an unavailable recording keeps the controls and disables Play', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    _phone(tester);
    for (final (Brightness brightness, FieldNotesColors colors)
        in <(Brightness, FieldNotesColors)>[
          (Brightness.light, FieldNotesColors.light),
          (Brightness.dark, FieldNotesColors.dark),
        ]) {
      final _SeekingAudioPlayer player = _SeekingAudioPlayer();
      final _Calls calls = _Calls();
      await tester.pumpWidget(
        _host(
          _scene(calls),
          resolver: FakeMediaResolver(),
          player: player,
          platform: TargetPlatform.android,
          brightness: brightness,
        ),
      );
      await _settle(tester);

      expect(player.loadCalls, isEmpty);
      final Finder message = find.text("Can't play this recording");
      expect(message, findsOneWidget);
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      final Rect shown = tester.getRect(message);
      expect(shown.bottom, lessThan(tester.getRect(_wave).top));
      expect(
        shown.overlaps(tester.getRect(find.byKey(logViewerEarlierKey))),
        isFalse,
      );
      final TextStyle style = tester.widget<Text>(message).style!;
      final TextStyle caption = tester.element(message).textStyles.captionSans;
      expect(style.color, colors.ink);
      expect(style.fontFamily, caption.fontFamily);
      expect(style.fontSize, caption.fontSize);

      expect(find.byKey(transportDockBackKey), findsOneWidget);
      expect(find.byKey(transportDockMoreKey), findsOneWidget);
      expect(find.byKey(logViewerEarlierKey), findsOneWidget);
      expect(find.byKey(logViewerLaterKey), findsOneWidget);
      expect(tester.widget<TransportPlayButton>(_play).onPressed, isNull);
      expect(
        tester.getSemantics(_play),
        isSemantics(label: 'Play', isButton: true, isEnabled: false),
      );

      await tester.tap(_play, warnIfMissed: false);
      await tester.pump();
      expect(player.playCalls, 0);
    }

    handle.dispose();
  });
}
