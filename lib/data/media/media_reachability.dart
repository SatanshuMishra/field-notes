import 'package:drift/drift.dart';

import '../database/app_database.dart';

Future<Set<String>> liveJournalMediaIds(AppDatabase database) async {
  final $EntriesTable entries = database.entries;
  final List<TypedResult> withMedia =
      await (database.selectOnly(entries)
            ..addColumns(<Expression<Object>>[
              entries.mediaId,
              entries.thumbnailMediaId,
            ])
            ..where(
              entries.deletedAt.isNull() &
                  (entries.mediaId.isNotNull() |
                      entries.thumbnailMediaId.isNotNull()),
            ))
          .get();
  final List<TypedResult> photos =
      await (database.selectOnly(database.entryPhotos)
            ..addColumns(<Expression<Object>>[database.entryPhotos.mediaId])
            ..where(database.entryPhotos.deletedAt.isNull()))
          .get();
  return Set<String>.unmodifiable(<String>{
    for (final TypedResult row in withMedia)
      ...<String?>[
        row.read(entries.mediaId),
        row.read(entries.thumbnailMediaId),
      ].nonNulls,
    for (final TypedResult row in photos)
      ?row.read(database.entryPhotos.mediaId),
  });
}
