import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/day_detail/day_media_pane.dart';
import 'package:field_notes/features/entry_cards/cards/video_controls_overlay.dart';
import 'package:field_notes/features/entry_cards/cards/video_scrubber.dart';
import 'package:field_notes/features/entry_cards/cards/voice_waveform.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart'
    show videoAspectProvider;
import 'package:field_notes/features/notes/notes.dart'
    show notesMediaResolverProvider;
import 'package:field_notes/features/search/search_day_tile.dart';
import 'package:field_notes/features/search/search_day_view.dart';
import 'package:field_notes/features/search/search_field.dart';
import 'package:field_notes/features/search/search_providers.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import '../entry_cards/support/fake_audio_player.dart';
import '../entry_cards/support/fake_video_player.dart';
import '../notes/support/notes_harness.dart' show FakeNoteMediaResolver;
import 'support/day_detail_harness.dart'
    show FakeJournalRepository, FakeMediaStore, blobOf;

const int _mousePointerId = 43;
const int _mouseDevice = 1;

const Color _ink = Color(0xFF4A3B2E);
const Color _white = Color(0xFFFFFFFF);
const Color _danger = Color(0xFFC0392B);
const Color _mediaGround = Color(0xFF15110D);

final int _lightRow = _ink.withValues(alpha: 0.06).toARGB32();
final int _dark = _white.withValues(alpha: 0.12).toARGB32();
final int _pillEdit = _white.withValues(alpha: 0.14).toARGB32();
final int _pillDelete = _danger.withValues(alpha: 0.6).toARGB32();

const Size _desktop = Size(1440, 900);
const Size _phone = Size(384, 832);
const String _date = '2026-07-19';
const String _openDayLabel = 'open day';
const String _voiceMedia = 'blob-voice';
const String _videoMedia = 'blob-video';
const String _noteId = 'note-1';
const String _voiceId = 'voice-1';
const String _videoId = 'video-1';

const Key _overlayChildKey = ValueKey<String>('overlay-child');

enum _Shape { circle, rounded }

class _Row {
  const _Row(
    this.label,
    this.control,
    this.fill,
    this.shape, {
    this.radius,
    this.role = _Role.button,
    this.labelMatcher,
  });

  final String label;
  final Finder control;
  final int fill;
  final _Shape shape;
  final double? radius;
  final _Role role;
  final Matcher? labelMatcher;
}

enum _Role { button, slider }

Finder _pressableAt(Finder inner) => find
    .ancestor(of: inner, matching: find.byType(Pressable), matchRoot: true)
    .first;

Finder _inCard(String id, Key key) => find.descendant(
  of: find.byWidgetPredicate(
    (Widget widget) => widget is CompactLogCard && widget.entry.id == id,
  ),
  matching: find.byKey(key),
);

Finder _hoverFill(_Row row) => find.descendant(
  of: row.control,
  matching: find.byWidgetPredicate((Widget widget) {
    if (widget is! DecoratedBox) {
      return false;
    }
    final Decoration decoration = widget.decoration;
    if (decoration is! BoxDecoration ||
        decoration.color?.toARGB32() != row.fill) {
      return false;
    }
    return switch (row.shape) {
      _Shape.circle => decoration.shape == BoxShape.circle,
      _Shape.rounded =>
        decoration.borderRadius == BorderRadius.circular(row.radius!),
    };
  }),
);

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

Future<TestGesture> _mousePointer(WidgetTester tester) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    pointer: _mousePointerId,
  );
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  return mouse;
}

Future<void> _expectRows(
  WidgetTester tester,
  TestGesture mouse,
  List<_Row> rows,
) async {
  for (final _Row row in rows) {
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(row.control, findsOneWidget, reason: row.label);
    expect(_hoverFill(row), findsNothing, reason: row.label);

    await mouse.moveTo(tester.getCenter(row.control));
    await tester.pump();

    expect(_cursor(), SystemMouseCursors.click, reason: row.label);
    expect(_hoverFill(row), findsOneWidget, reason: row.label);
    final SemanticsNode node = tester.getSemantics(
      find
          .descendant(
            of: row.control,
            matching: find.byType(Pressable),
            matchRoot: true,
          )
          .first,
    );
    expect(node, switch (row.role) {
      _Role.button => isSemantics(isButton: true),
      _Role.slider => isSemantics(isSlider: true),
    }, reason: row.label);
    expect(node.label, row.labelMatcher ?? row.label, reason: row.label);
  }
}

Entry _entry({
  required String id,
  required EntryType type,
  required int hour,
  String? textContent,
  String? mediaId,
  int? durationMs,
}) {
  return Entry(
    id: id,
    dayId: 'day-1',
    type: type,
    textContent: textContent,
    mediaId: mediaId,
    durationMs: durationMs,
    peaks: type == EntryType.voice
        ? const <double>[0.2, 0.6, 0.9, 0.4, 0.7, 0.3]
        : null,
    createdAt: DateTime(2026, 7, 19, hour, 12).millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

List<Entry> _dayEntries() => <Entry>[
  _entry(
    id: _noteId,
    type: EntryType.text,
    hour: 7,
    textContent: 'Fed the robins.',
  ),
  _entry(
    id: _voiceId,
    type: EntryType.voice,
    hour: 9,
    mediaId: _voiceMedia,
    durationMs: 65000,
  ),
  _entry(
    id: _videoId,
    type: EntryType.video,
    hour: 11,
    mediaId: _videoMedia,
    durationMs: 4000,
  ),
];

FakeNoteMediaResolver _resolver() {
  final Directory folder = Directory.systemTemp.createTempSync('entry-hover');
  addTearDown(() => folder.deleteSync(recursive: true));
  final File voice = File('${folder.path}/voice.m4a')
    ..writeAsBytesSync(const <int>[0, 1, 2, 3]);
  final File video = File('${folder.path}/video.mp4')
    ..writeAsBytesSync(const <int>[0, 1, 2, 3]);
  return FakeNoteMediaResolver(<String, ResolvedMedia>{
    _voiceMedia: ResolvedMedia.available(
      blob: blobOf(
        id: _voiceMedia,
        relPath: 'voice.m4a',
        kind: MediaKind.audio,
      ),
      file: voice,
    ),
    _videoMedia: ResolvedMedia.available(
      blob: blobOf(
        id: _videoMedia,
        relPath: 'video.mp4',
        kind: MediaKind.video,
      ),
      file: video,
    ),
  })..memoizeAll();
}

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showDayDetail(context, date: _date),
        child: const Text(_openDayLabel),
      ),
    );
  }
}

Future<void> _openDay(WidgetTester tester, TargetPlatform platform) async {
  final MediaResolver resolver = _resolver();
  final LruVideoSlots slots = LruVideoSlots(cap: 2);
  addTearDown(slots.dispose);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(
          FakeJournalRepository(entries: _dayEntries()),
        ),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp),
        ),
        dayDetailMediaResolverProvider.overrideWith((Ref ref) => resolver),
        notesMediaResolverProvider.overrideWith((Ref ref) async => resolver),
        todayAudioPlayerFactoryProvider.overrideWithValue(
          FakeEntryAudioPlayer.new,
        ),
        todayVideoPlayerFactoryProvider.overrideWithValue(
          FakeEntryVideoPlayer.new,
        ),
        videoSlotsProvider.overrideWithValue(slots),
        videoAspectProvider.overrideWith((Ref ref, String mediaId) => 16 / 9),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: const Scaffold(body: _Launcher()),
      ),
    ),
  );
  await tester.tap(find.text(_openDayLabel));
  await tester.pumpAndSettle();
}

Future<void> _pumpPiece(WidgetTester tester, Widget body) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        searchQueryProvider.overrideWith(() => _RainQuery()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Scaffold(body: body),
      ),
    ),
  );
  await tester.pump();
}

class _RainQuery extends SearchQuery {
  @override
  String build() => 'rain';
}

class _VoiceBodyPiece extends StatelessWidget {
  const _VoiceBodyPiece({required this.resolver, required this.player});

  final MediaResolver resolver;
  final FakeEntryAudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return VoiceBody(
      entry: _entry(
        id: _voiceId,
        type: EntryType.voice,
        hour: 9,
        mediaId: _voiceMedia,
        durationMs: 65000,
      ),
      resolver: resolver,
      playerFactory: () => player,
    );
  }
}

Widget _pieces(MediaResolver resolver, FakeEntryAudioPlayer player) =>
    SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 360,
              child: _VoiceBodyPiece(resolver: resolver, player: player),
            ),
            const SizedBox(height: 16),
            ColoredBox(
              color: _mediaGround,
              child: SizedBox(
                width: 320,
                child: VideoScrubber(
                  position: const Duration(seconds: 1),
                  total: const Duration(seconds: 10),
                  onSeek: (Duration position) {},
                  onScrubUpdate: (Duration position) {},
                  onScrubEnd: () {},
                ),
              ),
            ),
            const SizedBox(height: 16),
            LogActionsPill(onEdit: () {}, onDelete: () {}),
            const SizedBox(height: 16),
            SizedBox(
              width: 240,
              height: 140,
              child: CorruptMediaPlaceholder(
                label: 'Photo unavailable',
                onRetry: () {},
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 420,
              child: SearchDayTile(
                view: const SearchDayView(
                  date: '2026-07-14',
                  mood: null,
                  entryCount: 1,
                  preview: 'Rain on the roof',
                  searchText: 'rain on the roof',
                ),
                onTap: () {},
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(width: 420, child: SearchField()),
          ],
        ),
      ),
    );

void main() {
  testWidgets('every day, card and search control shows the click cursor and '
      'hover', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      _view(tester, _desktop);
      await _openDay(tester, TargetPlatform.macOS);
      final TestGesture mouse = await _mousePointer(tester);

      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Close',
          _pressableAt(find.byKey(dayDetailBackKey)),
          _lightRow,
          _Shape.rounded,
          radius: 10,
        ),
        _Row(
          'Earlier day',
          _pressableAt(find.byKey(dayDetailEarlierDayKey)),
          _lightRow,
          _Shape.rounded,
          radius: 10,
        ),
        _Row(
          'Later day',
          _pressableAt(find.byKey(dayDetailLaterDayKey)),
          _lightRow,
          _Shape.rounded,
          radius: 10,
        ),
        _Row(
          'Add a note',
          find.byKey(dayDetailAddNoteKey),
          _dark,
          _Shape.rounded,
          radius: 11,
        ),
        _Row(
          'Play',
          _inCard(_voiceId, compactLogPlayKey),
          _dark,
          _Shape.circle,
        ),
        _Row(
          'Play',
          _inCard(_videoId, compactLogPlayKey),
          _lightRow,
          _Shape.circle,
        ),
      ]);

      await tester.tap(_inCard(_voiceId, compactLogPlayKey));
      await tester.pumpAndSettle();

      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Full screen',
          find.byKey(dayMediaPaneFullScreenKey),
          _dark,
          _Shape.rounded,
          radius: 10,
        ),
      ]);

      await mouse.moveTo(Offset.zero);
      _view(tester, _phone);
      await _openDay(tester, TargetPlatform.android);

      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Edit note',
          find.byKey(daySheetEditKeyFor(_noteId)),
          _lightRow,
          _Shape.rounded,
          radius: 10,
        ),
        _Row(
          'Delete entry',
          find.byKey(daySheetDeleteKeyFor(_noteId)),
          _lightRow,
          _Shape.rounded,
          radius: 10,
        ),
        _Row(
          'Close',
          find.byKey(daySheetCloseKey),
          _lightRow,
          _Shape.rounded,
          radius: 14,
        ),
        _Row(
          'Add a note',
          find.byKey(dayDetailAddNoteKey),
          _dark,
          _Shape.rounded,
          radius: 14,
        ),
      ]);

      await mouse.moveTo(Offset.zero);
      _view(tester, _desktop);
      final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
      await _pumpPiece(tester, _pieces(_resolver(), player));

      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Play',
          find.byKey(const ValueKey<String>('voice-play-toggle')),
          _dark,
          _Shape.circle,
        ),
        _Row(
          'Playback position',
          find.descendant(
            of: find.byType(VoiceWaveform),
            matching: find.byType(Pressable),
          ),
          _lightRow,
          _Shape.rounded,
          radius: 2,
          role: _Role.slider,
        ),
        _Row(
          'Video position',
          find.byKey(const ValueKey<String>('video-scrub-bar')),
          _dark,
          _Shape.rounded,
          radius: 2,
          role: _Role.slider,
        ),
        _Row(
          'Edit note',
          find.byKey(logActionsEditKey),
          _pillEdit,
          _Shape.rounded,
          radius: 7,
        ),
        _Row(
          'Delete entry',
          find.byKey(logActionsDeleteKey),
          _pillDelete,
          _Shape.rounded,
          radius: 7,
        ),
        _Row(
          'Try again',
          _pressableAt(find.byKey(retryMediaKey)),
          _lightRow,
          _Shape.rounded,
          radius: 11,
        ),
        _Row(
          'Tuesday, July 14, Rain on the roof, 1 entry',
          find.byType(SearchDayTile),
          _lightRow,
          _Shape.rounded,
          radius: 16,
          labelMatcher: allOf(
            startsWith('Tuesday, July 14'),
            endsWith('Rain on the roof, 1 entry'),
          ),
        ),
        _Row(
          'Clear search',
          _pressableAt(find.byKey(searchClearFaceKey)),
          _lightRow,
          _Shape.rounded,
          radius: 20,
        ),
      ]);

      await mouse.moveTo(Offset.zero);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: Center(
              child: ColoredBox(
                color: _mediaGround,
                child: SizedBox(
                  width: 320,
                  height: 180,
                  child: VideoControlsOverlay(
                    controlsEnabled: true,
                    isPlaying: true,
                    onToggle: () {},
                    model: VideoControlModel.pointer,
                    child: const SizedBox.expand(key: _overlayChildKey),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final Finder surface = find.byKey(
        const ValueKey<String>('video-surface-tap'),
      );
      final Finder controls = find.ancestor(
        of: find.byKey(_overlayChildKey),
        matching: find.byType(AnimatedOpacity),
      );
      await tester.pump(kVideoControlsHideDelay);
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedOpacity>(controls).opacity, 0);

      await mouse.moveTo(tester.getCenter(surface));
      await tester.pump();

      expect(_cursor(), SystemMouseCursors.click);
      expect(tester.widget<AnimatedOpacity>(controls).opacity, 1);
      expect(
        tester.getSemantics(surface),
        isSemantics(label: 'Play or pause video', isButton: true),
      );
    } finally {
      semantics.dispose();
    }
  });
}
