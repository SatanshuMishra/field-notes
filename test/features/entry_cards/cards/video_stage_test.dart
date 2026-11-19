import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/video/camera_picture_fill.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';
import 'package:field_notes/features/entry_cards/media/hatched_media_image.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots_provider.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../../day_detail/support/day_detail_harness.dart'
    show FakeJournalRepository;
import '../support/entry_cards_harness.dart' show FakeMediaResolver;
import '../support/fake_video_player.dart';
import '../support/video_card_harness.dart'
    show posterFixtureFile, videoFixtureFile, videoResolverFor;

const Size _box = Size(800, 450);
const double _upright = 1080 / 1920;
const ValueKey<String> _surfaceKey = ValueKey<String>('fake-video-surface');

Entry _video({String? thumbnailMediaId}) {
  final int at = DateTime(2026, 7, 19, 9, 12).millisecondsSinceEpoch;
  return Entry(
    id: 'video-1',
    dayId: 'day-1',
    type: EntryType.video,
    mediaId: 'vid',
    thumbnailMediaId: thumbnailMediaId,
    durationMs: 64000,
    createdAt: at,
    updatedAt: at,
  );
}

FakeMediaResolver _resolver({bool poster = false}) {
  final FakeMediaResolver resolver = videoResolverFor(
    videoFixtureFile(),
    poster: poster ? posterFixtureFile() : null,
  )..memoize('vid');
  if (poster) {
    resolver.memoize('thumb');
  }
  return resolver;
}

Widget _bodyHost(Widget body, {bool reduceMotion = false}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Center(
      child: SizedBox.fromSize(size: _box, child: body),
    ),
  ),
);

VideoBody _body({
  required FakeEntryVideoPlayer player,
  required double? aspectRatio,
  bool poster = false,
  VideoControlsHandle? handle,
}) => VideoBody(
  entry: _video(thumbnailMediaId: poster ? 'thumb' : null),
  resolver: _resolver(poster: poster),
  playerFactory: () => player,
  slots: const UnlimitedVideoSlots(),
  aspectRatio: aspectRatio,
  handle: handle,
  controls: (BuildContext context, VideoControlsState state) =>
      const SizedBox.shrink(),
);

Future<void> _frames(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame += 1) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _picture() => find.byKey(cameraPictureKey);

Finder _fill() => find.byKey(cameraPictureFillKey);

Finder _ring() => find.byKey(videoLoadingRingKey);

void _expectRect(Rect actual, Rect expected, {double within = 1}) {
  expect(actual.left, closeTo(expected.left, within), reason: '$actual');
  expect(actual.top, closeTo(expected.top, within), reason: '$actual');
  expect(actual.width, closeTo(expected.width, within), reason: '$actual');
  expect(actual.height, closeTo(expected.height, within), reason: '$actual');
}

Rect _rectWithin(WidgetTester tester, Finder inner, Finder outer) {
  final RenderBox box = tester.renderObject<RenderBox>(inner);
  final RenderBox frame = tester.renderObject<RenderBox>(outer);
  return frame.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
}

final class _Card {
  final List<FakeEntryVideoPlayer> players = <FakeEntryVideoPlayer>[];
}

Future<_Card> _pumpCard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final VideoSlots slots = LruVideoSlots(cap: 2);
  addTearDown(slots.dispose);
  final _Card card = _Card();
  final Entry entry = _video(thumbnailMediaId: 'thumb');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        journalRepositoryProvider.overrideWithValue(
          FakeJournalRepository(entries: <Entry>[entry]),
        ),
        todayVideoPlayerFactoryProvider.overrideWithValue(() {
          final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
          card.players.add(player);
          return player;
        }),
        videoSlotsProvider.overrideWithValue(slots),
        videoAspectProvider.overrideWith((Ref ref, String mediaId) => _upright),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              CompactLogCard(
                entry: entry,
                resolver: _resolver(poster: true),
                density: CompactLogDensity.feed,
                onOpen: () {},
                onDelete: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await _frames(tester);
  return card;
}

Finder _posterPicture() => find.descendant(
  of: find.byKey(compactLogPosterKey),
  matching: find.descendant(of: _picture(), matching: find.byType(Image)),
);

void main() {
  testWidgets(
    'an upright video is shown whole and centred with its own picture fill around it',
    (WidgetTester tester) async {
      final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
      await tester.pumpWidget(
        _bodyHost(_body(player: player, aspectRatio: 9 / 16)),
      );
      await _frames(tester);
      player.emitState(VideoPlaybackState.paused);
      await _frames(tester);

      expect(find.byType(CameraPictureStage), findsOneWidget);
      final Rect box = tester.getRect(find.byType(VideoBody));
      final Rect picture = tester.getRect(_picture());
      expect(picture.width, closeTo(253, 1));
      expect(picture.height, closeTo(450, 1));
      expect(picture.left - box.left, closeTo(273, 1));
      expect(
        find.descendant(of: _picture(), matching: find.byKey(_surfaceKey)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _fill(), matching: find.byKey(_surfaceKey)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'no picture fill is drawn when the video fills its box or motion is reduced',
    (WidgetTester tester) async {
      final FakeEntryVideoPlayer wide = FakeEntryVideoPlayer();
      await tester.pumpWidget(
        _bodyHost(_body(player: wide, aspectRatio: 16 / 9)),
      );
      await _frames(tester);
      wide.emitState(VideoPlaybackState.paused);
      await _frames(tester);

      expect(find.byType(CameraPictureStage), findsOneWidget);
      expect(_fill(), findsNothing);

      final FakeEntryVideoPlayer upright = FakeEntryVideoPlayer();
      await tester.pumpWidget(
        _bodyHost(
          _body(player: upright, aspectRatio: 9 / 16),
          reduceMotion: true,
        ),
      );
      await _frames(tester);
      upright.emitState(VideoPlaybackState.paused);
      await _frames(tester);

      expect(find.byType(CameraPictureStage), findsOneWidget);
      expect(_fill(), findsNothing);
    },
  );

  testWidgets(
    'before the first frame a video shows its thumbnail with a small ring and no hatching',
    (WidgetTester tester) async {
      final FakeEntryVideoPlayer withPoster = FakeEntryVideoPlayer();
      final VideoControlsHandle handle = VideoControlsHandle();
      addTearDown(handle.dispose);
      await tester.pumpWidget(
        _bodyHost(
          _body(
            player: withPoster,
            aspectRatio: 16 / 9,
            poster: true,
            handle: handle,
          ),
        ),
      );
      await _frames(tester);
      handle.state!.onToggle!();
      await _frames(tester);

      expect(withPoster.loadCalls, hasLength(1));
      expect(find.byType(CrossHatchPlaceholder), findsNothing);
      final Finder still = find.descendant(
        of: find.byType(VideoStillStage),
        matching: find.descendant(
          of: find.byType(CameraPictureStage),
          matching: find.descendant(
            of: _picture(),
            matching: find.byType(Image),
          ),
        ),
      );
      expect(still, findsOneWidget);
      expect(_ring(), findsOneWidget);
      final Rect ring = tester.getRect(_ring());
      final Rect thumbnail = tester.getRect(still);
      expect(thumbnail.contains(ring.center), isTrue);
      expect(ring.width, lessThan(thumbnail.width / 4));

      withPoster.emitState(VideoPlaybackState.paused);
      await _frames(tester);
      expect(_ring(), findsNothing);

      final FakeEntryVideoPlayer bare = FakeEntryVideoPlayer();
      await tester.pumpWidget(
        _bodyHost(_body(player: bare, aspectRatio: 16 / 9)),
      );
      await _frames(tester);

      expect(bare.loadCalls, hasLength(1));
      expect(find.byType(CrossHatchPlaceholder), findsNothing);
      expect(find.byType(VideoStillStage), findsNothing);
      expect(_ring(), findsOneWidget);
      final ColoredBox ground = tester.widget<ColoredBox>(
        find.ancestor(of: _ring(), matching: find.byType(ColoredBox)).first,
      );
      expect(ground.color, Palette.mediaBlack);

      bare.emitState(VideoPlaybackState.paused);
      await _frames(tester);
      expect(_ring(), findsNothing);
    },
  );

  testWidgets(
    'the Today card shows an upright video thumbnail whole and centred before play',
    (WidgetTester tester) async {
      await _pumpCard(tester);

      expect(find.byType(HatchedMediaImage), findsNothing);
      expect(
        find.ancestor(
          of: _posterPicture(),
          matching: find.byType(CameraPictureStage),
        ),
        findsOneWidget,
      );
      final Finder stage = find.ancestor(
        of: _posterPicture(),
        matching: find.byType(CameraPictureStage),
      );
      final Size media = tester.getSize(stage);
      final Rect picture = _rectWithin(tester, _posterPicture(), stage);
      expect(media.width, greaterThan(media.height));
      expect(
        picture.width / picture.height,
        closeTo(_upright, _upright * 0.01),
      );
      expect(picture.height, closeTo(media.height, 1));
      expect(picture.center.dx, closeTo(media.width / 2, 1));
      expect(picture.center.dy, closeTo(media.height / 2, 1));
    },
  );

  testWidgets('pressing play on the Today card keeps the picture in place', (
    WidgetTester tester,
  ) async {
    final _Card card = await _pumpCard(tester);
    final Rect before = tester.getRect(_posterPicture());

    await tester.tap(find.byKey(compactLogVideoPlayKey));
    await _frames(tester);

    final FakeEntryVideoPlayer player = card.players.single;
    expect(player.loadCalls, hasLength(1));
    expect(_posterPicture(), findsOneWidget);
    _expectRect(tester.getRect(_posterPicture()), before);

    player.emitState(VideoPlaybackState.playing);
    await _frames(tester);

    final Finder playing = find.descendant(
      of: find.byType(VideoBody),
      matching: find.descendant(
        of: _picture(),
        matching: find.byKey(_surfaceKey),
      ),
    );
    expect(playing, findsOneWidget);
    _expectRect(tester.getRect(playing), before);
  });
}
