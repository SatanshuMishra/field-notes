import 'dart:io';

import 'package:field_notes/data/drafts/draft_paths.dart';
import 'package:field_notes/data/drafts/filesystem_draft_store.dart';
import 'package:field_notes/domain/services/draft_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'draft_provider.g.dart';

@Riverpod(keepAlive: true)
Future<Directory> draftRoot(Ref ref) async {
  final documents = await getApplicationDocumentsDirectory();
  return Directory(p.join(documents.path, draftsSubdir));
}

@Riverpod(keepAlive: true)
Future<DraftStore> draftStore(Ref ref) async {
  final root = await ref.watch(draftRootProvider.future);
  return FilesystemDraftStore(root: root);
}
