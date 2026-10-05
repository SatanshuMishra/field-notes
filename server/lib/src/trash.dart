import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'auth.dart';
import 'blobs.dart';
import 'database.dart';

const String trashFolderName = '.trash';

String trashPath(String mediaDirectory) =>
    p.join(mediaDirectory, trashFolderName);

String stagingTrashPath(String mediaDirectory) =>
    p.join(mediaDirectory, stagingFolderName, trashFolderName);

Directory? _moveToTrash(Directory source, String trashRoot, String label) {
  if (!source.existsSync()) {
    return null;
  }
  try {
    Directory(trashRoot).createSync(recursive: true);
    return source.renameSync(p.join(trashRoot, label));
  } on FileSystemException {
    return source;
  }
}

List<Directory> trashAccountMedia(
  String mediaDirectory,
  String accountId,
  List<String> uploadIds,
  DateTime now,
) {
  final int millis = toMillis(now);
  final List<Directory?> moved = <Directory?>[
    _moveToTrash(
      Directory(accountMediaPath(mediaDirectory, accountId)),
      trashPath(mediaDirectory),
      '$accountId-$millis',
    ),
    for (final String uploadId in uploadIds)
      _moveToTrash(
        Directory(stagingPath(mediaDirectory, uploadId)),
        stagingTrashPath(mediaDirectory),
        '$uploadId-$millis',
      ),
  ];
  return moved.whereType<Directory>().toList();
}

Future<void> deleteQuietly(Directory directory) async {
  try {
    await directory.delete(recursive: true);
  } on FileSystemException {
    return;
  }
}

void deleteQuietlySync(Directory directory) {
  try {
    directory.deleteSync(recursive: true);
  } on FileSystemException {
    return;
  }
}

Future<void> clearLeftovers(
  RelayDatabase database,
  String mediaDirectory,
) async {
  final List<Directory> leftovers = <Directory>[
    Directory(trashPath(mediaDirectory)),
    Directory(stagingTrashPath(mediaDirectory)),
    ..._orphanAccounts(database, mediaDirectory),
    ..._orphanUploads(database, mediaDirectory),
  ];
  for (final Directory directory in leftovers) {
    if (directory.existsSync()) {
      await deleteQuietly(directory);
    }
  }
}

Iterable<Directory> _orphanAccounts(
  RelayDatabase database,
  String mediaDirectory,
) => _children(mediaDirectory).where((Directory directory) {
  final String accountId = p.basename(directory.path);
  if (!isSyncId(accountId)) {
    return false;
  }
  final Row? account = database.selectOne(
    'SELECT status FROM accounts WHERE id = ?',
    <Object?>[accountId],
  );
  return account == null ||
      account['status'] == AccountStatus.erased.storedName;
});

Iterable<Directory> _orphanUploads(
  RelayDatabase database,
  String mediaDirectory,
) =>
    _children(p.join(mediaDirectory, stagingFolderName))
        .where((Directory directory) {
          final String uploadId = p.basename(directory.path);
          return isUploadId(uploadId) &&
              database.count(
                    'SELECT count(*) FROM uploads WHERE id = ?',
                    <Object?>[uploadId],
                  ) ==
                  0;
        });

List<Directory> _children(String path) {
  final Directory parent = Directory(path);
  if (!parent.existsSync()) {
    return const <Directory>[];
  }
  return parent.listSync(followLinks: false).whereType<Directory>().toList();
}
