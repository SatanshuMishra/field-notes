import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String databaseFileName = 'field_notes.sqlite';

LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, databaseFileName));
    return NativeDatabase.createInBackground(file);
  });
}
