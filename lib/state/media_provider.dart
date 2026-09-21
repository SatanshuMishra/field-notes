import 'dart:io';

import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/drafts/draft_paths.dart';
import 'package:field_notes/data/media/blob_extension_backfill.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_provider.g.dart';

const String mediaSubdir = 'media';

@Riverpod(keepAlive: true)
Future<Directory> mediaRoot(Ref ref) async {
  final documents = await getApplicationDocumentsDirectory();
  return Directory(p.join(documents.path, mediaSubdir));
}

@Riverpod(keepAlive: true)
Future<Directory> mediaDraftsRoot(Ref ref) async {
  final root = await ref.watch(mediaRootProvider.future);
  return Directory(p.join(p.dirname(root.path), draftsSubdir));
}

@Riverpod(keepAlive: true)
Future<MediaStore> mediaStore(Ref ref) async {
  final database = ref.watch(databaseProvider);
  final root = await ref.watch(mediaRootProvider.future);
  final drafts = await ref.watch(mediaDraftsRootProvider.future);
  await _runBackfill(database, root);
  return FilesystemMediaStore(
    database: database,
    root: root,
    drafts: drafts,
  );
}

Future<void> _runBackfill(AppDatabase database, Directory root) async {
  try {
    await BlobExtensionBackfill(database: database, root: root).run();
  } catch (error, stackTrace) {
    debugPrint('Media blob extension backfill skipped: $error\n$stackTrace');
  }
}
