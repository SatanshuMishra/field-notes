import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 29 + seed) % 251);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late RelayFixture relay;
  late SyncTestDevice mac;

  setUp(() async {
    relay = await RelayFixture.start(rateBurst: 1000);
    mac = await enrolDevice(relay, SyncTestDevice('Mac'));
  });

  tearDown(() async {
    await mac.dispose();
    await relay.dispose();
  });

  test('media downloads run at most four at once', () async {
    final SyncTestMedia media = await SyncTestMedia.create(mac);
    final List<domain.MediaBlob> blobs = <domain.MediaBlob>[];
    for (int seed = 0; seed < 6; seed++) {
      final domain.MediaBlob blob = await media.store.putBytes(
        bytes: _bytes(400, seed),
        mime: 'image/jpeg',
        kind: domain.MediaKind.photo,
      );
      await File(media.store.absolutePath(blob)).delete();
      blobs.add(blob);
    }
    final KeyedNames names = KeyedNames(await mac.journalKeys());
    final Map<String, String> blobOfName = <String, String>{
      for (final domain.MediaBlob blob in blobs)
        names.blobName(blob.id): blob.id,
    };
    final RelayClient client = mac.relayClient(
      relay.baseUrl,
      await mac.deviceKeys(),
      (SessionResponse _) {},
    );
    await client.signIn();
    final List<String> started = <String>[];
    final List<Completer<http.StreamedResponse>> held =
        <Completer<http.StreamedResponse>>[];
    int inFlight = 0;
    int most = 0;
    mac.http.intercept = (http.BaseRequest request) async {
      final String? blobId = blobOfName[request.url.pathSegments.last];
      if (request.method != 'GET' || blobId == null) {
        return null;
      }
      started.add(blobId);
      inFlight += 1;
      most = max(most, inFlight);
      final Completer<http.StreamedResponse> answer =
          Completer<http.StreamedResponse>();
      held.add(answer);
      return answer.future;
    };
    int finished = 0;

    final List<Future<bool>> downloads = <Future<bool>>[
      for (final domain.MediaBlob blob in blobs)
        media.downloads.download(client, blob.id),
    ];
    for (final Future<bool> download in downloads) {
      unawaited(download.whenComplete(() => finished += 1));
    }
    await eventually(() async => started.length == 4);

    for (int released = 1; released <= blobs.length; released++) {
      final Completer<http.StreamedResponse> next = held.removeAt(0);
      inFlight -= 1;
      next.complete(
        jsonAnswer(
          HttpStatus.notFound,
          const ErrorResponse(
            code: SyncErrorCode.notFound,
            message: 'Not stored here',
          ).toJson(),
        ),
      );
      await eventually(() async => finished == released);
      await eventually(
        () async => started.length == min(blobs.length, released + 4),
      );
    }

    expect(most, 4);
    expect(started.sublist(0, 4).toSet(), <String>{
      for (final domain.MediaBlob blob in blobs.take(4)) blob.id,
    });
    expect(started.sublist(4), <String>[blobs[4].id, blobs[5].id]);
    expect(await Future.wait(downloads), everyElement(isFalse));
  });
}
