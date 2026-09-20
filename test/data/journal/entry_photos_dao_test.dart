import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/journal/entry_photos_dao.dart';

import 'journal_test_db.dart';

Future<void> _seedDayAndEntry(AppDatabase db) async {
  await db.into(db.days).insert(
        DaysCompanion.insert(
          id: 'd1',
          date: '2026-07-12',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
  await db.into(db.entries).insert(
        EntriesCompanion.insert(
          id: 'e1',
          dayId: 'd1',
          type: 'text',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
}

void main() {
  late AppDatabase db;
  late EntryPhotosDao dao;

  setUp(() async {
    db = newTestDatabase();
    dao = EntryPhotosDao(db);
    await _seedDayAndEntry(db);
    await seedMediaBlob(db, 'blob-a');
    await seedMediaBlob(db, 'blob-b');
  });

  tearDown(() async {
    await db.close();
  });

  test('insertPhoto returns the row and activePhotosForEntry sorts by sortOrder',
      () async {
    await dao.insertPhoto(
      id: 'p2',
      entryId: 'e1',
      mediaId: 'blob-b',
      sortOrder: 2,
      createdAt: 0,
      updatedAt: 0,
    );
    await dao.insertPhoto(
      id: 'p1',
      entryId: 'e1',
      mediaId: 'blob-a',
      sortOrder: 1,
      createdAt: 0,
      updatedAt: 0,
    );

    final photos = await dao.activePhotosForEntry('e1');

    expect(photos.map((p) => p.id).toList(), ['p1', 'p2']);
  });

  test('softDelete hides the photo from active reads', () async {
    await dao.insertPhoto(
      id: 'p1',
      entryId: 'e1',
      mediaId: 'blob-a',
      sortOrder: 1,
      createdAt: 0,
      updatedAt: 0,
    );

    await dao.softDelete(id: 'p1', deletedAt: 42);

    expect(await dao.activePhotosForEntry('e1'), isEmpty);
  });

  test('watchActivePhotosForEntry reacts to new photos', () async {
    final emissions = <List<String>>[];
    final sub = dao
        .watchActivePhotosForEntry('e1')
        .listen((rows) => emissions.add(rows.map((p) => p.id).toList()));

    await dao.insertPhoto(
      id: 'p1',
      entryId: 'e1',
      mediaId: 'blob-a',
      sortOrder: 1,
      createdAt: 0,
      updatedAt: 0,
    );
    await pumpEventQueue();

    expect(emissions.last, ['p1']);
    await sub.cancel();
  });

  test('replacePhotos clears the existing rows and inserts the new set in '
      'sort order', () async {
    await seedMediaBlob(db, 'blob-c');
    await dao.insertPhoto(
      id: 'old-1',
      entryId: 'e1',
      mediaId: 'blob-a',
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
    );
    await dao.insertPhoto(
      id: 'old-2',
      entryId: 'e1',
      mediaId: 'blob-b',
      sortOrder: 1,
      createdAt: 0,
      updatedAt: 0,
    );
    await dao.softDelete(id: 'old-2', deletedAt: 5);
    var counter = 0;

    final rows = await dao.replacePhotos(
      entryId: 'e1',
      mediaIds: ['blob-c', 'blob-a'],
      now: 42,
      newId: () => 'new-${counter++}',
    );

    expect(rows.map((r) => r.id).toList(), ['new-0', 'new-1']);
    expect(rows.map((r) => r.sortOrder).toList(), [0, 1]);
    expect(rows.map((r) => r.createdAt).toSet(), {42});
    final active = await dao.activePhotosForEntry('e1');
    expect(active.map((r) => r.mediaId).toList(), ['blob-c', 'blob-a']);
    final all = await db.select(db.entryPhotos).get();
    expect(all.map((r) => r.id).toSet(), {'new-0', 'new-1'});
  });

  test('replacePhotos with no media ids empties the entry index', () async {
    await dao.insertPhoto(
      id: 'old-1',
      entryId: 'e1',
      mediaId: 'blob-a',
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
    );

    final rows = await dao.replacePhotos(
      entryId: 'e1',
      mediaIds: const [],
      now: 42,
      newId: () => 'unused',
    );

    expect(rows, isEmpty);
    expect(await db.select(db.entryPhotos).get(), isEmpty);
  });
}
