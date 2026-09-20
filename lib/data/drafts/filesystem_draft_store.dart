import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../../domain/services/draft_store.dart';
import 'draft_paths.dart';

const String _tmpSubdir = '.tmp';

class FilesystemDraftStore implements DraftStore {
  FilesystemDraftStore({required this.root});

  final Directory root;
  final Random _random = Random();

  @override
  Future<String?> read(String key) async {
    final file = _fileFor(key);
    try {
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsString();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> write(String key, String source) async {
    final file = _fileFor(key);
    final tmpDir = Directory(p.join(root.path, _tmpSubdir));
    File? tmp;
    try {
      await tmpDir.create(recursive: true);
      await file.parent.create(recursive: true);
      tmp = File(p.join(tmpDir.path, _tmpName()));
      await tmp.writeAsString(source, flush: true);
      await tmp.rename(file.path);
    } on FileSystemException catch (e) {
      if (tmp != null) {
        await _bestEffortDelete(tmp);
      }
      throw DraftWriteException('failed to write draft $key', e);
    }
  }

  @override
  Future<void> delete(String key) async {
    final file = _fileFor(key);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException catch (e) {
      throw DraftWriteException('failed to delete draft $key', e);
    }
  }

  File _fileFor(String key) => File(p.join(root.path, draftFileName(key)));

  String _tmpName() =>
      'draft-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}.part';

  Future<void> _bestEffortDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      return;
    }
  }
}
