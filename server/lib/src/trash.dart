import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'auth.dart';
import 'blobs.dart';
import 'database.dart';

const String trashFolderName = '.trash';
const String deletedAccountsTable = 'deleted_accounts';

String trashPath(String mediaDirectory) =>
    p.join(mediaDirectory, trashFolderName);

String stagingTrashPath(String mediaDirectory) =>
    p.join(mediaDirectory, stagingFolderName, trashFolderName);

Directory? _moveToTrash(
  Directory source,
  String trashRoot,
  String label,
  Rename rename,
) {
  if (!source.existsSync()) {
    return null;
  }
  try {
    Directory(trashRoot).createSync(recursive: true);
    final String target = p.join(trashRoot, label);
    rename(source.path, target);
    return Directory(target);
  } on FileSystemException {
    return source;
  }
}

List<Directory> trashAccountMedia(
  String mediaDirectory,
  String accountId,
  List<String> uploadIds,
  DateTime now, {
  Rename rename = renameOnDisk,
}) {
  final int millis = toMillis(now);
  final List<Directory?> moved = <Directory?>[
    _moveToTrash(
      Directory(accountMediaPath(mediaDirectory, accountId)),
      trashPath(mediaDirectory),
      '$accountId-$millis',
      rename,
    ),
    for (final String uploadId in uploadIds)
      _moveToTrash(
        Directory(stagingPath(mediaDirectory, uploadId)),
        stagingTrashPath(mediaDirectory),
        '$uploadId-$millis',
        rename,
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

final class LeftoverReport {
  const LeftoverReport({
    required this.trash,
    required this.uploadTrash,
    required this.assembling,
    required this.erasedAccounts,
    required this.deletedAccounts,
    required this.unownedUploads,
    required this.swept,
    required this.unswept,
  });

  final int trash;
  final int uploadTrash;
  final int assembling;
  final int erasedAccounts;
  final int deletedAccounts;
  final int unownedUploads;
  final bool swept;
  final int unswept;

  bool get worthLogging =>
      trash +
              uploadTrash +
              assembling +
              erasedAccounts +
              deletedAccounts +
              unownedUploads >
          0 ||
      unswept > 0;

  Map<String, Object> get fields => <String, Object>{
    'trash': trash,
    'upload_trash': uploadTrash,
    'assembling': assembling,
    'erased_accounts': erasedAccounts,
    'deleted_accounts': deletedAccounts,
    'unowned_uploads': unownedUploads,
    'swept': swept,
  };
}

Future<LeftoverReport> clearLeftovers(
  RelayDatabase database,
  String mediaDirectory,
) async {
  final int trash = await _clearFolder(Directory(trashPath(mediaDirectory)));
  final int uploadTrash = await _clearFolder(
    Directory(stagingTrashPath(mediaDirectory)),
  );
  final int assembling = await _clearFolder(
    Directory(assemblyPath(mediaDirectory)),
  );
  final List<Directory> accountFolders = <Directory>[
    for (final Directory directory in _children(mediaDirectory))
      if (isSyncId(p.basename(directory.path))) directory,
  ];
  final List<Directory> uploadFolders = <Directory>[
    for (final Directory directory in _children(
      p.join(mediaDirectory, stagingFolderName),
    ))
      if (isUploadId(p.basename(directory.path))) directory,
  ];
  if (database.count('SELECT count(*) FROM accounts') == 0) {
    return LeftoverReport(
      trash: trash,
      uploadTrash: uploadTrash,
      assembling: assembling,
      erasedAccounts: 0,
      deletedAccounts: 0,
      unownedUploads: 0,
      swept: false,
      unswept: accountFolders.length + uploadFolders.length,
    );
  }
  final Set<String> deleted = _deletedAccounts(database);
  final List<Directory> erasedFolders = <Directory>[];
  final List<Directory> deletedFolders = <Directory>[];
  for (final Directory directory in accountFolders) {
    final String accountId = p.basename(directory.path);
    final Row? account = database.selectOne(
      'SELECT status FROM accounts WHERE id = ?',
      <Object?>[accountId],
    );
    if (account?['status'] == AccountStatus.erased.storedName) {
      erasedFolders.add(directory);
    } else if (account == null && deleted.contains(accountId)) {
      deletedFolders.add(directory);
    }
  }
  final List<Directory> unownedFolders = <Directory>[
    for (final Directory directory in uploadFolders)
      if (database.count('SELECT count(*) FROM uploads WHERE id = ?', <Object?>[
            p.basename(directory.path),
          ]) ==
          0)
        directory,
  ];
  for (final Directory directory in <Directory>[
    ...erasedFolders,
    ...deletedFolders,
    ...unownedFolders,
  ]) {
    await deleteQuietly(directory);
  }
  return LeftoverReport(
    trash: trash,
    uploadTrash: uploadTrash,
    assembling: assembling,
    erasedAccounts: erasedFolders.length,
    deletedAccounts: deletedFolders.length,
    unownedUploads: unownedFolders.length,
    swept: true,
    unswept: 0,
  );
}

Set<String> _deletedAccounts(RelayDatabase database) {
  if (!database.hasTable(deletedAccountsTable)) {
    return const <String>{};
  }
  return <String>{
    for (final Row row in database.select(
      'SELECT id FROM $deletedAccountsTable',
    ))
      row['id'] as String,
  };
}

Future<int> _clearFolder(Directory folder) async {
  if (!folder.existsSync()) {
    return 0;
  }
  final int entries = folder.listSync(followLinks: false).length;
  await deleteQuietly(folder);
  return entries;
}

List<Directory> _children(String path) {
  final Directory parent = Directory(path);
  if (!parent.existsSync()) {
    return const <Directory>[];
  }
  return parent.listSync(followLinks: false).whereType<Directory>().toList();
}
