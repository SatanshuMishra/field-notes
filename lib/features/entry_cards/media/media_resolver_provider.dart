import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/media/syncing_media_resolver.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final FutureProvider<MediaResolver> mediaResolverProvider =
    FutureProvider<MediaResolver>((Ref ref) async {
      final MediaStore store = await ref.watch(mediaStoreProvider.future);
      final MediaStoreResolver local = MediaStoreResolver(store);
      if (store is! FilesystemMediaStore) {
        return local;
      }
      if (!await ref.watch(syncEnabledProvider.future)) {
        return local;
      }
      final AppDatabase database = ref.watch(databaseProvider);
      final SyncEngine engine = ref.watch(syncEngineProvider);
      final SyncMedia media = await ref.watch(syncMediaProvider.future);
      return SyncingMediaResolver(
        inner: local,
        store: store,
        fetch: engine.fetchMedia,
        posterOf: (String blobId) async => (await (database.select(
          database.mediaBlobs,
        )..where((t) => t.id.equals(blobId))).getSingleOrNull())?.posterId,
        recordOpen: media.cache.recordOpen,
        progressOf: media.downloads.progress,
      );
    });
