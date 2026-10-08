import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:field_notes/data/database/journal_directory.dart';
import 'package:path/path.dart' as p;

const String databaseFileName = 'field_notes.sqlite';

LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final directory = await journalDirectory();
    final file = File(p.join(directory.path, databaseFileName));
    return NativeDatabase.createInBackground(file);
  });
}
