import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/media/video_frames.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/cards/video_controls_overlay.dart';
import 'package:field_notes/features/entry_cards/cards/voice_body.dart';
import 'package:field_notes/features/entry_cards/cards/voice_waveform.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';
import 'package:field_notes/features/entry_cards/transport/transport.dart';
import 'package:field_notes/features/entry_cards/transport/transport_bar.dart';
import 'package:field_notes/features/entry_cards/transport/transport_timeline.dart';

import '../support/entry_cards_harness.dart';
import '../support/fake_audio_player.dart';
import '../support/fake_video_player.dart';

const Duration _total = Duration(seconds: 100);
const Duration _start = Duration(seconds: 30);
const Size _stage = Size(800, 600);

class _Calls {
  final List<Duration> seeks = <Duration>[];
  int toggles = 0;
  int fullScreens = 0;
}

TransportValue _value(
  _Calls calls, {
  bool playing = false,
  Duration position = _start,
}) => TransportValue(
  position: position,
  total: _total,
  isPlaying: playing,
  onToggle: () => calls.toggles += 1,
  onSeek: calls.seeks.add,
);

ThemeData _theme(TargetPlatform platform, Brightness brightness) =>
    fieldNotesTheme(brightness: brightness).copyWith(platform: platform);

Widget _host(
  Widget child, {
  TargetPlatform platform = TargetPlatform.macOS,
  Brightness brightness = Brightness.light,
  Size size = _stage,
}) => MaterialApp(
  theme: _theme(platform, brightness),
  home: Material(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox.fromSize(size: size, child: child),
    ),
  ),
);

Widget _videoCard(
  _Calls calls, {
  TargetPlatform platform = TargetPlatform.macOS,
  Brightness brightness = Brightness.light,
  PlaybackTuning? tuning,
  String? mediaPath,
}) => _host(
  Align(
    alignment: Alignment.bottomCenter,
    child: Transport(
      kind: TransportKind.video,
      mode: TransportMode.card,
      value: _value(calls),
      tuning: tuning ?? PlaybackTuning(),
      mediaPath: mediaPath,
    ),
  ),
  platform: platform,
  brightness: brightness,
);

Widget _viewer(
  _Calls calls, {
  required PlaybackTuning tuning,
  bool playing = false,
  TransportKind kind = TransportKind.video,
}) => _host(
  Transport(
    kind: kind,
    mode: TransportMode.viewer,
    value: _value(calls, playing: playing),
    tuning: tuning,
    autofocus: true,
    compact: false,
    onFullScreen: () => calls.fullScreens += 1,
  ),
);

Rect _timelineRect(WidgetTester tester) =>
    tester.getRect(find.byType(TransportTimeline));

Offset _timelineAt(WidgetTester tester, double share) {
  final Rect rail = _timelineRect(tester);
  return Offset(rail.left + rail.width * share, rail.center.dy);
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  return mouse;
}

class _RecordingFrames extends VideoFrames {
  _RecordingFrames(this.answer);

  final Uint8List? answer;
  final List<(String, Duration)> asked = <(String, Duration)>[];

  @override
  Future<Uint8List?> frameAt(String path, Duration position) async {
    asked.add((path, position));
    return answer;
  }
}

class _TunableAudio extends FakeEntryAudioPlayer implements TunablePlayer {
  final List<double> volumes = <double>[];
  final List<double> speeds = <double>[];

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> setSpeed(double speed) async => speeds.add(speed);
}

class _TunableVideo extends FakeEntryVideoPlayer implements TunablePlayer {
  final List<double> volumes = <double>[];
  final List<double> speeds = <double>[];

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> setSpeed(double speed) async => speeds.add(speed);
}

FakeMediaResolver _resolver(String id, MediaKind kind) =>
    FakeMediaResolver()..set(
      id,
      ResolvedMedia.available(
        blob: blobOf(id: id, relPath: 'media', kind: kind),
        file: File('/tmp/$id'),
      ),
    );

Widget _transportControls(BuildContext context, VideoControlsState state) =>
    Align(
      alignment: Alignment.bottomCenter,
      child: Transport(
        kind: TransportKind.video,
        mode: TransportMode.card,
        value: state.transport,
        tuning: state.tuning,
        mediaPath: state.mediaPath,
      ),
    );

Widget _videoBody(
  FakeEntryVideoPlayer player, {
  required PlaybackTuning tuning,
  TargetPlatform platform = TargetPlatform.macOS,
  VideoControlModel? model,
  VoidCallback? onFullScreen,
}) => _host(
  VideoBody(
    entry: entryOf(
      type: EntryType.video,
      mediaId: 'vid',
      durationMs: _total.inMilliseconds,
    ),
    resolver: _resolver('vid', MediaKind.video),
    playerFactory: () => player,
    slots: const UnlimitedVideoSlots(),
    controls: _transportControls,
    controlModel: model,
    tuning: tuning,
    onFullScreen: onFullScreen,
  ),
  platform: platform,
);

Widget _voiceBody(
  FakeEntryAudioPlayer player, {
  required PlaybackTuning tuning,
  TargetPlatform platform = TargetPlatform.macOS,
  Brightness brightness = Brightness.light,
}) => _host(
  Align(
    alignment: Alignment.bottomCenter,
    child: VoiceBody(
      entry: entryOf(
        type: EntryType.voice,
        mediaId: 'aud',
        durationMs: _total.inMilliseconds,
      ),
      resolver: _resolver('aud', MediaKind.audio),
      playerFactory: () => player,
      tuning: tuning,
    ),
  ),
  platform: platform,
  brightness: brightness,
);

BoxDecoration _bubbleDecoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byKey(transportBubbleKey),
                    matching: find.byType(DecoratedBox),
                  )
                  .last,
            )
            .decoration
        as BoxDecoration;

const Key _screenKey = ValueKey<String>('transport-test-screen');

Future<(Uint8List, int)> _capture(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_screenKey));
  final (Uint8List, int)? captured = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData? data = await image.toByteData();
    final int width = image.width;
    image.dispose();
    return (data!.buffer.asUint8List(), width);
  });
  return captured!;
}

Color _pixelAt((Uint8List, int) capture, Offset point) {
  final (Uint8List pixels, int width) = capture;
  final int index = (point.dy.floor() * width + point.dx.floor()) * 4;
  return Color.fromARGB(
    pixels[index + 3],
    pixels[index],
    pixels[index + 1],
    pixels[index + 2],
  );
}

void main() {
  group('timeline', () {
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.android,
    ]) {
      testWidgets(
        'a drag previews and seeks once on release on ${platform.name}',
        (WidgetTester tester) async {
          final _Calls calls = _Calls();
          await tester.pumpWidget(_videoCard(calls, platform: platform));

          final TestGesture drag = await tester.startGesture(
            _timelineAt(tester, 0.2),
          );
          await drag.moveTo(_timelineAt(tester, 0.3));
          await tester.pump();
          await drag.moveTo(_timelineAt(tester, 0.6));
          await tester.pump();
          expect(calls.seeks, isEmpty);
          expect(find.byKey(transportBubbleKey), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(transportBubbleKey),
              matching: find.text('1:00'),
            ),
            findsOneWidget,
          );

          await drag.up();
          await tester.pump();
          expect(calls.seeks, <Duration>[const Duration(seconds: 60)]);
        },
      );
    }

    testWidgets('dragging the voice waveform seeks', (
      WidgetTester tester,
    ) async {
      final _Calls calls = _Calls();
      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.bottomCenter,
            child: Transport(
              kind: TransportKind.voice,
              mode: TransportMode.card,
              value: _value(calls),
              peaks: const <double>[0.2, 0.9, 0.4],
              tuning: PlaybackTuning(),
            ),
          ),
        ),
      );

      final Rect wave = tester.getRect(find.byType(VoiceWaveform));
      final TestGesture drag = await tester.startGesture(
        Offset(wave.left + wave.width * 0.1, wave.center.dy),
      );
      await drag.moveTo(Offset(wave.left + wave.width * 0.4, wave.center.dy));
      await tester.pump();
      await drag.up();
      await tester.pump();

      expect(calls.seeks, <Duration>[const Duration(seconds: 40)]);
    });

    testWidgets(
      'hover floats the time at the pointer over a ghost line and paints no fill',
      (WidgetTester tester) async {
        final _Calls calls = _Calls();
        await tester.pumpWidget(_videoCard(calls));
        final TestGesture mouse = await _mouse(tester);

        await mouse.moveTo(_timelineAt(tester, 0.25));
        await tester.pump();

        final Finder bubble = find.byKey(transportBubbleKey);
        expect(bubble, findsOneWidget);
        expect(
          find.descendant(of: bubble, matching: find.text('0:25')),
          findsOneWidget,
        );
        final Rect ghost = tester.getRect(find.byKey(transportGhostKey));
        expect(ghost.center.dx, closeTo(_timelineAt(tester, 0.25).dx, 1e-6));
        expect(ghost.width, 2);
        expect(
          tester.getRect(bubble).bottom,
          lessThan(_timelineRect(tester).top),
        );
        final BoxDecoration fill =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byKey(transportVideoTimelineKey),
                        matching: find.byKey(pressableHoverFillKey),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        expect(fill.color, isNull);

        await mouse.moveTo(Offset.zero);
        await tester.pump();
        expect(bubble, findsNothing);
        expect(find.byKey(transportGhostKey), findsNothing);
        expect(calls.seeks, isEmpty);
      },
    );

    testWidgets('the hover bubble paints in full above a host that clips', (
      WidgetTester tester,
    ) async {
      const Key clipKey = ValueKey<String>('clipping-host');
      await tester.pumpWidget(
        RepaintBoundary(
          key: _screenKey,
          child: _host(
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRect(
                key: clipKey,
                child: Transport(
                  kind: TransportKind.video,
                  mode: TransportMode.card,
                  value: _value(_Calls()),
                  tuning: PlaybackTuning(),
                ),
              ),
            ),
          ),
        ),
      );
      final TestGesture mouse = await _mouse(tester);

      await mouse.moveTo(_timelineAt(tester, 0.25));
      await tester.pump();

      final Rect clip = tester.getRect(find.byKey(clipKey));
      final Rect time = tester.getRect(
        find.descendant(
          of: find.byKey(transportBubbleKey),
          matching: find.text('0:25'),
        ),
      );
      expect(time.bottom, lessThan(clip.top));
      final (Uint8List, int) screen = await _capture(tester);
      for (final Offset inside in <Offset>[
        Offset(time.left - 4, time.center.dy),
        Offset(time.right + 4, time.center.dy),
        Offset(time.center.dx, time.top - 2),
        Offset(time.center.dx, time.bottom + 2),
      ]) {
        expect(
          _pixelAt(screen, inside),
          FieldNotesColors.light.mediaBubble,
          reason: 'bubble fill at $inside',
        );
      }
    });

    testWidgets('hover shows the frame under the pointer for video', (
      WidgetTester tester,
    ) async {
      final _RecordingFrames frames = _RecordingFrames(
        Uint8List.fromList(onePixelPngBytes()),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoFramesProvider.overrideWithValue(frames)],
          child: _videoCard(_Calls(), mediaPath: '/tmp/clip.mp4'),
        ),
      );
      final TestGesture mouse = await _mouse(tester);

      await mouse.moveTo(_timelineAt(tester, 0.5));
      await tester.pump();
      await tester.pump();

      expect(frames.asked, <(String, Duration)>[
        ('/tmp/clip.mp4', const Duration(seconds: 50)),
      ]);
      final Finder frame = find.byKey(transportFrameKey);
      expect(frame, findsOneWidget);
      expect(
        tester.getRect(frame).bottom,
        lessThan(
          tester
              .getRect(
                find.descendant(
                  of: find.byKey(transportBubbleKey),
                  matching: find.text('0:50'),
                ),
              )
              .top,
        ),
      );
    });

    testWidgets('a frame that cannot be read leaves the time alone', (
      WidgetTester tester,
    ) async {
      final _RecordingFrames frames = _RecordingFrames(null);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoFramesProvider.overrideWithValue(frames)],
          child: _videoCard(_Calls(), mediaPath: '/tmp/clip.mp4'),
        ),
      );
      final TestGesture mouse = await _mouse(tester);

      await mouse.moveTo(_timelineAt(tester, 0.5));
      await tester.pump();
      await tester.pump();

      expect(frames.asked, hasLength(1));
      expect(find.byKey(transportFrameKey), findsNothing);
      expect(find.byKey(transportBubbleKey), findsOneWidget);
    });

    testWidgets('voice never asks for a frame', (WidgetTester tester) async {
      final _RecordingFrames frames = _RecordingFrames(
        Uint8List.fromList(onePixelPngBytes()),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoFramesProvider.overrideWithValue(frames)],
          child: _host(
            Align(
              alignment: Alignment.bottomCenter,
              child: Transport(
                kind: TransportKind.voice,
                mode: TransportMode.card,
                value: _value(_Calls()),
                tuning: PlaybackTuning(),
                mediaPath: '/tmp/note.m4a',
              ),
            ),
          ),
        ),
      );
      final TestGesture mouse = await _mouse(tester);

      await mouse.moveTo(_timelineAt(tester, 0.5));
      await tester.pump();

      expect(find.byKey(transportBubbleKey), findsOneWidget);
      expect(frames.asked, isEmpty);
    });
  });

  group('keyboard', () {
    final Map<String, (LogicalKeyboardKey, Duration)> seekKeys =
        <String, (LogicalKeyboardKey, Duration)>{
          'J': (LogicalKeyboardKey.keyJ, const Duration(seconds: 20)),
          'L': (LogicalKeyboardKey.keyL, const Duration(seconds: 40)),
          'Left': (LogicalKeyboardKey.arrowLeft, const Duration(seconds: 25)),
          'Right': (LogicalKeyboardKey.arrowRight, const Duration(seconds: 35)),
          'Home': (LogicalKeyboardKey.home, Duration.zero),
          'End': (LogicalKeyboardKey.end, _total),
          'Comma': (
            LogicalKeyboardKey.comma,
            _start - const Duration(microseconds: 33333),
          ),
          'Period': (
            LogicalKeyboardKey.period,
            _start + const Duration(microseconds: 33333),
          ),
          for (
            int digit = 0;
            digit < 10;
            digit++
          ) ...<String, (LogicalKeyboardKey, Duration)>{
            '$digit': (
              LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + digit),
              Duration(seconds: digit * 10),
            ),
            'numpad $digit': (
              LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + digit),
              Duration(seconds: digit * 10),
            ),
          },
        };

    for (final MapEntry<String, (LogicalKeyboardKey, Duration)> key
        in seekKeys.entries) {
      testWidgets('${key.key} moves the playhead', (WidgetTester tester) async {
        final _Calls calls = _Calls();
        await tester.pumpWidget(_viewer(calls, tuning: PlaybackTuning()));
        await tester.pump();

        await tester.sendKeyEvent(key.value.$1);
        await tester.pump();

        expect(calls.seeks, <Duration>[key.value.$2]);
      });
    }

    for (final (String name, LogicalKeyboardKey key)
        in <(String, LogicalKeyboardKey)>[
          ('Space', LogicalKeyboardKey.space),
          ('K', LogicalKeyboardKey.keyK),
        ]) {
      testWidgets('$name plays and pauses', (WidgetTester tester) async {
        final _Calls calls = _Calls();
        await tester.pumpWidget(_viewer(calls, tuning: PlaybackTuning()));
        await tester.pump();

        await tester.sendKeyEvent(key);
        await tester.pump();

        expect(calls.toggles, 1);
      });
    }

    testWidgets('Space on a focused button presses that button, not play', (
      WidgetTester tester,
    ) async {
      final _Calls calls = _Calls();
      await tester.pumpWidget(_viewer(calls, tuning: PlaybackTuning()));
      await tester.pump();

      Focus.of(
        tester.element(
          find.descendant(
            of: find.byKey(transportForward10Key),
            matching: find.byType(TransportGlyphIcon),
          ),
        ),
      ).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(calls.toggles, 0);
      expect(calls.seeks, <Duration>[const Duration(seconds: 40)]);
    });

    testWidgets('Up and Down step the volume and show it', (
      WidgetTester tester,
    ) async {
      final PlaybackTuning tuning = PlaybackTuning()..setVolume(0.5);
      await tester.pumpWidget(_viewer(_Calls(), tuning: tuning));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(tuning.volume, closeTo(0.55, 1e-9));
      expect(find.text('55%'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(tuning.volume, closeTo(0.45, 1e-9));
    });

    testWidgets('M mutes and restores', (WidgetTester tester) async {
      final PlaybackTuning tuning = PlaybackTuning()..setVolume(0.6);
      await tester.pumpWidget(_viewer(_Calls(), tuning: tuning));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(tuning.audibleVolume, 0);
      expect(find.text('Muted'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(tuning.audibleVolume, closeTo(0.6, 1e-9));
      expect(find.text('Sound on'), findsOneWidget);
    });

    testWidgets('F asks the host for full screen', (WidgetTester tester) async {
      final _Calls calls = _Calls();
      await tester.pumpWidget(_viewer(calls, tuning: PlaybackTuning()));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();

      expect(calls.fullScreens, 1);
    });

    testWidgets('a skip flashes its readout in the viewer and it clears', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_viewer(_Calls(), tuning: PlaybackTuning()));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pump();
      expect(find.text('-10 s'), findsOneWidget);

      await tester.pump(transportReadoutHold);
      expect(find.text('-10 s'), findsNothing);
    });

    testWidgets('frame stepping is refused while playing', (
      WidgetTester tester,
    ) async {
      final _Calls calls = _Calls();
      await tester.pumpWidget(
        _viewer(calls, tuning: PlaybackTuning(), playing: true),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyEvent(LogicalKeyboardKey.period);
      await tester.pump();

      expect(calls.seeks, isEmpty);
    });

    testWidgets('frame stepping is video only', (WidgetTester tester) async {
      final _Calls calls = _Calls();
      await tester.pumpWidget(
        _viewer(calls, tuning: PlaybackTuning(), kind: TransportKind.voice),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.pump();

      expect(calls.seeks, isEmpty);
    });

    testWidgets('Page Up and Page Down stay with the viewer', (
      WidgetTester tester,
    ) async {
      final _Calls calls = _Calls();
      final List<LogicalKeyboardKey> reachedViewer = <LogicalKeyboardKey>[];
      await tester.pumpWidget(
        Focus(
          onKeyEvent: (FocusNode node, KeyEvent event) {
            if (event is KeyDownEvent) {
              reachedViewer.add(event.logicalKey);
            }
            return KeyEventResult.ignored;
          },
          child: _viewer(calls, tuning: PlaybackTuning()),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();

      expect(reachedViewer, <LogicalKeyboardKey>[
        LogicalKeyboardKey.pageUp,
        LogicalKeyboardKey.pageDown,
      ]);
      expect(calls.seeks, isEmpty);
    });

    testWidgets('a chord with Control is left to the app', (
      WidgetTester tester,
    ) async {
      final _Calls calls = _Calls();
      await tester.pumpWidget(_viewer(calls, tuning: PlaybackTuning()));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(calls.toggles, 0);
    });
  });

  group('volume and speed reach the playback controllers', () {
    testWidgets('voice mute, slider and speed menu', (
      WidgetTester tester,
    ) async {
      final _TunableAudio player = _TunableAudio();
      final PlaybackTuning tuning = PlaybackTuning();
      await tester.pumpWidget(_voiceBody(player, tuning: tuning));
      await tester.pump();
      await tester.pump();
      expect(player.volumes.last, tuning.audibleVolume);
      expect(player.speeds.last, 1);

      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byKey(transportMuteKey)));
      await tester.pump();
      await tester.pump(Motion.fade);
      final Rect slider = tester.getRect(find.byKey(transportVolumeKey));
      await tester.tapAt(
        Offset(slider.left + slider.width / 4, slider.center.dy),
      );
      await tester.pump();
      expect(player.volumes.last, closeTo(0.25, 1e-9));

      await tester.tap(find.byKey(transportMuteKey));
      await tester.pump();
      expect(player.volumes.last, 0);
      await tester.tap(find.byKey(transportMuteKey));
      await tester.pump();
      expect(player.volumes.last, closeTo(0.25, 1e-9));

      await tester.tap(find.byKey(transportSpeedKey));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(transportSpeedChoiceKey(1.5)));
      await tester.pump();
      expect(player.speeds.last, 1.5);
      expect(find.byKey(transportSpeedMenuKey), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(transportSpeedKey),
          matching: find.text('1.5x'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('video picks up the current settings when it loads and after', (
      WidgetTester tester,
    ) async {
      final _TunableVideo player = _TunableVideo();
      final PlaybackTuning tuning = PlaybackTuning()
        ..setVolume(0.4)
        ..setSpeed(2);
      await tester.pumpWidget(_videoBody(player, tuning: tuning));
      await tester.pump();
      await tester.pump();
      expect(player.volumes.last, closeTo(0.4, 1e-9));
      expect(player.speeds.last, 2);

      tuning.setVolume(0.7);
      tuning.setSpeed(0.75);
      await tester.pump();
      expect(player.volumes.last, closeTo(0.7, 1e-9));
      expect(player.speeds.last, 0.75);

      await tester.pumpWidget(const SizedBox());
      final int heard = player.volumes.length;
      tuning.setVolume(0.1);
      expect(player.volumes, hasLength(heard));
    });

    testWidgets('the speed menu moves by arrows and Escape closes it', (
      WidgetTester tester,
    ) async {
      final PlaybackTuning tuning = PlaybackTuning();
      await tester.pumpWidget(_viewer(_Calls(), tuning: tuning));
      await tester.pump();

      await tester.tap(find.byKey(transportSpeedKey));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(transportSpeedMenuKey), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tuning.speed, 1.25);
      expect(find.byKey(transportSpeedMenuKey), findsNothing);

      await tester.tap(find.byKey(transportSpeedKey));
      await tester.pump();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(transportSpeedMenuKey), findsNothing);
      expect(tuning.speed, 1.25);
    });
  });

  group('bar', () {
    testWidgets('the skip buttons move ten seconds', (
      WidgetTester tester,
    ) async {
      final _Calls calls = _Calls();
      await tester.pumpWidget(_videoCard(calls));

      await tester.tap(find.byKey(transportBack10Key));
      await tester.tap(find.byKey(transportForward10Key));
      await tester.pump();

      expect(calls.seeks, <Duration>[
        const Duration(seconds: 20),
        const Duration(seconds: 40),
      ]);
    });

    testWidgets('full screen appears only where the host offers it', (
      WidgetTester tester,
    ) async {
      final _Calls calls = _Calls();
      await tester.pumpWidget(_videoCard(calls));
      expect(find.byKey(transportFullScreenKey), findsNothing);

      await tester.pumpWidget(_viewer(calls, tuning: PlaybackTuning()));
      await tester.tap(find.byKey(transportFullScreenKey));
      await tester.pump();

      expect(calls.fullScreens, 1);
    });

    testWidgets('every control names itself to a screen reader', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_viewer(_Calls(), tuning: PlaybackTuning()));

      for (final String label in <String>[
        'Play',
        'Back 10 seconds',
        'Forward 10 seconds',
        'Mute',
        'Volume',
        'Playback speed',
        'Full screen',
        'Video position',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      handle.dispose();
    });
  });

  group('Android', () {
    testWidgets('there is no volume slider or mute', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _videoCard(_Calls(), platform: TargetPlatform.android),
      );

      expect(find.byKey(transportVolumeKey), findsNothing);
      expect(find.byKey(transportMuteKey), findsNothing);
      expect(find.byKey(transportSpeedKey), findsOneWidget);
    });

    testWidgets('Up, Down and M on a focused voice card leave the volume', (
      WidgetTester tester,
    ) async {
      final PlaybackTuning tuning = PlaybackTuning()..setVolume(0.5);
      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.bottomCenter,
            child: Transport(
              kind: TransportKind.voice,
              mode: TransportMode.card,
              value: _value(_Calls()),
              tuning: tuning,
            ),
          ),
          platform: TargetPlatform.android,
        ),
      );
      Focus.of(
        tester.element(
          find.descendant(
            of: find.byKey(transportForward10Key),
            matching: find.byType(TransportGlyphIcon),
          ),
        ),
      ).requestFocus();
      await tester.pump();

      for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.keyM,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }

      expect(tuning.volume, 0.5);
      expect(tuning.muted, isFalse);
    });

    for (final (String side, double share, int expected, String readout)
        in <(String, double, int, String)>[
          ('left', 0.1, 20, '-10 s'),
          ('right', 0.9, 40, '+10 s'),
        ]) {
      testWidgets('a double tap on the $side skips and shows a brief readout', (
        WidgetTester tester,
      ) async {
        final _TunableVideo player = _TunableVideo();
        await tester.pumpWidget(
          _videoBody(
            player,
            tuning: PlaybackTuning(),
            platform: TargetPlatform.android,
            model: VideoControlModel.touch,
          ),
        );
        await tester.pump();
        await tester.pump();
        player.emitPosition(_start);
        await tester.pump();

        final Offset tapAt = Offset(_stage.width * share, _stage.height / 2);
        await tester.tapAt(tapAt);
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tapAt(tapAt);
        await tester.pump();

        expect(player.seekCalls, <Duration>[Duration(seconds: expected)]);
        expect(find.text(readout), findsOneWidget);

        await tester.pump(transportReadoutHold);
        expect(find.text(readout), findsNothing);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('one tap never skips', (WidgetTester tester) async {
      final _TunableVideo player = _TunableVideo();
      await tester.pumpWidget(
        _videoBody(
          player,
          tuning: PlaybackTuning(),
          platform: TargetPlatform.android,
          model: VideoControlModel.touch,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tapAt(Offset(_stage.width * 0.1, _stage.height / 2));
      await tester.pump(const Duration(milliseconds: 301));
      await tester.tapAt(Offset(_stage.width * 0.1, _stage.height / 2));
      await tester.pump(const Duration(milliseconds: 301));

      expect(player.seekCalls, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the viewer dock has the skip controls and no volume', (
      WidgetTester tester,
    ) async {
      final _Calls calls = _Calls();
      await tester.pumpWidget(
        _host(
          Transport(
            kind: TransportKind.voice,
            mode: TransportMode.viewer,
            value: _value(calls),
            tuning: PlaybackTuning(),
          ),
          platform: TargetPlatform.android,
          size: const Size(390, 800),
        ),
      );

      expect(find.byType(TransportDock), findsOneWidget);
      expect(find.byKey(transportVolumeKey), findsNothing);
      await tester.tap(find.byKey(transportForward10Key));
      await tester.pump();
      expect(calls.seeks, <Duration>[const Duration(seconds: 40)]);
      expect(tester.takeException(), isNull);
    });
  });

  group('desktop picture', () {
    testWidgets('a double click asks the host for full screen', (
      WidgetTester tester,
    ) async {
      final _TunableVideo player = _TunableVideo();
      int fullScreens = 0;
      await tester.pumpWidget(
        _videoBody(
          player,
          tuning: PlaybackTuning(),
          model: VideoControlModel.pointer,
          onFullScreen: () => fullScreens += 1,
        ),
      );
      await tester.pump();
      await tester.pump();

      final Offset picture = Offset(_stage.width / 2, _stage.height / 2);
      await tester.tapAt(picture);
      await tester.pump(const Duration(milliseconds: 80));
      expect(fullScreens, 0);
      await tester.tapAt(picture);
      await tester.pump();

      expect(fullScreens, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('themes', () {
    for (final (Brightness brightness, FieldNotesColors colors)
        in <(Brightness, FieldNotesColors)>[
          (Brightness.light, FieldNotesColors.light),
          (Brightness.dark, FieldNotesColors.dark),
        ]) {
      testWidgets(
        '${brightness.name} timeline and bubble use the media tokens',
        (WidgetTester tester) async {
          await tester.pumpWidget(_videoCard(_Calls(), brightness: brightness));
          final TestGesture mouse = await _mouse(tester);
          await mouse.moveTo(_timelineAt(tester, 0.25));
          await tester.pump();

          final TransportPalette palette = tester
              .widget<TransportTimeline>(find.byType(TransportTimeline))
              .palette;
          expect(palette.rail, colors.mediaRail);
          expect(palette.played, colors.mediaPlayed);
          expect(_bubbleDecoration(tester).color, colors.mediaBubble);
          expect(
            tester
                .widget<Text>(
                  find.descendant(
                    of: find.byKey(transportBubbleKey),
                    matching: find.text('0:25'),
                  ),
                )
                .style!
                .color,
            colors.mediaBubbleInk,
          );
        },
      );

      testWidgets(
        '${brightness.name} voice bars and viewer use the media tokens',
        (WidgetTester tester) async {
          final _TunableAudio player = _TunableAudio();
          await tester.pumpWidget(
            _voiceBody(
              player,
              tuning: PlaybackTuning(),
              brightness: brightness,
            ),
          );
          await tester.pump();
          await tester.pump();
          final Rect wave = tester.getRect(find.byType(VoiceWaveform));
          await tester.tapAt(Offset(wave.right - 1, wave.center.dy));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          final BoxDecoration bar =
              tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byKey(voiceWaveformBarKey(0)),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration;
          expect(bar.color, colors.mediaPlayed);

          await tester.pumpWidget(
            _host(
              Transport(
                kind: TransportKind.voice,
                mode: TransportMode.viewer,
                value: _value(_Calls()),
                tuning: PlaybackTuning(),
                compact: false,
              ),
              brightness: brightness,
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            tester
                .widget<TransportTimeline>(find.byType(TransportTimeline))
                .palette
                .wave,
            colors.viewerWaveform,
          );
          final Finder disc = find.descendant(
            of: find.byType(TransportPlayButton),
            matching: find.byWidgetPredicate(
              (Widget widget) =>
                  widget is DecoratedBox &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).shape ==
                      BoxShape.circle &&
                  (widget.decoration as BoxDecoration).color == colors.mediaCta,
            ),
          );
          expect(disc, findsOneWidget);
        },
      );
    }
  });
}
