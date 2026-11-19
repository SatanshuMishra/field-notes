import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/entry_cards/transport/transport_bar.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart'
    show videoAspectProvider;
import 'package:field_notes/features/log_viewer/viewer_chrome.dart'
    show viewerTitleFieldKey;
import 'package:field_notes/features/notes/notes.dart'
    show notesMediaResolverProvider;
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import '../day_detail/support/day_detail_harness.dart';
import '../entry_cards/support/fake_video_player.dart';

const String _date = '2026-07-19';
const String _videoMedia = 'blob-video';
const String _videoId = 'video-log';
const Duration _pastDoubleClick = Duration(milliseconds: 400);

final TargetPlatformVariant _mac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

final class _Window {
  _Window(WidgetTester tester, {required bool fullScreen}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowChannel, (MethodCall call) async {
          calls.add(call);
          return call.method == windowStateMethod
              ? <String, Object?>{
                  'maximized': false,
                  'active': true,
                  'fullScreen': fullScreen,
                }
              : null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(windowChannel, null),
    );
  }

  final List<MethodCall> calls = <MethodCall>[];

  List<Object?> get fullScreenRequests => <Object?>[
    for (final MethodCall call in calls)
      if (call.method == setFullScreenMethod) call.arguments,
  ];

  Future<void> reports(WidgetTester tester, {required bool fullScreen}) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          windowChannelName,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(stateChangedMethod, <String, Object?>{
              'maximized': false,
              'active': true,
              'fullScreen': fullScreen,
            }),
          ),
          (ByteData? _) {},
        );
    await tester.pumpAndSettle();
  }
}

final class _FullView {
  _FullView(this.player, this.outcomes);

  final FakeEntryVideoPlayer player;
  final List<LogViewerOutcome> outcomes;
}

void _useMacWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

FakeMediaResolver _mediaResolver() {
  final Directory folder = Directory.systemTemp.createTempSync(
    'full-view-window',
  );
  addTearDown(() => folder.deleteSync(recursive: true));
  final File video = File('${folder.path}/video.mp4')
    ..writeAsBytesSync(const <int>[0, 1, 2, 3]);
  return FakeMediaResolver(<String, ResolvedMedia>{
    _videoMedia: ResolvedMedia.available(
      blob: blobOf(
        id: _videoMedia,
        relPath: 'video.mp4',
        kind: MediaKind.video,
      ),
      file: video,
    ),
  });
}

Entry _videoLog() {
  return Entry(
    id: _videoId,
    dayId: 'day-1',
    type: EntryType.video,
    mediaId: _videoMedia,
    durationMs: 4000,
    createdAt: DateTime(2026, 7, 19, 11, 30).millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

Future<_FullView> _openFullView(WidgetTester tester) async {
  final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
  final List<LogViewerOutcome> outcomes = <LogViewerOutcome>[];
  final MediaResolver resolver = _mediaResolver();
  final LruVideoSlots slots = LruVideoSlots(cap: 2);
  addTearDown(slots.dispose);
  late BuildContext host;
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(
          FakeJournalRepository(entries: <Entry>[_videoLog()]),
        ),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp),
        ),
        notesMediaResolverProvider.overrideWith((Ref ref) async => resolver),
        todayVideoPlayerFactoryProvider.overrideWithValue(() => player),
        videoSlotsProvider.overrideWithValue(slots),
        videoAspectProvider.overrideWith((Ref ref, String mediaId) => 16 / 9),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Builder(
          builder: (BuildContext context) {
            host = context;
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  showLogViewer(
    host,
    date: _date,
    entryId: _videoId,
    exit: LogViewerExit.back,
  ).then(outcomes.add);
  await tester.pumpAndSettle();
  expect(find.byKey(logViewerPanelKey), findsOneWidget);
  return _FullView(player, outcomes);
}

Finder get _fullScreenButton => find.byKey(transportFullScreenKey);

String _fullScreenLabel(WidgetTester tester) =>
    tester.widget<TransportIconButton>(_fullScreenButton).label;

bool _showsFullScreenLayout(WidgetTester tester) {
  final bool chromeHidden = find
      .byKey(viewerTitleFieldKey)
      .hitTestable()
      .evaluate()
      .isEmpty;
  final bool exitGlyph = _fullScreenLabel(tester) == 'Exit full screen';
  expect(
    chromeHidden,
    exitGlyph,
    reason: 'the title bar hides exactly while the button offers to exit',
  );
  return chromeHidden;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _pressBackControl(WidgetTester tester) async {
  tester
      .widget<Pressable>(
        find.descendant(
          of: find.byKey(logViewerBackKey),
          matching: find.byType(Pressable),
          matchRoot: true,
        ),
      )
      .onPressed!();
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the full-screen button and F ask the window to go full screen and back',
    (WidgetTester tester) async {
      _useMacWindow(tester);
      final _Window window = _Window(tester, fullScreen: false);
      await _openFullView(tester);
      expect(_showsFullScreenLayout(tester), isFalse);

      await tester.tap(_fullScreenButton);
      await tester.pumpAndSettle();
      expect(window.fullScreenRequests, <Object?>[true]);

      await _press(tester, LogicalKeyboardKey.keyF);
      expect(window.fullScreenRequests, <Object?>[true, false]);
      expect(find.byKey(logViewerPanelKey), findsOneWidget);

      await _close(tester);
    },
    variant: _mac,
  );

  testWidgets('Esc leaves full screen before it leaves the full view', (
    WidgetTester tester,
  ) async {
    _useMacWindow(tester);
    final _Window window = _Window(tester, fullScreen: false);
    final _FullView view = await _openFullView(tester);
    await tester.tap(_fullScreenButton);
    await tester.pumpAndSettle();
    expect(window.fullScreenRequests, <Object?>[true]);

    await _press(tester, LogicalKeyboardKey.escape);
    expect(window.fullScreenRequests, <Object?>[true, false]);
    expect(find.byKey(logViewerPanelKey), findsOneWidget);
    expect(view.outcomes, isEmpty);

    await _press(tester, LogicalKeyboardKey.escape);
    expect(find.byKey(logViewerPanelKey), findsNothing);
    expect(view.outcomes, <LogViewerOutcome>[LogViewerOutcome.returned]);
    expect(window.fullScreenRequests, <Object?>[true, false]);

    await _close(tester);
  }, variant: _mac);

  testWidgets(
    'leaving the full view returns the window to windowed only when the full '
    'view made it full screen',
    (WidgetTester tester) async {
      _useMacWindow(tester);
      final _Window madeHere = _Window(tester, fullScreen: false);
      final _FullView first = await _openFullView(tester);
      await tester.tap(_fullScreenButton);
      await tester.pumpAndSettle();
      expect(madeHere.fullScreenRequests, <Object?>[true]);

      await _pressBackControl(tester);
      expect(find.byKey(logViewerPanelKey), findsNothing);
      expect(first.outcomes, <LogViewerOutcome>[LogViewerOutcome.returned]);
      expect(madeHere.fullScreenRequests, <Object?>[true, false]);
      await _close(tester);

      final _Window alreadyFull = _Window(tester, fullScreen: true);
      final _FullView second = await _openFullView(tester);
      expect(_showsFullScreenLayout(tester), isTrue);

      await _pressBackControl(tester);
      expect(find.byKey(logViewerPanelKey), findsNothing);
      expect(second.outcomes, <LogViewerOutcome>[LogViewerOutcome.returned]);
      await _close(tester);
      expect(alreadyFull.fullScreenRequests, isEmpty);
    },
    variant: _mac,
  );

  testWidgets('a double click on the picture makes the window full screen', (
    WidgetTester tester,
  ) async {
    _useMacWindow(tester);
    final _Window window = _Window(tester, fullScreen: false);
    final _FullView view = await _openFullView(tester);
    final FakeEntryVideoPlayer player = view.player;
    await tester.tap(find.byType(TransportPlayButton));
    await tester.pump();
    player.emitState(VideoPlaybackState.playing);
    await tester.pump();
    expect(player.playCalls, 1);

    final Offset picture = tester.getCenter(find.byKey(videoFrameKey));
    await tester.tapAt(picture, kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(player.pauseCalls, 1);
    player.emitState(VideoPlaybackState.paused);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(picture, kind: PointerDeviceKind.mouse);
    await tester.pump();
    player.emitState(VideoPlaybackState.playing);
    await tester.pump(_pastDoubleClick);

    expect(window.fullScreenRequests, <Object?>[true]);
    expect(player.playCalls, 2);
    expect(player.pauseCalls, 1);
    expect(player.state, VideoPlaybackState.playing);

    await _close(tester);
  }, variant: _mac);

  testWidgets('the full view follows a full-screen change the window reports', (
    WidgetTester tester,
  ) async {
    _useMacWindow(tester);
    final _Window window = _Window(tester, fullScreen: false);
    final _FullView view = await _openFullView(tester);
    expect(_showsFullScreenLayout(tester), isFalse);

    await window.reports(tester, fullScreen: true);
    expect(_showsFullScreenLayout(tester), isTrue);
    expect(window.fullScreenRequests, isEmpty);

    await _press(tester, LogicalKeyboardKey.escape);
    expect(window.fullScreenRequests, <Object?>[false]);
    expect(find.byKey(logViewerPanelKey), findsOneWidget);
    expect(view.outcomes, isEmpty);

    await window.reports(tester, fullScreen: false);
    expect(_showsFullScreenLayout(tester), isFalse);
    expect(find.byKey(logViewerPanelKey), findsOneWidget);

    await _close(tester);
    expect(window.fullScreenRequests, <Object?>[false]);
  }, variant: _mac);
}
