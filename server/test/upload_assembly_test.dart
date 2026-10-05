import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:relay_server/src/blobs.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

const int partSize = 1024;

typedef RenameCall = ({String source, String target, bool crossed});

Uint8List ciphertext(int length, int seed) => Uint8List.fromList(
  List<int>.generate(length, (int index) => (index * 31 + seed) % 256),
);

List<int> partOf(List<int> blob, int index) =>
    blob.sublist(index * partSize, min((index + 1) * partSize, blob.length));

UploadStatusResponse statusOf(http.Response response) =>
    UploadStatusResponse.fromJson(decodeJsonObject(response.body));

int rowsOf(RelayHarness harness, String table, String accountId) =>
    harness.database.count(
      'SELECT count(*) FROM $table WHERE account_id = ?',
      <Object?>[accountId],
    );

Future<http.Response> putPart(
  RelayHarness harness,
  SignedIn who, {
  required String name,
  required String uploadId,
  required List<int> blob,
  required int index,
}) => harness.putPart(
  who.session,
  name: name,
  uploadId: uploadId,
  index: index,
  blobSize: blob.length,
  partSize: partSize,
  bytes: partOf(blob, index),
);

void main() {
  test('assembly never renames across the staging subvolume', () async {
    final List<RenameCall> renames = <RenameCall>[];
    late final RelayHarness harness;
    bool staged(String path) =>
        p.isWithin(p.join(harness.mediaDirectory, stagingFolderName), path);
    harness = await RelayHarness.start(
      rename: (String source, String target) {
        final bool crossed = staged(source) != staged(target);
        renames.add((source: source, target: target, crossed: crossed));
        if (crossed) {
          throw FileSystemException(
            'Cross-device link',
            source,
            const OSError('Cross-device link', 18),
          );
        }
        renameOnDisk(source, target);
      },
    );
    addTearDown(harness.dispose);
    final TestAccount account = await harness.enrol();
    final SignedIn me = await harness.signIn(account.firstDevice);
    final String name = harness.blobName();
    final String uploadId = newSyncId();
    final Uint8List blob = ciphertext(partSize * 2 + 300, 21);

    final List<http.Response> answers = <http.Response>[
      for (int index = 0; index < 3; index++)
        await putPart(
          harness,
          me,
          name: name,
          uploadId: uploadId,
          blob: blob,
          index: index,
        ),
    ];

    for (final http.Response answer in answers) {
      expect(answer.statusCode, HttpStatus.ok);
    }
    expect(statusOf(answers.last).assembled, isTrue);
    final http.Response downloaded = await harness.send(
      SyncRoutes.downloadBlob,
      parameters: <String, Object>{SyncRoutes.nameParameter: name},
      credential: me.session,
    );
    expect(downloaded.statusCode, HttpStatus.ok);
    expect(downloaded.bodyBytes, blob);
    expect(Directory(assemblyPath(harness.mediaDirectory)).listSync(), isEmpty);
    expect(
      Directory(stagingPath(harness.mediaDirectory, uploadId)).existsSync(),
      isFalse,
    );
    expect(renames.where((RenameCall call) => call.crossed), isEmpty);
    expect(
      renames.where(
        (RenameCall call) =>
            call.target ==
            blobPath(harness.mediaDirectory, account.accountId, name),
      ),
      hasLength(1),
    );

    final String unfinished = newSyncId();
    final Uint8List partial = ciphertext(partSize * 2, 22);
    expect(
      (await putPart(
        harness,
        me,
        name: harness.blobName(),
        uploadId: unfinished,
        blob: partial,
        index: 0,
      )).statusCode,
      HttpStatus.ok,
    );
    renames.clear();

    final http.Response erased = await harness.send(
      SyncRoutes.eraseJournal,
      credential: me.session,
    );

    expect(erased.statusCode, HttpStatus.noContent);
    expect(
      renames.map((RenameCall call) => call.source),
      unorderedEquals(<String>[
        accountMediaPath(harness.mediaDirectory, account.accountId),
        stagingPath(harness.mediaDirectory, unfinished),
      ]),
    );
    expect(renames.where((RenameCall call) => call.crossed), isEmpty);
    expect(
      Directory(accountMediaPath(harness.mediaDirectory, account.accountId))
          .existsSync(),
      isFalse,
    );
    expect(
      Directory(stagingPath(harness.mediaDirectory, unfinished)).existsSync(),
      isFalse,
    );
  });

  test('an upload finishing during an erase leaves nothing behind', () async {
    late final RelayHarness harness;
    late final SignedIn me;
    final List<int> erasures = <int>[];
    harness = await RelayHarness.start(
      beforeAssembly: (String uploadId) async {
        final http.Response erased = await harness.send(
          SyncRoutes.eraseJournal,
          credential: me.session,
        );
        erasures.add(erased.statusCode);
      },
    );
    addTearDown(harness.dispose);
    final TestAccount account = await harness.enrol();
    me = await harness.signIn(account.firstDevice);
    final String name = harness.blobName();
    final String uploadId = newSyncId();
    final Uint8List blob = ciphertext(partSize + 500, 23);
    expect(
      (await putPart(
        harness,
        me,
        name: name,
        uploadId: uploadId,
        blob: blob,
        index: 0,
      )).statusCode,
      HttpStatus.ok,
    );

    final http.Response last = await putPart(
      harness,
      me,
      name: name,
      uploadId: uploadId,
      blob: blob,
      index: 1,
    );

    expect(erasures, <int>[HttpStatus.noContent]);
    expect(last.statusCode, SyncErrorCode.journalErased.httpStatus);
    expect(errorOf(last).code, SyncErrorCode.journalErased);
    expect(
      Directory(accountMediaPath(harness.mediaDirectory, account.accountId))
          .existsSync(),
      isFalse,
    );
    expect(rowsOf(harness, 'blobs', account.accountId), 0);
    expect(rowsOf(harness, 'uploads', account.accountId), 0);
    expect(
      Directory(stagingPath(harness.mediaDirectory, uploadId)).existsSync(),
      isFalse,
    );
    expect(Directory(assemblyPath(harness.mediaDirectory)).listSync(), isEmpty);

    await harness.restart();

    expect(
      Directory(accountMediaPath(harness.mediaDirectory, account.accountId))
          .existsSync(),
      isFalse,
    );
    expect(Directory(assemblyPath(harness.mediaDirectory)).listSync(), isEmpty);
  });
}
