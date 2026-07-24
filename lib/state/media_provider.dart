import 'dart:io';

import 'package:field_notes/data/media/blob_extension_backfill.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/state/database_provider.dart';
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
Future<MediaStore> mediaStore(Ref ref) async {
  final database = ref.watch(databaseProvider);
  final root = await ref.watch(mediaRootProvider.future);
  await BlobExtensionBackfill(database: database, root: root).run();
  return FilesystemMediaStore(database: database, root: root);
}
