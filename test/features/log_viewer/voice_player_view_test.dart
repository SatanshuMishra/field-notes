import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/dialog_host.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/audio_playback.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';
import 'package:field_notes/features/log_viewer/viewer_waveform.dart';
import 'package:field_notes/features/log_viewer/voice_player_view.dart';

import '../entry_cards/support/entry_cards_harness.dart';
import '../entry_cards/support/fake_audio_player.dart';

const Color _ground = Color(0xFF1C1713);
const Color _rose = Color(0xFFB8566A);
const Color _played = Color(0xFFE3889A);
const Color _ink = Color(0xFFF3E6D1);

const double _statusBar = 34;
const double _gestureBar = 24;
const int _durationMs = 98000;
const String _mediaId = 'voice-media';
const String _dayTitle = 'Thursday 2 October';
const String _idleTime = '0:00 / 1:38';

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

void _mac(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
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

Entry _voiceEntry() {
  return entryOf(
    type: EntryType.voice,
    id: 'voice-entry',
    mediaId: _mediaId,
    durationMs: _durationMs,
  );
}

LogViewerScene _scene(
  _Calls calls, {
  bool earlier = true,
  bool later = true,
  LogViewerExit exit = LogViewerExit.close,
}) {
  return LogViewerScene(
    entry: _voiceEntry(),
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
  );
}

Widget _host(
  LogViewerScene scene, {
  required MediaResolver resolver,
  required EntryAudioPlayer player,
  required TargetPlatform platform,
  Brightness brightness = Brightness.dark,
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

bool _framesContent(Widget widget) {
  if (widget is CustomPaint) {
    return true;
  }
  if (widget is! DecoratedBox) {
    return false;
  }
  final Decoration decoration = widget.decoration;
  return decoration is! BoxDecoration ||
      decoration.border != null ||
      decoration.color != null;
}

Finder _groundBox() {
  return _inStage(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is ColoredBox && widget.color.toARGB32() == _ground.toARGB32(),
    ),
  ).first;
}

Finder _playCircle() {
  return find.descendant(
    of: find.byType(ViewerPrimaryButton),
    matching: find.byWidgetPredicate((Widget widget) {
      if (widget is! DecoratedBox) {
        return false;
      }
      final Decoration decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.shape == BoxShape.circle &&
          decoration.color != null;
    }),
  );
}

int _circleColour(WidgetTester tester) {
  final DecoratedBox circle = tester.widget<DecoratedBox>(_playCircle());
  return (circle.decoration as BoxDecoration).color!.toARGB32();
}

TextStyle _timeStyle(WidgetTester tester) {
  final Text time = tester.widget<Text>(find.text(_idleTime));
  return time.textSpan!.style!;
}

List<int> _barColours(WidgetTester tester) {
  final Finder paint = find.descendant(
    of: find.byType(ViewerWaveform),
    matching: find.byType(CustomPaint),
  );
  final CustomPaint custom = tester.widget<CustomPaint>(paint);
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  custom.painter!.paint(canvas, tester.getSize(paint));
  return <int>[
    for (final RecordedInvocation call in canvas.invocations)
      if (call.invocation.memberName == #drawRRect)
        (call.invocation.positionalArguments[1] as Paint).color.toARGB32(),
  ];
}

List<BackdropKey?> _backdropKeysIn(WidgetTester tester, Type chrome) => tester
    .renderObjectList<RenderBackdropFilter>(
      find.descendant(
        of: find.byType(chrome),
        matching: find.byType(BackdropFilter),
      ),
    )
    .map((RenderBackdropFilter filter) => filter.backdropKey)
    .toList();

void main() {
  testWidgets('the phone voice player shows only the player', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    _phone(tester);
    final File file = _recording();
    final int unplayed = _ink.withValues(alpha: 0.28).toARGB32();
    final int tallUnplayed = _ink.withValues(alpha: 0.46).toARGB32();

    for (final Brightness brightness in Brightness.values) {
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

      expect(tester.getRect(_groundBox()), const Rect.fromLTWH(0, 0, 384, 832));

      final Rect wave = tester.getRect(find.byType(ViewerWaveform));
      expect(wave.height, 176);
      expect(wave.left, 22);
      expect(wave.right, 384 - 22);
      expect(wave.center.dy, 832 / 2);

      final Iterable<DecoratedBox> waveAncestors = tester
          .widgetList<DecoratedBox>(
            find.ancestor(
              of: find.byType(ViewerWaveform),
              matching: find.byType(DecoratedBox),
            ),
          );
      expect(
        waveAncestors.where((DecoratedBox box) {
          final Decoration decoration = box.decoration;
          return decoration is BoxDecoration && decoration.border != null;
        }),
        isEmpty,
      );

      final List<int> bars = _barColours(tester);
      expect(bars, isNotEmpty);
      expect(bars.toSet(), <int>{unplayed, tallUnplayed});

      expect(
        tester.getSemantics(find.byType(ViewerWaveform)),
        isSemantics(
          label: 'Playback position',
          value: '0:00 of 1:38',
          increasedValue: '0:05 of 1:38',
          decreasedValue: '0:00 of 1:38',
          isSlider: true,
          isEnabled: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );

      final TextStyle time = _timeStyle(tester);
      expect(time.fontSize, 48);
      expect(time.fontFamily, TypographyTokens.serif);
      expect(time.color!.toARGB32(), _ink.toARGB32());
      final Rect timeRect = tester.getRect(find.text(_idleTime));
      expect(timeRect.top, greaterThan(wave.bottom));
      expect(timeRect.center.dx, closeTo(192, 0.5));

      final ViewerQuietLine quiet = tester.widget<ViewerQuietLine>(
        find.byType(ViewerQuietLine),
      );
      expect(quiet.text, startsWith(_dayTitle));
      final Rect quietRect = tester.getRect(find.byType(ViewerQuietLine));
      expect(quietRect.top, greaterThanOrEqualTo(_statusBar));
      expect(quietRect.bottom, lessThan(wave.top));
      expect(quietRect.center.dx, closeTo(192, 0.5));

      expect(_playCircle(), findsOneWidget);
      expect(tester.getSize(_playCircle()), const Size(68, 68));
      expect(_circleColour(tester), _rose.toARGB32());

      final ViewerDock dock = tester.widget<ViewerDock>(
        find.byType(ViewerDock),
      );
      expect(dock.slots, hasLength(5));
      for (final String label in <String>[
        'Close',
        'Earlier',
        'Play',
        'Later',
        'Delete',
      ]) {
        expect(
          find.descendant(
            of: find.byType(ViewerDock),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }

      const double column = (384 - 32) / 5;
      final List<Finder> controls = <Finder>[
        find.byKey(logViewerBackKey),
        find.byKey(logViewerEarlierKey),
        find.byType(ViewerPrimaryButton),
        find.byKey(logViewerLaterKey),
        find.byKey(logActionsDeleteKey),
      ];
      for (int index = 0; index < controls.length; index++) {
        final Rect control = tester.getRect(controls[index]);
        expect(control.center.dx, closeTo(16 + column * (index + 0.5), 0.5));
        expect(control.width, greaterThanOrEqualTo(48));
        expect(control.height, greaterThanOrEqualTo(48));
        expect(control.top, greaterThan(timeRect.bottom));
      }

      for (final String label in <String>[
        'Close',
        logViewerEarlierLabel,
        'Play',
        logViewerLaterLabel,
        'Delete',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }

      final List<String> texts = <String>[
        for (final Text text in tester.widgetList<Text>(
          _inStage(find.byType(Text)),
        ))
          text.data ?? text.textSpan!.toPlainText(),
      ];
      expect(texts, hasLength(7));
      expect(texts.toSet(), <String>{
        quiet.text,
        _idleTime,
        'Close',
        'Earlier',
        'Play',
        'Later',
        'Delete',
      });
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

    final Rect wave = tester.getRect(find.byType(ViewerWaveform));
    await tester.tapAt(Offset(wave.left + wave.width * 0.75, wave.center.dy));
    await tester.pump();
    expect(player.seeks, <Duration>[
      const Duration(milliseconds: _durationMs * 3 ~/ 4),
    ]);
    expect(calls.earlier, 0);
    expect(calls.later, 0);

    player.emitState(AudioPlaybackState.playing);
    player.emitPosition(const Duration(milliseconds: _durationMs * 3 ~/ 4));
    await tester.pump();
    final Set<int> playing = _barColours(tester).toSet();
    expect(playing, contains(_played.toARGB32()));
    expect(playing, contains(_ink.toARGB32()));
    expect(playing, contains(_ink.withValues(alpha: 0.28).toARGB32()));

    final int tapped = player.seeks.length;
    const double dragEnd = 80;
    await tester.dragFrom(
      Offset(wave.right - 20, wave.center.dy),
      Offset(dragEnd - (wave.width - 20), 0),
    );
    await tester.pump();
    expect(player.seeks.length, greaterThan(tapped + 1));
    expect(
      player.seeks.last.inMilliseconds,
      closeTo(dragEnd / wave.width * _durationMs, 1),
    );
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
    expect(player.seeks, hasLength(dragged));
  });

  testWidgets('the Mac voice player fills the window below the title bar', (
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

    final Rect wave = tester.getRect(find.byType(ViewerWaveform));
    expect(wave.size, const Size(960, 200));
    expect(wave.center.dx, 720);
    expect(wave.center.dy, 42 + (900 - 42) / 2);

    expect(_timeStyle(tester).fontSize, 56);
    expect(tester.getRect(find.text(_idleTime)).top, greaterThan(wave.bottom));

    expect(tester.getRect(find.byKey(logViewerBackKey)).left, 18);
    expect(tester.getRect(find.byKey(logActionsDeleteKey)).right, 1440 - 18);
    expect(
      tester.getRect(find.byType(ViewerQuietLine)).center.dx,
      closeTo(720, 0.5),
    );

    expect(_playCircle(), findsOneWidget);
    expect(tester.getSize(_playCircle()), const Size(56, 56));
    expect(_circleColour(tester), _rose.toARGB32());
    final Rect capsule = tester.getRect(find.byType(ViewerCapsule));
    expect(capsule.bottom, 900 - 30);
    expect(capsule.center.dx, closeTo(720, 0.5));
    final double playX = tester.getRect(_playCircle()).center.dx;
    expect(playX, closeTo(720, 0.5));
    expect(
      find.descendant(
        of: find.byType(ViewerCapsule),
        matching: find.byKey(logViewerEarlierKey),
      ),
      findsOneWidget,
    );

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
    expect(tester.getRect(_playCircle()).center.dx, playX);
    expect(tester.getRect(find.byType(ViewerCapsule)).bottom, 900 - 30);
  });

  testWidgets('Space, arrows and Esc drive the Mac voice player', (
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

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(calls.earlier, 1);
    expect(calls.later, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(calls.later, 1);
    expect(calls.earlier, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(calls.back, 1);
    expect(calls.delete, 0);
  });

  testWidgets('an unavailable recording keeps the controls and disables Play', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    _phone(tester);
    const Rect waveSlot = Rect.fromLTWH(22, (832 - 176) / 2, 384 - 44, 176);
    for (final Brightness brightness in Brightness.values) {
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
      expect(find.byType(ViewerWaveform), findsNothing);
      final Finder message = find.text("Can't play this recording");
      expect(message, findsOneWidget);
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      final Rect shown = tester.getRect(message);
      expect(shown.center, waveSlot.center);
      expect(shown.width, lessThanOrEqualTo(waveSlot.width));
      expect(shown.height, lessThanOrEqualTo(waveSlot.height));
      final TextStyle style = tester.widget<Text>(message).style!;
      final TextStyle caption = tester.element(message).textStyles.captionSans;
      expect(style.color?.toARGB32(), _ink.toARGB32());
      expect(style.fontFamily, caption.fontFamily);
      expect(style.fontSize, caption.fontSize);
      expect(
        find.ancestor(
          of: message,
          matching: _inStage(find.byWidgetPredicate(_framesContent)),
        ),
        findsNothing,
      );

      expect(find.byKey(logViewerBackKey), findsOneWidget);
      expect(find.byKey(logViewerEarlierKey), findsOneWidget);
      expect(find.byKey(logViewerLaterKey), findsOneWidget);
      expect(find.byKey(logActionsDeleteKey), findsOneWidget);
      expect(
        tester
            .widget<ViewerPrimaryButton>(find.byType(ViewerPrimaryButton))
            .onPressed,
        isNull,
      );
      expect(
        tester.getSemantics(find.byType(ViewerPrimaryButton)),
        isSemantics(label: 'Play', isButton: true, isEnabled: false),
      );

      await tester.tap(find.byType(ViewerPrimaryButton));
      await tester.pump();
      expect(player.playCalls, 0);
    }

    handle.dispose();
  });

  testWidgets(
    'the phone dock glass shares one read and the Mac capsule keeps its own',
    (WidgetTester tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _scene(_Calls()),
          resolver: _resolverFor(_recording()),
          player: FakeEntryAudioPlayer(),
          platform: TargetPlatform.android,
        ),
      );
      await _settle(tester);
      final List<BackdropKey?> dock = _backdropKeysIn(tester, ViewerDock);
      expect(dock, hasLength(4));
      expect(dock.first, isNotNull);
      expect(dock.toSet(), hasLength(1));

      _mac(tester);
      await tester.pumpWidget(
        _host(
          _scene(_Calls()),
          resolver: _resolverFor(_recording()),
          player: FakeEntryAudioPlayer(),
          platform: TargetPlatform.macOS,
        ),
      );
      await _settle(tester);
      final List<BackdropKey?> capsule = _backdropKeysIn(tester, ViewerCapsule);
      expect(capsule, hasLength(3));
      expect(capsule, everyElement(isNull));
    },
  );
}
