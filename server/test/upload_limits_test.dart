import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:relay_server/src/blobs.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

const int mebibyte = 1024 * 1024;
const int gibibyte = 1024 * mebibyte;

void main() {
  late RelayHarness harness;
  late TestAccount account;
  late SignedIn me;

  setUp(() async {
    harness = await RelayHarness.start();
    account = await harness.enrol();
    me = await harness.signIn(account.firstDevice);
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<http.Response> sendPart(
    SignedIn who, {
    required String uploadId,
    required int index,
    required int blobSize,
    required int partSize,
    required int length,
    String? name,
  }) => harness.putPart(
    who.session,
    name: name ?? harness.blobName(),
    uploadId: uploadId,
    index: index,
    blobSize: blobSize,
    partSize: partSize,
    bytes: Uint8List(length),
  );

  void expectRefused(http.Response response, SyncErrorCode code, String what) {
    expect(response.statusCode, code.httpStatus, reason: what);
    expect(errorOf(response).code, code, reason: what);
  }

  UploadStatusResponse statusOf(http.Response response) =>
      UploadStatusResponse.fromJson(decodeJsonObject(response.body));

  int uploads() => harness.database.count('SELECT count(*) FROM uploads');

  test('a part outside the upload size limits is refused', () async {
    expectRefused(
      await sendPart(
        me,
        uploadId: newSyncId(),
        index: 0,
        blobSize: 10,
        partSize: 8 * mebibyte + 1,
        length: 10,
      ),
      SyncErrorCode.badRequest,
      'a part size above 8 MiB',
    );
    expectRefused(
      await sendPart(
        me,
        uploadId: newSyncId(),
        index: 128,
        blobSize: 2 * gibibyte + 1,
        partSize: 16 * mebibyte,
        length: 1,
      ),
      SyncErrorCode.badRequest,
      'a blob above 2 GiB',
    );
    expectRefused(
      await sendPart(
        me,
        uploadId: newSyncId(),
        index: 0,
        blobSize: 257 * 1024,
        partSize: 1024,
        length: 1024,
      ),
      SyncErrorCode.badRequest,
      'a blob of 257 parts',
    );
    expect(uploads(), 0);

    final http.Response lastOf256 = await sendPart(
      me,
      uploadId: newSyncId(),
      index: 255,
      blobSize: 256 * 1024,
      partSize: 1024,
      length: 1024,
    );
    expect(lastOf256.statusCode, HttpStatus.ok);
    expect(statusOf(lastOf256).receivedParts, <int>[255]);
    final http.Response fullPartSize = await sendPart(
      me,
      uploadId: newSyncId(),
      index: 0,
      blobSize: 10,
      partSize: 8 * mebibyte,
      length: 10,
    );
    expect(fullPartSize.statusCode, HttpStatus.ok);
    expect(statusOf(fullPartSize).assembled, isTrue);
  });

  test('an account keeps at most 32 unfinished uploads', () async {
    final List<({String uploadId, String name})> started =
        <({String uploadId, String name})>[];
    for (int index = 0; index < 32; index++) {
      final ({String uploadId, String name}) upload = (
        uploadId: newSyncId(),
        name: harness.blobName(),
      );
      started.add(upload);
      final http.Response response = await sendPart(
        me,
        uploadId: upload.uploadId,
        name: upload.name,
        index: 0,
        blobSize: 2048,
        partSize: 1024,
        length: 1024,
      );
      expect(response.statusCode, HttpStatus.ok, reason: 'upload $index');
    }

    expectRefused(
      await sendPart(
        me,
        uploadId: newSyncId(),
        index: 0,
        blobSize: 2048,
        partSize: 1024,
        length: 1024,
      ),
      SyncErrorCode.storageFull,
      'a 33rd unfinished upload',
    );
    expect(uploads(), 32);

    final TestAccount other = await harness.enrol(note: 'Other journal');
    final SignedIn otherIn = await harness.signIn(other.firstDevice);
    expect(
      (await sendPart(
        otherIn,
        uploadId: newSyncId(),
        index: 0,
        blobSize: 2048,
        partSize: 1024,
        length: 1024,
      )).statusCode,
      HttpStatus.ok,
    );

    final http.Response finished = await sendPart(
      me,
      uploadId: started.first.uploadId,
      name: started.first.name,
      index: 1,
      blobSize: 2048,
      partSize: 1024,
      length: 1024,
    );
    expect(statusOf(finished).assembled, isTrue);
    expect(
      (await sendPart(
        me,
        uploadId: newSyncId(),
        index: 0,
        blobSize: 2048,
        partSize: 1024,
        length: 1024,
      )).statusCode,
      HttpStatus.ok,
    );
  });

  test('an account stages at most 4 GiB of parts', () async {
    void stage(int totalBytes) {
      final String uploadId = newSyncId();
      const int partSize = 8 * mebibyte;
      harness.database.execute(
        'INSERT INTO uploads (id, account_id, name, total_bytes, part_size, '
        'created_at, assembling, assembled) VALUES (?, ?, ?, ?, ?, ?, 0, 0)',
        <Object?>[
          uploadId,
          account.accountId,
          harness.blobName(),
          totalBytes,
          partSize,
          harness.now.millisecondsSinceEpoch,
        ],
      );
      for (int index = 0; index * partSize < totalBytes; index++) {
        harness.database.execute(
          'INSERT INTO upload_parts (upload_id, part_index) VALUES (?, ?)',
          <Object?>[uploadId, index],
        );
      }
    }

    stage(2 * gibibyte);
    stage(2 * gibibyte - 1000);

    final http.Response fits = await sendPart(
      me,
      uploadId: newSyncId(),
      index: 0,
      blobSize: 1000,
      partSize: 1024,
      length: 1000,
    );
    expect(fits.statusCode, HttpStatus.ok);
    expect(statusOf(fits).assembled, isTrue);

    expectRefused(
      await sendPart(
        me,
        uploadId: newSyncId(),
        index: 0,
        blobSize: 1001,
        partSize: 1024,
        length: 1001,
      ),
      SyncErrorCode.storageFull,
      'a part past 4 GiB of staged parts',
    );

    final TestAccount other = await harness.enrol(note: 'Other journal');
    final SignedIn otherIn = await harness.signIn(other.firstDevice);
    expect(
      (await sendPart(
        otherIn,
        uploadId: newSyncId(),
        index: 0,
        blobSize: 1001,
        partSize: 1024,
        length: 1001,
      )).statusCode,
      HttpStatus.ok,
    );
  });

  test('concurrent parts cannot overrun the free-space floor', () async {
    const int floor = 1000000;
    const int partLength = 1024;
    final RelayHarness tight = await RelayHarness.start(minFreeBytes: floor);
    addTearDown(tight.dispose);
    final TestAccount owner = await tight.enrol();
    final SignedIn signedIn = await tight.signIn(owner.firstDevice);
    tight.freeBytes = floor + 2 * partLength + partLength ~/ 2;

    final List<http.Response> answers = await Future.wait(
      <Future<http.Response>>[
        for (int index = 0; index < 3; index++)
          tight.putPart(
            signedIn.session,
            name: tight.blobName(),
            uploadId: newSyncId(),
            index: 0,
            blobSize: 2 * partLength,
            partSize: partLength,
            bytes: Uint8List(partLength),
          ),
      ],
    );

    expect(
      answers.where(
        (http.Response answer) => answer.statusCode == HttpStatus.ok,
      ),
      hasLength(2),
    );
    final List<http.Response> refused = <http.Response>[
      for (final http.Response answer in answers)
        if (answer.statusCode != HttpStatus.ok) answer,
    ];
    expect(refused, hasLength(1));
    expectRefused(refused.single, SyncErrorCode.storageFull, 'a third part');
    expect(tight.database.count('SELECT count(*) FROM upload_parts'), 2);
  });

  test('assembly needs room for the whole blob', () async {
    const int floor = 1000000;
    const int partLength = 1024;
    final RelayHarness tight = await RelayHarness.start(minFreeBytes: floor);
    addTearDown(tight.dispose);
    final TestAccount owner = await tight.enrol();
    final SignedIn signedIn = await tight.signIn(owner.firstDevice);
    final Uint8List blob = Uint8List.fromList(
      List<int>.generate(3 * partLength, (int index) => index % 251),
    );
    final String name = tight.blobName();
    final String uploadId = newSyncId();
    Future<http.Response> sendPart(int index) => tight.putPart(
      signedIn.session,
      name: name,
      uploadId: uploadId,
      index: index,
      blobSize: blob.length,
      partSize: partLength,
      bytes: blob.sublist(index * partLength, (index + 1) * partLength),
    );
    int stagedParts() => tight.database.count(
      'SELECT count(*) FROM upload_parts WHERE upload_id = ?',
      <Object?>[uploadId],
    );
    Future<http.Response> askStatus() => tight.send(
      SyncRoutes.uploadStatus,
      parameters: <String, Object>{
        SyncRoutes.nameParameter: name,
        SyncRoutes.uploadIdParameter: uploadId,
      },
      credential: signedIn.session,
    );
    expect((await sendPart(0)).statusCode, HttpStatus.ok);
    expect((await sendPart(1)).statusCode, HttpStatus.ok);
    tight.freeBytes = floor + partLength + 100;
    tight.advance(const Duration(seconds: 5));

    final http.Response last = await sendPart(2);

    expectRefused(last, SyncErrorCode.storageFull, 'a blob without room');
    expect(stagedParts(), 3);
    for (int index = 0; index < 3; index++) {
      expect(
        File(p.join(stagingPath(tight.mediaDirectory, uploadId), '$index'))
            .lengthSync(),
        partLength,
      );
    }
    expect(
      tight.database.count(
        'SELECT count(*) FROM blobs WHERE name = ?',
        <Object?>[name],
      ),
      0,
    );
    expectRefused(
      await askStatus(),
      SyncErrorCode.storageFull,
      'a status request while there is still no room',
    );
    expect(stagedParts(), 3);

    tight.freeBytes = floor + 10 * blob.length;
    tight.advance(const Duration(seconds: 5));
    final http.Response status = await askStatus();

    expect(status.statusCode, HttpStatus.ok);
    expect(statusOf(status).assembled, isTrue);
    expect(stagedParts(), 0);
    final http.Response downloaded = await tight.send(
      SyncRoutes.downloadBlob,
      parameters: <String, Object>{SyncRoutes.nameParameter: name},
      credential: signedIn.session,
    );
    expect(downloaded.bodyBytes, blob);
  });
}
