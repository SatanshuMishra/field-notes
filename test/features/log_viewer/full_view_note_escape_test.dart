import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/entry_cards/transport/transport_bar.dart'
    show transportFullScreenKey;
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/note_reading_room.dart'
    show noteReadingRoomKey;
import 'package:field_notes/features/notes/notes.dart'
    show notesMediaResolverProvider;
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../day_detail/support/day_detail_harness.dart';
import '../entry_cards/support/fake_video_player.dart';

const String _date = '2026-07-19';
const String _videoMedia = 'blob-video';
const String _videoId = 'video-log';
const String _noteId = 'note-log';

final TargetPlatformVariant _mac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

final class _Window {
  _Window({required bool fullScreen}) {
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

void _useMacWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

FakeMediaResolver _mediaResolver() {
  final Directory folder = Directory.systemTemp.createTempSync(
    'full-view-note-escape',
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

List<Entry> _videoThenNote() {
  return <Entry>[
    Entry(
      id: _videoId,
      dayId: 'day-1',
      type: EntryType.video,
      mediaId: _videoMedia,
      durationMs: 4000,
      createdAt: DateTime(2026, 7, 19, 11, 30).millisecondsSinceEpoch,
      updatedAt: 0,
    ),
    Entry(
      id: _noteId,
      dayId: 'day-1',
      type: EntryType.text,
      textContent: 'Fed the robins.',
      createdAt: DateTime(2026, 7, 19, 12, 15).millisecondsSinceEpoch,
      updatedAt: 0,
    ),
  ];
}

Future<List<LogViewerOutcome>> _openFullView(
  WidgetTester tester, {
  required String entryId,
}) async {
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
          FakeJournalRepository(entries: _videoThenNote()),
        ),
        notesMediaResolverProvider.overrideWith((Ref ref) async => resolver),
        todayVideoPlayerFactoryProvider.overrideWithValue(
          FakeEntryVideoPlayer.new,
        ),
        videoSlotsProvider.overrideWithValue(slots),
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
    entryId: entryId,
    exit: LogViewerExit.back,
  ).then(outcomes.add);
  await tester.pumpAndSettle();
  expect(find.byKey(logViewerPanelKey), findsOneWidget);
  return outcomes;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'on a note reached from a video made full screen, the first Esc leaves '
    'full screen and the second leaves the full view',
    (WidgetTester tester) async {
      _useMacWindow(tester);
      final _Window window = _Window(fullScreen: false);
      final List<LogViewerOutcome> outcomes = await _openFullView(
        tester,
        entryId: _videoId,
      );
      await tester.tap(find.byKey(transportFullScreenKey));
      await tester.pumpAndSettle();
      await window.reports(tester, fullScreen: true);
      expect(window.fullScreenRequests, <Object?>[true]);

      await _press(tester, LogicalKeyboardKey.pageDown);
      expect(find.byKey(noteReadingRoomKey), findsOneWidget);

      await _press(tester, LogicalKeyboardKey.escape);
      expect(window.fullScreenRequests, <Object?>[true, false]);
      expect(find.byKey(logViewerPanelKey), findsOneWidget);
      expect(outcomes, isEmpty);
      await window.reports(tester, fullScreen: false);

      await _press(tester, LogicalKeyboardKey.escape);
      expect(find.byKey(logViewerPanelKey), findsNothing);
      expect(outcomes, <LogViewerOutcome>[LogViewerOutcome.returned]);
      expect(window.fullScreenRequests, <Object?>[true, false]);

      await _close(tester);
    },
    variant: _mac,
  );

  testWidgets(
    'on a note while the window reports full screen, Esc leaves full screen '
    'before it leaves the full view',
    (WidgetTester tester) async {
      _useMacWindow(tester);
      final _Window window = _Window(fullScreen: false);
      final List<LogViewerOutcome> outcomes = await _openFullView(
        tester,
        entryId: _noteId,
      );
      await window.reports(tester, fullScreen: true);

      await _press(tester, LogicalKeyboardKey.escape);
      expect(window.fullScreenRequests, <Object?>[false]);
      expect(find.byKey(logViewerPanelKey), findsOneWidget);
      expect(outcomes, isEmpty);
      await window.reports(tester, fullScreen: false);

      await _press(tester, LogicalKeyboardKey.escape);
      expect(find.byKey(logViewerPanelKey), findsNothing);
      expect(outcomes, <LogViewerOutcome>[LogViewerOutcome.returned]);
      expect(window.fullScreenRequests, <Object?>[false]);

      await _close(tester);
    },
    variant: _mac,
  );
}
