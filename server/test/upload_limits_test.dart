import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
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
}
