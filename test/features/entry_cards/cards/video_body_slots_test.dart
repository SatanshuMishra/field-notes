import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';

import '../support/entry_cards_harness.dart';
import '../support/fake_video_player.dart';

const ValueKey<String> _playToggle = ValueKey<String>('video-play-toggle');
const ValueKey<String> _muteToggle = ValueKey<String>('video-mute-toggle');
const ValueKey<String> _retryButton = ValueKey<String>('media-retry');
const ValueKey<String> _surface = ValueKey<String>('fake-video-surface');

const Duration _loadTimeout = Duration(milliseconds: 100);
const List<Duration> _backoff = <Duration>[
  Duration(milliseconds: 10),
  Duration(milliseconds: 20),
];
const Duration _pastBackoff = Duration(milliseconds: 200);

typedef _PlayerSetup = void Function(FakeEntryVideoPlayer player, int index);

File _videoFile({int bytes = 8, bool create = true}) {
  final Directory dir = Directory.systemTemp.createTempSync('video_body_slots');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  final File file = File('${dir.path}/v.mp4');
  if (create) {
    file.writeAsBytesSync(List<int>.filled(bytes, 0));
  }
  return file;
}

FakeMediaResolver _resolverFor(File file) => FakeMediaResolver()
  ..set(
    'vid',
    ResolvedMedia.available(
      blob: blobOf(id: 'vid', relPath: 'v.mp4', kind: MediaKind.video),
      file: file,
    ),
  );

EntryVideoPlayerFactory _factoryInto(
  List<FakeEntryVideoPlayer> built, {
  _PlayerSetup? setUpPlayer,
}) {
  return () {
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    setUpPlayer?.call(player, built.length);
    built.add(player);
    return player;
  };
}

Widget _card({
  required MediaResolver resolver,
  required EntryVideoPlayerFactory playerFactory,
  required VideoSlots slots,
  String mediaId = 'vid',
  int? durationMs = 65000,
}) {
  return cardHarness(
    VideoBody(
      entry: entryOf(
        type: EntryType.video,
        mediaId: mediaId,
        durationMs: durationMs,
      ),
      resolver: resolver,
      playerFactory: playerFactory,
      slots: slots,
      loadTimeout: _loadTimeout,
      retryBackoff: _backoff,
    ),
  );
}

bool _enabled(WidgetTester tester, ValueKey<String> key) =>
    tester.widget<GestureDetector>(find.byKey(key)).onTap != null;

LruVideoSlots _slotsWithCapOf(int cap) {
  final LruVideoSlots slots = LruVideoSlots(cap: cap);
  addTearDown(slots.dispose);
  return slots;
}

void main() {
  group('VideoBody decoder slot gating', () {
    testWidgets('renders neutral with disabled controls when the cap denies a '
        'slot', (WidgetTester tester) async {
      final LruVideoSlots slots = _slotsWithCapOf(1);
      final VideoSlotToken? occupant = slots.acquire(onEvicted: () {});
      expect(occupant, isNotNull);

      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];
      await tester.pumpWidget(
        _card(
          resolver: _resolverFor(_videoFile()),
          playerFactory: _factoryInto(built),
          slots: slots,
        ),
      );
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(find.byType(NeutralMediaPlaceholder), findsOneWidget);
      expect(built, isEmpty);
      expect(find.byKey(_surface), findsNothing);
      expect(_enabled(tester, _playToggle), isFalse);
      expect(_enabled(tester, _muteToggle), isFalse);
    });

    testWidgets('a freed slot promotes a waiting card to loaded', (
      WidgetTester tester,
    ) async {
      final LruVideoSlots slots = _slotsWithCapOf(1);
      final VideoSlotToken? occupant = slots.acquire(onEvicted: () {});
      final File file = _videoFile();
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        _card(
          resolver: _resolverFor(file),
          playerFactory: _factoryInto(built),
          slots: slots,
        ),
      );
      await tester.pump();
      expect(built, isEmpty);

      slots.release(occupant);
      await tester.pump();

      expect(built, hasLength(1));
      expect(built.single.loadCalls, <String>[file.path]);
      expect(find.byKey(_surface), findsOneWidget);
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(_enabled(tester, _playToggle), isTrue);
    });

    testWidgets('a failing load retries twice and then offers Try again', (
      WidgetTester tester,
    ) async {
      final File file = _videoFile();
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        _card(
          resolver: _resolverFor(file),
          playerFactory: _factoryInto(
            built,
            setUpPlayer: (FakeEntryVideoPlayer player, int index) {
              if (index < 3) {
                player.loadError = StateError('decoder busy');
              }
            },
          ),
          slots: const UnlimitedVideoSlots(),
        ),
      );
      await tester.pump();

      expect(built, hasLength(1));
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);

      await tester.pump(const Duration(milliseconds: 15));
      await tester.pump();
      expect(built, hasLength(2));
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);

      await tester.pump(const Duration(milliseconds: 25));
      await tester.pump();
      expect(built, hasLength(3));
      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
      expect(find.byKey(_retryButton), findsOneWidget);

      await tester.tap(find.byKey(_retryButton));
      await tester.pump();

      expect(built, hasLength(4));
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(find.byKey(_surface), findsOneWidget);
    });

    testWidgets('a hanging load retries through the timeout instead of going '
        'red', (WidgetTester tester) async {
      final File file = _videoFile();
      final Completer<void> gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) {
          gate.complete();
        }
      });
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        _card(
          resolver: _resolverFor(file),
          playerFactory: _factoryInto(
            built,
            setUpPlayer: (FakeEntryVideoPlayer player, int index) {
              if (index == 0) {
                player.loadGate = gate;
              }
            },
          ),
          slots: const UnlimitedVideoSlots(),
        ),
      );
      await tester.pump();

      expect(built, hasLength(1));
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(built.first.disposeCalls, 1);

      await tester.pump(const Duration(milliseconds: 25));
      await tester.pump();

      expect(built, hasLength(2));
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(find.byKey(_surface), findsOneWidget);
    });

    testWidgets('a zero length file goes red with no retries', (
      WidgetTester tester,
    ) async {
      final File file = _videoFile(bytes: 0);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        _card(
          resolver: _resolverFor(file),
          playerFactory: _factoryInto(
            built,
            setUpPlayer: (FakeEntryVideoPlayer player, int index) =>
                player.loadError = StateError('empty file'),
          ),
          slots: const UnlimitedVideoSlots(),
        ),
      );
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);

      await tester.pump(_pastBackoff);
      await tester.pump();

      expect(built, hasLength(1));
      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
    });

    testWidgets('a vanished file goes red with no retries', (
      WidgetTester tester,
    ) async {
      final File file = _videoFile(create: false);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        _card(
          resolver: _resolverFor(file),
          playerFactory: _factoryInto(
            built,
            setUpPlayer: (FakeEntryVideoPlayer player, int index) =>
                player.loadError = StateError('no such file'),
          ),
          slots: const UnlimitedVideoSlots(),
        ),
      );
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);

      await tester.pump(_pastBackoff);
      await tester.pump();

      expect(built, hasLength(1));
      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
    });

    testWidgets('eviction returns a loaded card to neutral and disposes its '
        'player', (WidgetTester tester) async {
      final LruVideoSlots slots = _slotsWithCapOf(1);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        _card(
          resolver: _resolverFor(_videoFile()),
          playerFactory: _factoryInto(built),
          slots: slots,
        ),
      );
      await tester.pump();
      expect(find.byKey(_surface), findsOneWidget);

      final VideoSlotToken? intruder = slots.acquire(onEvicted: () {});
      expect(intruder, isNotNull);
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(find.byType(NeutralMediaPlaceholder), findsOneWidget);
      expect(find.byKey(_surface), findsNothing);
      expect(built.single.disposeCalls, 1);
      expect(_enabled(tester, _playToggle), isFalse);
    });

    testWidgets('reaching ready restores the full retry budget', (
      WidgetTester tester,
    ) async {
      final File file = _videoFile();
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        _card(
          resolver: _resolverFor(file),
          playerFactory: _factoryInto(
            built,
            setUpPlayer: (FakeEntryVideoPlayer player, int index) {
              if (index != 1) {
                player.loadError = StateError('decoder busy');
              }
            },
          ),
          slots: const UnlimitedVideoSlots(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 15));
      await tester.pump();

      expect(built, hasLength(2));
      expect(find.byKey(_surface), findsOneWidget);

      built[1].emitState(VideoPlaybackState.error);
      await tester.pump();
      await tester.pump(_pastBackoff);
      await tester.pump();
      await tester.pump(_pastBackoff);
      await tester.pump();

      expect(built, hasLength(4));
      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
    });

    testWidgets('a mid playback error reloads and resumes instead of latching '
        'red', (WidgetTester tester) async {
      final File file = _videoFile();
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        _card(
          resolver: _resolverFor(file),
          playerFactory: _factoryInto(built),
          slots: const UnlimitedVideoSlots(),
        ),
      );
      await tester.pump();

      built.single.emitState(VideoPlaybackState.playing);
      built.single.emitPosition(const Duration(seconds: 5));
      await tester.pump();

      built.first.emitState(VideoPlaybackState.error);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 15));
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(built, hasLength(2));
      expect(built[1].loadCalls, <String>[file.path]);
      expect(built[1].seekCalls, <Duration>[const Duration(seconds: 5)]);
      expect(built[1].playCalls, 0);
      expect(built[0].disposeCalls, 1);
    });

    testWidgets('a playing card is pinned and survives cap pressure', (
      WidgetTester tester,
    ) async {
      final LruVideoSlots slots = _slotsWithCapOf(1);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        _card(
          resolver: _resolverFor(_videoFile()),
          playerFactory: _factoryInto(built),
          slots: slots,
        ),
      );
      await tester.pump();

      built.single.emitState(VideoPlaybackState.playing);
      await tester.pump();

      expect(slots.acquire(onEvicted: () {}), isNull);
      await tester.pump();

      expect(find.byKey(_surface), findsOneWidget);
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(built.single.disposeCalls, 0);
      expect(_enabled(tester, _playToggle), isTrue);
    });

    testWidgets('Try again restores the full retry budget', (
      WidgetTester tester,
    ) async {
      final File file = _videoFile();
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        _card(
          resolver: _resolverFor(file),
          playerFactory: _factoryInto(
            built,
            setUpPlayer: (FakeEntryVideoPlayer player, int index) =>
                player.loadError = StateError('decoder busy'),
          ),
          slots: const UnlimitedVideoSlots(),
        ),
      );
      await tester.pump();
      await tester.pump(_pastBackoff);
      await tester.pump();
      await tester.pump(_pastBackoff);
      await tester.pump();

      expect(built, hasLength(3));
      expect(find.byKey(_retryButton), findsOneWidget);

      await tester.tap(find.byKey(_retryButton));
      await tester.pump();
      await tester.pump(_pastBackoff);
      await tester.pump();
      await tester.pump(_pastBackoff);
      await tester.pump();

      expect(built, hasLength(6));
      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
      expect(find.byKey(_retryButton), findsOneWidget);
    });
  });
}
