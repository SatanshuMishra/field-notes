import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';

AppDatabase newTestDatabase() => AppDatabase(NativeDatabase.memory());

int Function() fixedClock(int value) => () => value;

String Function() sequentialIds([String prefix = 'id']) {
  var counter = 0;
  return () => '$prefix-${(counter++).toString().padLeft(4, '0')}';
}

Future<void> seedMediaBlob(AppDatabase db, String id) {
  return db.into(db.mediaBlobs).insert(
        MediaBlobsCompanion.insert(
          id: id,
          relPath: 'blobs/$id',
          mime: 'image/jpeg',
          kind: 'photo',
          bytes: 1,
          createdAt: 0,
        ),
      );
}
