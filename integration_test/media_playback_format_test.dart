import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/domain/models/media_kind.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/just_audio_player.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_player_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'fixtures/tiny_media_fixtures.dart';

const Duration _bound = Duration(seconds: 30);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory root;
  late FilesystemMediaStore store;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('fn_playback_format');
    store = FilesystemMediaStore(database: db, root: root);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  testWidgets('a stored video blob loads in the real video player',
      (tester) async {
    final blob = await store.putBytes(
      bytes: tinyMovBytes(),
      mime: 'video/mp4',
      kind: MediaKind.video,
    );

    final resolved = await MediaStoreResolver(store).resolve(blob.id);
    expect(resolved.isAvailable, isTrue);
    expect(p.extension(resolved.file!.path), isNotEmpty);

    final EntryVideoPlayer player = createVideoPlayerEntryPlayer();
    addTearDown(player.dispose);

    await player.load(resolved.file!.path).timeout(_bound);

    expect(player.state, VideoPlaybackState.ready);
  });

  testWidgets('a stored audio blob loads in the real audio player',
      (tester) async {
    final blob = await store.putBytes(
      bytes: tinyM4aBytes(),
      mime: 'audio/mp4',
      kind: MediaKind.audio,
    );

    final resolved = await MediaStoreResolver(store).resolve(blob.id);
    expect(resolved.isAvailable, isTrue);
    expect(p.extension(resolved.file!.path), isNotEmpty);

    final player = createJustAudioPlayer();
    addTearDown(player.dispose);

    await player.load(resolved.file!.path).timeout(_bound);

    expect(player.duration, isNotNull);
  });
}
