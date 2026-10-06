import 'dart:io';

import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/domain/services/delete_all_service.dart';

typedef UploadCanceller = Future<void> Function();

final class LocalJournalWipe {
  LocalJournalWipe({
    required AppDatabase database,
    required this._keyStore,
    required this._deleteAll,
    this._workDirectories = const <Directory>[],
    this._cancelUploads,
  }) : _db = database;

  static const List<String> keptStates = <String>[
    ChangeRecorder.nodeIdKey,
    ChangeRecorder.lastClockKey,
  ];

  final AppDatabase _db;
  final KeyStore _keyStore;
  final DeleteAllService _deleteAll;
  final List<Directory> _workDirectories;
  final UploadCanceller? _cancelUploads;

  Future<void> wipe() async {
    await _cancelUploads?.call();
    await _deleteAll.deleteAll();
    await _db.transaction(() async {
      await _db.delete(_db.syncOutbox).go();
      await _db.delete(_db.syncRecordSeqs).go();
      await _db.delete(_db.syncTextBases).go();
      await _db.delete(_db.syncHeldStates).go();
      await _db.delete(_db.syncUploads).go();
      await _db.delete(_db.syncMediaCache).go();
      await _db.delete(_db.journalSettings).go();
      await (_db.delete(
        _db.syncStates,
      )..where((t) => t.key.isNotIn(keptStates))).go();
    });
    await _keyStore.wipe();
    for (final Directory directory in _workDirectories) {
      try {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      } on FileSystemException {
        continue;
      }
    }
    await _cancelUploads?.call();
  }
}
