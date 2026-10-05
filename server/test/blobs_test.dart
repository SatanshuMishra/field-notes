import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:relay_server/src/blobs.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

const int partSize = 1024;

Uint8List ciphertext(int length, int seed) => Uint8List.fromList(
  List<int>.generate(length, (int index) => (index * 31 + seed) % 256),
);

List<int> partOf(List<int> blob, int index) {
  final int start = index * partSize;
  final int end = start + partSize > blob.length
      ? blob.length
      : start + partSize;
  return blob.sublist(start, end);
}

UploadStatusResponse statusOf(http.Response response) =>
    UploadStatusResponse.fromJson(decodeJsonObject(response.body));

Future<RelayHarness> startHarness({AssemblyHook? beforeAssembly}) async {
  final RelayHarness harness = await RelayHarness.start(
    beforeAssembly: beforeAssembly,
  );
  addTearDown(harness.dispose);
  return harness;
}

Future<SignedIn> signedInto(
  RelayHarness harness, [
  String note = 'Journal',
]) async {
  final TestAccount account = await harness.enrol(note: note);
  return harness.signIn(account.firstDevice);
}

Future<http.Response> put(
  RelayHarness harness,
  SignedIn who, {
  required String name,
  required String uploadId,
  required List<int> blob,
  required int index,
  List<int>? bytes,
}) => harness.putPart(
  who.session,
  name: name,
  uploadId: uploadId,
  index: index,
  blobSize: blob.length,
  partSize: partSize,
  bytes: bytes ?? partOf(blob, index),
);

Future<http.Response> uploadStatus(
  RelayHarness harness,
  SignedIn who,
  String name,
  String uploadId,
) => harness.send(
  SyncRoutes.uploadStatus,
  parameters: <String, Object>{
    SyncRoutes.nameParameter: name,
    SyncRoutes.uploadIdParameter: uploadId,
  },
  credential: who.session,
);

Future<http.Response> head(RelayHarness harness, SignedIn who, String name) =>
    harness.send(
      SyncRoutes.blobExists,
      parameters: <String, Object>{SyncRoutes.nameParameter: name},
      credential: who.session,
    );

Future<http.Response> download(
  RelayHarness harness,
  SignedIn who,
  String name,
) => harness.send(
  SyncRoutes.downloadBlob,
  parameters: <String, Object>{SyncRoutes.nameParameter: name},
  credential: who.session,
);

Future<http.Response> report(
  RelayHarness harness,
  SignedIn who,
  SyncRoute route,
  List<String> names,
) => harness.send(
  route,
  credential: who.session,
  body: BlobNamesRequest(names: names),
);

void main() {
  test("another account's blob cannot be read", () async {
    final RelayHarness harness = await startHarness();
    final SignedIn owner = await signedInto(harness, 'Owner');
    final SignedIn stranger = await signedInto(harness, 'Stranger');
    final String name = harness.blobName();
    final Uint8List blob = ciphertext(3000, 1);
    await harness.uploadBlob(owner.session, name, blob);
    expect((await head(harness, owner, name)).statusCode, HttpStatus.ok);
    expect((await download(harness, owner, name)).bodyBytes, blob);

    final http.Response strangerHead = await head(harness, stranger, name);
    final http.Response strangerGet = await download(harness, stranger, name);

    expect(strangerHead.statusCode, HttpStatus.notFound);
    expect(strangerHead.bodyBytes, isEmpty);
    expect(strangerGet.statusCode, HttpStatus.notFound);
    expect(errorOf(strangerGet).code, SyncErrorCode.notFound);
    expect(strangerGet.bodyBytes.length, lessThan(blob.length));
  });

  test('an interrupted upload resumes from the first missing part', () async {
    final RelayHarness harness = await startHarness();
    final SignedIn me = await signedInto(harness);
    final String name = harness.blobName();
    final String uploadId = newSyncId();
    final Uint8List blob = ciphertext(partSize * 3 + 500, 2);
    for (final int index in <int>[0, 1]) {
      final http.Response sent = await put(
        harness,
        me,
        name: name,
        uploadId: uploadId,
        blob: blob,
        index: index,
      );
      expect(sent.statusCode, HttpStatus.ok);
      expect(statusOf(sent).assembled, isFalse);
    }

    final UploadStatusResponse halfway = statusOf(
      await uploadStatus(harness, me, name, uploadId),
    );

    expect(halfway.receivedParts, <int>[0, 1]);
    expect(halfway.assembled, isFalse);
    expect((await head(harness, me, name)).statusCode, HttpStatus.notFound);

    final http.Response third = await put(
      harness,
      me,
      name: name,
      uploadId: uploadId,
      blob: blob,
      index: 2,
    );
    final http.Response fourth = await put(
      harness,
      me,
      name: name,
      uploadId: uploadId,
      blob: blob,
      index: 3,
    );

    expect(statusOf(third).receivedParts, <int>[0, 1, 2]);
    expect(statusOf(third).assembled, isFalse);
    expect(statusOf(fourth).assembled, isTrue);
    expect((await download(harness, me, name)).bodyBytes, blob);
    expect(
      Directory(stagingPath(harness.mediaDirectory, uploadId)).existsSync(),
      isFalse,
    );
  });

  test('an existing blob name is reported so the upload is skipped', () async {
    final RelayHarness harness = await startHarness();
    final SignedIn me = await signedInto(harness);
    final String held = harness.blobName();
    await harness.uploadBlob(me.session, held, ciphertext(100, 3));

    final http.Response present = await head(harness, me, held);
    final http.Response absent = await head(harness, me, harness.blobName());
    final http.Response malformed = await head(harness, me, 'not-a-name');

    expect(present.statusCode, HttpStatus.ok);
    expect(absent.statusCode, HttpStatus.notFound);
    expect(malformed.statusCode, HttpStatus.badRequest);
  });

  test('a part for a blob already held is answered as assembled', () async {
    final RelayHarness harness = await startHarness();
    final SignedIn me = await signedInto(harness);
    final String name = harness.blobName();
    final Uint8List blob = ciphertext(partSize * 2, 4);
    await harness.uploadBlob(me.session, name, blob);
    final String again = newSyncId();

    final http.Response response = await put(
      harness,
      me,
      name: name,
      uploadId: again,
      blob: blob,
      index: 0,
    );

    expect(response.statusCode, HttpStatus.ok);
    expect(
      statusOf(response),
      UploadStatusResponse(receivedParts: const <int>[], assembled: true),
    );
    expect(
      harness.database.count(
        'SELECT count(*) FROM uploads WHERE id = ?',
        <Object?>[again],
      ),
      0,
    );
    expect(
      harness.database.count(
        'SELECT count(*) FROM upload_parts WHERE upload_id = ?',
        <Object?>[again],
      ),
      0,
    );
    expect(
      Directory(stagingPath(harness.mediaDirectory, again)).existsSync(),
      isFalse,
    );
    expect((await download(harness, me, name)).bodyBytes, blob);
  });

  test('an unknown upload id reads as empty', () async {
    final RelayHarness harness = await startHarness();
    final SignedIn me = await signedInto(harness);
    final String held = harness.blobName();
    await harness.uploadBlob(me.session, held, ciphertext(200, 5));

    final http.Response unknown = await uploadStatus(
      harness,
      me,
      harness.blobName(),
      newSyncId(),
    );
    final http.Response unknownForHeld = await uploadStatus(
      harness,
      me,
      held,
      newSyncId(),
    );
    final http.Response malformed = await uploadStatus(
      harness,
      me,
      held,
      'short',
    );

    expect(unknown.statusCode, HttpStatus.ok);
    expect(
      statusOf(unknown),
      UploadStatusResponse(receivedParts: const <int>[], assembled: false),
    );
    expect(unknownForHeld.statusCode, HttpStatus.ok);
    expect(
      statusOf(unknownForHeld),
      UploadStatusResponse(receivedParts: const <int>[], assembled: true),
    );
    expect(malformed.statusCode, HttpStatus.badRequest);
  });

  test('a blob unused for thirty days is purged', () async {
    final RelayHarness harness = await startHarness();
    final SignedIn me = await signedInto(harness);
    final String unused = harness.blobName();
    final String kept = harness.blobName();
    await harness.uploadBlob(me.session, unused, ciphertext(300, 6));
    await harness.uploadBlob(me.session, kept, ciphertext(300, 7));
    final String accountId =
        harness.database.selectOne(
              'SELECT account_id FROM blobs WHERE name = ?',
              <Object?>[unused],
            )!['account_id']
            as String;
    final File file = File(blobPath(harness.mediaDirectory, accountId, unused));
    expect(file.existsSync(), isTrue);

    final http.Response reported = await report(
      harness,
      me,
      SyncRoutes.reportUnusedBlobs,
      <String>[unused],
    );
    expect(reported.statusCode, HttpStatus.noContent);
    harness.advance(const Duration(days: 29));
    await harness.tick();
    final SignedIn later = await harness.signIn(me.device);
    expect((await head(harness, later, unused)).statusCode, HttpStatus.ok);
    harness.advance(const Duration(days: 1));
    await harness.tick();
    final SignedIn last = await harness.signIn(me.device);

    expect((await head(harness, last, unused)).statusCode, HttpStatus.notFound);
    expect(file.existsSync(), isFalse);
    expect(
      harness.database.count(
        'SELECT count(*) FROM blobs WHERE name = ?',
        <Object?>[unused],
      ),
      0,
    );
    expect((await head(harness, last, kept)).statusCode, HttpStatus.ok);
  });

  test('a blob referenced again within thirty days is kept', () async {
    final RelayHarness harness = await startHarness();
    final SignedIn me = await signedInto(harness);
    final String name = harness.blobName();
    final Uint8List blob = ciphertext(400, 8);
    await harness.uploadBlob(me.session, name, blob);
    await report(harness, me, SyncRoutes.reportUnusedBlobs, <String>[name]);
    harness.advance(const Duration(days: 29));
    final SignedIn later = await harness.signIn(me.device);

    final http.Response referenced = await report(
      harness,
      later,
      SyncRoutes.reportReferencedBlobs,
      <String>[name],
    );
    harness.advance(const Duration(days: 2));
    await harness.tick();
    final SignedIn last = await harness.signIn(me.device);

    expect(referenced.statusCode, HttpStatus.ok);
    expect(
      BlobNamesResponse.fromJson(decodeJsonObject(referenced.body)).names,
      isEmpty,
    );
    expect((await head(harness, last, name)).statusCode, HttpStatus.ok);
    expect((await download(harness, last, name)).bodyBytes, blob);
    final Row row = harness.database.selectOne(
      'SELECT unused_since FROM blobs WHERE name = ?',
      <Object?>[name],
    )!;
    expect(row['unused_since'], isNull);
  });

  test('a referenced report lists the blobs the relay lacks', () async {
    final RelayHarness harness = await startHarness();
    final SignedIn owner = await signedInto(harness, 'Owner');
    final SignedIn stranger = await signedInto(harness, 'Stranger');
    final String first = harness.blobName();
    final String second = harness.blobName();
    final String strangers = harness.blobName();
    final String missing = harness.blobName();
    await harness.uploadBlob(owner.session, first, ciphertext(10, 9));
    await harness.uploadBlob(owner.session, second, ciphertext(20, 10));
    await harness.uploadBlob(stranger.session, strangers, ciphertext(30, 11));

    final http.Response answered = await report(
      harness,
      owner,
      SyncRoutes.reportReferencedBlobs,
      <String>[first, missing, second, strangers],
    );
    final http.Response malformed = await report(
      harness,
      owner,
      SyncRoutes.reportReferencedBlobs,
      <String>['not-a-name'],
    );

    expect(answered.statusCode, HttpStatus.ok);
    expect(
      BlobNamesResponse.fromJson(decodeJsonObject(answered.body)).names,
      unorderedEquals(<String>[missing, strangers]),
    );
    expect(malformed.statusCode, HttpStatus.badRequest);
  });

  test('the last part assembles the blob without a finishing call', () async {
    final RelayHarness harness = await startHarness();
    final SignedIn me = await signedInto(harness);
    final String name = harness.blobName();
    final String uploadId = newSyncId();
    final Uint8List blob = ciphertext(partSize * 2 + 10, 12);
    final List<UploadStatusResponse> answers = <UploadStatusResponse>[];

    for (final int index in <int>[2, 0, 1]) {
      final http.Response response = await put(
        harness,
        me,
        name: name,
        uploadId: uploadId,
        blob: blob,
        index: index,
      );
      expect(response.statusCode, HttpStatus.ok);
      answers.add(statusOf(response));
    }

    expect(
      answers.map((UploadStatusResponse answer) => answer.assembled),
      <bool>[false, false, true],
    );
    expect(answers[1].receivedParts, <int>[0, 2]);
    expect((await download(harness, me, name)).bodyBytes, blob);
    final Row upload = harness.database.selectOne(
      'SELECT assembled, assembling FROM uploads WHERE id = ?',
      <Object?>[uploadId],
    )!;
    expect(upload['assembled'], 1);
    expect(upload['assembling'], 0);
    expect(
      harness.database.selectOne(
        'SELECT size FROM blobs WHERE name = ?',
        <Object?>[name],
      )!['size'],
      blob.length,
    );
  });

  test('a part of the wrong length is refused', () async {
    final RelayHarness harness = await startHarness();
    final SignedIn me = await signedInto(harness);
    final String name = harness.blobName();
    final String uploadId = newSyncId();
    final Uint8List blob = ciphertext(partSize * 2 + 300, 13);
    expect(
      (await put(
        harness,
        me,
        name: name,
        uploadId: uploadId,
        blob: blob,
        index: 0,
      )).statusCode,
      HttpStatus.ok,
    );
    final List<int> middle = partOf(blob, 1);
    final List<int> last = partOf(blob, 2);

    final List<http.Response> refused = <http.Response>[
      await put(
        harness,
        me,
        name: name,
        uploadId: uploadId,
        blob: blob,
        index: 1,
        bytes: middle.sublist(0, partSize - 1),
      ),
      await put(
        harness,
        me,
        name: name,
        uploadId: uploadId,
        blob: blob,
        index: 1,
        bytes: <int>[...middle, 0],
      ),
      await put(
        harness,
        me,
        name: name,
        uploadId: uploadId,
        blob: blob,
        index: 2,
        bytes: last.sublist(1),
      ),
      await put(
        harness,
        me,
        name: name,
        uploadId: uploadId,
        blob: blob,
        index: 2,
        bytes: <int>[...last, 0],
      ),
      await harness.putPart(
        me.session,
        name: name,
        uploadId: newSyncId(),
        index: 0,
        blobSize: maxPartSize * 2,
        partSize: maxPartSize + 1,
        bytes: const <int>[1, 2, 3],
      ),
    ];
    final http.StreamedRequest chunked =
        http.StreamedRequest(
            'PUT',
            harness.uri(
              SyncRoutes.uploadPart,
              parameters: <String, Object>{
                SyncRoutes.nameParameter: name,
                SyncRoutes.uploadIdParameter: uploadId,
                SyncRoutes.indexParameter: 1,
              },
            ),
          )
          ..headers.addAll(<String, String>{
            SyncHeaders.protocol: '$syncProtocolVersion',
            SyncHeaders.authorization: me.session.authorization,
            SyncHeaders.blobSize: '${blob.length}',
            SyncHeaders.partSize: '$partSize',
          });
    chunked.sink
      ..add(middle.sublist(0, 512))
      ..add(<int>[...middle.sublist(512), 7, 7])
      ..close();
    refused.add(
      await http.Response.fromStream(await harness.client.send(chunked)),
    );

    for (final http.Response response in refused) {
      expect(response.statusCode, HttpStatus.badRequest);
      expect(errorOf(response).code, SyncErrorCode.badRequest);
    }
    final UploadStatusResponse kept = statusOf(
      await uploadStatus(harness, me, name, uploadId),
    );
    expect(kept.receivedParts, <int>[0]);
    expect(kept.assembled, isFalse);
    expect(
      Directory(stagingPath(harness.mediaDirectory, uploadId))
          .listSync()
          .map((FileSystemEntity entity) => p.basename(entity.path)),
      <String>['0'],
    );

    for (final int index in <int>[1, 2]) {
      await put(
        harness,
        me,
        name: name,
        uploadId: uploadId,
        blob: blob,
        index: index,
      );
    }
    expect((await download(harness, me, name)).bodyBytes, blob);
  });

  test('a failed assembly is retried', () async {
    int failures = 1;
    int attempts = 0;
    final RelayHarness harness = await startHarness(
      beforeAssembly: (String uploadId) async {
        attempts++;
        if (failures > 0) {
          failures--;
          throw const FileSystemException(
            'No space left on device',
            '',
            OSError('No space left on device', 28),
          );
        }
      },
    );
    final SignedIn me = await signedInto(harness);
    final String name = harness.blobName();
    final String uploadId = newSyncId();
    final Uint8List blob = ciphertext(partSize + 100, 14);
    await put(
      harness,
      me,
      name: name,
      uploadId: uploadId,
      blob: blob,
      index: 0,
    );

    final http.Response full = await put(
      harness,
      me,
      name: name,
      uploadId: uploadId,
      blob: blob,
      index: 1,
    );

    expect(full.statusCode, SyncErrorCode.storageFull.httpStatus);
    expect(errorOf(full).code, SyncErrorCode.storageFull);
    final Row failed = harness.database.selectOne(
      'SELECT assembling, assembled FROM uploads WHERE id = ?',
      <Object?>[uploadId],
    )!;
    expect(failed['assembling'], 0);
    expect(failed['assembled'], 0);
    expect(
      harness.database.count(
        'SELECT count(*) FROM upload_parts WHERE upload_id = ?',
        <Object?>[uploadId],
      ),
      2,
    );
    expect((await head(harness, me, name)).statusCode, HttpStatus.notFound);
    expect(attempts, 1);

    final UploadStatusResponse retried = statusOf(
      await uploadStatus(harness, me, name, uploadId),
    );

    expect(retried.assembled, isTrue);
    expect(attempts, 2);
    expect((await download(harness, me, name)).bodyBytes, blob);

    failures = 1;
    final String stuckName = harness.blobName();
    final String stuckUpload = newSyncId();
    final Uint8List stuckBlob = ciphertext(partSize + 50, 15);
    await put(
      harness,
      me,
      name: stuckName,
      uploadId: stuckUpload,
      blob: stuckBlob,
      index: 0,
    );
    expect(
      (await put(
        harness,
        me,
        name: stuckName,
        uploadId: stuckUpload,
        blob: stuckBlob,
        index: 1,
      )).statusCode,
      SyncErrorCode.storageFull.httpStatus,
    );
    final http.Response resent = await put(
      harness,
      me,
      name: stuckName,
      uploadId: stuckUpload,
      blob: stuckBlob,
      index: 0,
    );
    expect(statusOf(resent).assembled, isTrue);
    expect((await download(harness, me, stuckName)).bodyBytes, stuckBlob);

    final String crashName = harness.blobName();
    final String crashUpload = newSyncId();
    final Uint8List crashBlob = ciphertext(partSize + 60, 16);
    failures = 1;
    await put(
      harness,
      me,
      name: crashName,
      uploadId: crashUpload,
      blob: crashBlob,
      index: 0,
    );
    await put(
      harness,
      me,
      name: crashName,
      uploadId: crashUpload,
      blob: crashBlob,
      index: 1,
    );
    harness.database.execute(
      'UPDATE uploads SET assembling = 1 WHERE id = ?',
      <Object?>[crashUpload],
    );
    expect(
      statusOf(await uploadStatus(harness, me, crashName, crashUpload))
          .assembled,
      isFalse,
    );

    await harness.restart();

    expect(
      harness.database.selectOne(
        'SELECT assembling FROM uploads WHERE id = ?',
        <Object?>[crashUpload],
      )!['assembling'],
      0,
    );
    final SignedIn again = await harness.signIn(me.device);
    expect(
      statusOf(await uploadStatus(harness, again, crashName, crashUpload))
          .assembled,
      isTrue,
    );
    expect((await download(harness, again, crashName)).bodyBytes, crashBlob);
  });

  test('every part of one upload sent at once assembles once', () async {
    late final RelayHarness harness;
    final List<int> partsAtAssembly = <int>[];
    harness = await startHarness(
      beforeAssembly: (String uploadId) async {
        partsAtAssembly.add(
          harness.database.count(
            'SELECT count(*) FROM upload_parts WHERE upload_id = ?',
            <Object?>[uploadId],
          ),
        );
      },
    );
    final SignedIn me = await signedInto(harness);
    final String name = harness.blobName();
    final String uploadId = newSyncId();
    final Uint8List blob = ciphertext(partSize * 5 + 77, 17);

    final List<http.Response> responses = await Future.wait(
      <Future<http.Response>>[
        for (int index = 0; index < 6; index++)
          put(
            harness,
            me,
            name: name,
            uploadId: uploadId,
            blob: blob,
            index: index,
          ),
      ],
    );

    for (final http.Response response in responses) {
      expect(response.statusCode, HttpStatus.ok);
    }
    expect(partsAtAssembly, <int>[6]);
    expect(
      responses.where((http.Response response) => statusOf(response).assembled),
      isNotEmpty,
    );
    expect(
      statusOf(await uploadStatus(harness, me, name, uploadId)).assembled,
      isTrue,
    );
    expect((await download(harness, me, name)).bodyBytes, blob);
    expect(
      harness.database.count(
        'SELECT count(*) FROM blobs WHERE name = ?',
        <Object?>[name],
      ),
      1,
    );
  });

  test('a part sent again during assembly leaves the blob intact', () async {
    final Completer<void> entered = Completer<void>();
    final Completer<void> release = Completer<void>();
    final RelayHarness harness = await startHarness(
      beforeAssembly: (String uploadId) async {
        if (!entered.isCompleted) {
          entered.complete();
        }
        await release.future;
      },
    );
    final SignedIn me = await signedInto(harness);
    final String name = harness.blobName();
    final String uploadId = newSyncId();
    final Uint8List blob = ciphertext(partSize * 2 + 200, 18);
    for (final int index in <int>[0, 1]) {
      await put(
        harness,
        me,
        name: name,
        uploadId: uploadId,
        blob: blob,
        index: index,
      );
    }
    final Future<http.Response> last = put(
      harness,
      me,
      name: name,
      uploadId: uploadId,
      blob: blob,
      index: 2,
    );
    await entered.future;

    final http.Response again = await put(
      harness,
      me,
      name: name,
      uploadId: uploadId,
      blob: blob,
      index: 0,
      bytes: List<int>.filled(partSize, 0xAB),
    );

    expect(again.statusCode, HttpStatus.ok);
    expect(statusOf(again).assembled, isFalse);
    final Directory staging = Directory(
      stagingPath(harness.mediaDirectory, uploadId),
    );
    expect(File(p.join(staging.path, '0')).readAsBytesSync(), partOf(blob, 0));
    expect(
      staging
          .listSync()
          .map((FileSystemEntity entity) => p.basename(entity.path))
          .where((String name) => name.startsWith('.part-')),
      isEmpty,
    );

    release.complete();
    final http.Response finished = await last;

    expect(statusOf(finished).assembled, isTrue);
    expect((await download(harness, me, name)).bodyBytes, blob);
  });
}
