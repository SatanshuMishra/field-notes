import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';

import 'entry_cards_harness.dart';
import 'fake_video_player.dart';

const ValueKey<String> videoPlayToggleKey =
    ValueKey<String>('video-play-toggle');
const ValueKey<String> videoMuteToggleKey =
    ValueKey<String>('video-mute-toggle');
const ValueKey<String> videoScrubBarKey = ValueKey<String>('video-scrub-bar');
const ValueKey<String> videoSurfaceKey =
    ValueKey<String>('fake-video-surface');
const ValueKey<String> mediaRetryKey = ValueKey<String>('media-retry');

const Duration videoLoadTimeout = Duration(milliseconds: 100);
const List<Duration> videoBackoff = <Duration>[
  Duration(milliseconds: 10),
  Duration(milliseconds: 20),
];
const Duration pastFirstBackoff = Duration(milliseconds: 15);
const Duration pastAllBackoff = Duration(milliseconds: 200);

typedef VideoPlayerSetup = void Function(FakeEntryVideoPlayer player, int index);

File videoFixtureFile({String prefix = 'video_card', int bytes = 8}) {
  final Directory dir = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  final File file = File('${dir.path}/v.mp4');
  file.writeAsBytesSync(List<int>.filled(bytes, 0));
  return file;
}

File posterFixtureFile() {
  final Directory dir = Directory.systemTemp.createTempSync('video_poster');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  final File file = File('${dir.path}/p.png');
  file.writeAsBytesSync(onePixelPngBytes());
  return file;
}

FakeMediaResolver videoResolverFor(File file, {File? poster}) {
  final FakeMediaResolver resolver = FakeMediaResolver()
    ..set(
      'vid',
      ResolvedMedia.available(
        blob: blobOf(id: 'vid', relPath: 'v.mp4', kind: MediaKind.video),
        file: file,
      ),
    );
  if (poster != null) {
    resolver.set(
      'thumb',
      ResolvedMedia.available(
        blob: blobOf(id: 'thumb', relPath: 'p.png'),
        file: poster,
      ),
    );
  }
  return resolver;
}

EntryVideoPlayerFactory videoFactoryInto(
  List<FakeEntryVideoPlayer> built, {
  VideoPlayerSetup? setUpPlayer,
}) {
  return () {
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    setUpPlayer?.call(player, built.length);
    built.add(player);
    return player;
  };
}

LruVideoSlots slotsWithCapOf(int cap) {
  final LruVideoSlots slots = LruVideoSlots(cap: cap);
  addTearDown(slots.dispose);
  return slots;
}

Widget videoCardColumn({
  required MediaResolver resolver,
  required EntryVideoPlayerFactory playerFactory,
  required VideoSlots slots,
  required List<int> indices,
  String? thumbnailMediaId,
  int? durationMs = 65000,
}) {
  return cardHarness(
    SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final int index in indices)
            VideoBody(
              key: ValueKey<String>('card-$index'),
              entry: entryOf(
                id: 'e$index',
                type: EntryType.video,
                mediaId: 'vid',
                thumbnailMediaId: thumbnailMediaId,
                durationMs: durationMs,
              ),
              resolver: resolver,
              playerFactory: playerFactory,
              slots: slots,
              loadTimeout: videoLoadTimeout,
              retryBackoff: videoBackoff,
            ),
        ],
      ),
    ),
  );
}

Finder cardAt(int index) => find.byKey(ValueKey<String>('card-$index'));

Finder inCard(int index, Key key) =>
    find.descendant(of: cardAt(index), matching: find.byKey(key));

bool tapEnabled(WidgetTester tester, Finder finder) =>
    tester.widget<GestureDetector>(finder).onTap != null;

bool readyControlsEnabled(WidgetTester tester, int index) =>
    tapEnabled(tester, inCard(index, videoMuteToggleKey));

bool surfaceMounted(WidgetTester tester, int index) =>
    inCard(index, videoSurfaceKey).evaluate().isNotEmpty;
