import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/media/unused_blobs.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

const String _unused = '/v1/blobs/unused';
const String _referenced = '/v1/blobs/referenced';

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 5 + seed) % 251);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late RelayFixture relay;
  late SyncTestDevice mac;
  late SyncTestMedia media;
  late RelayClient client;
  late domain.Day day;

  setUp(() async {
    relay = await RelayFixture.start(rateBurst: 1000);
    mac = await enrolDevice(relay, SyncTestDevice('Mac'));
    media = await SyncTestMedia.create(mac);
    client = mac.relayClient(relay.baseUrl, await mac.deviceKeys(), (_) {});
    day = await mac.journal.ensureDayForDate('2026-10-12');
  });

  tearDown(() async {
    await mac.dispose();
    await relay.dispose();
  });

  Future<domain.MediaBlob> uploadedVoice(int seed) async {
    final domain.MediaBlob blob = await media.store.putBytes(
      bytes: _bytes(900, seed),
      mime: 'audio/mp4',
      kind: domain.MediaKind.audio,
    );
    await media.uploads.prepare(blob.id);
    await media.uploads.send(client, RelayUploadSender(client));
    return blob;
  }

  Future<domain.Entry> voiceEntry(domain.MediaBlob blob) =>
      mac.journal.createEntry(
        dayId: day.id,
        type: domain.EntryType.voice,
        mediaId: blob.id,
      );

  test('unused blobs are reported only after a complete pull', () async {
    final domain.MediaBlob kept = await uploadedVoice(1);
    final domain.MediaBlob dropped = await uploadedVoice(2);
    await voiceEntry(kept);
    final domain.Entry goes = await voiceEntry(dropped);
    await mac.journal.softDeleteEntry(goes.id);

    await writeSyncState(mac.database, pullCompleteKey, pullIncompleteValue);
    final BlobReport incomplete = await media.unusedBlobs.report(client);

    expect(incomplete.unused, isEmpty);
    expect(mac.http.countOf('POST', _unused), 0);

    await writeSyncState(mac.database, pullCompleteKey, pullCompleteValue);
    final BlobReport complete = await media.unusedBlobs.report(client);

    expect(complete.unused, <String>[dropped.id]);
    expect(mac.http.countOf('POST', _unused), 1);

    final BlobReport again = await media.unusedBlobs.report(client);
    expect(again.unused, isEmpty);
    expect(mac.http.countOf('POST', _unused), 1);
  });

  test('only changed reachability is reported', () async {
    final domain.MediaBlob first = await uploadedVoice(3);
    final domain.MediaBlob second = await uploadedVoice(4);
    await voiceEntry(first);
    await voiceEntry(second);
    await writeSyncState(mac.database, pullCompleteKey, pullCompleteValue);

    final BlobReport initial = await media.unusedBlobs.report(client);
    expect(initial.referenced.toSet(), <String>{first.id, second.id});
    expect(mac.http.countOf('POST', _referenced), 1);

    final BlobReport unchanged = await media.unusedBlobs.report(client);
    expect(unchanged.unused, isEmpty);
    expect(unchanged.referenced, isEmpty);
    expect(mac.http.countOf('POST', _referenced), 1);
    expect(mac.http.countOf('POST', _unused), 0);

    await mac.clock.advance(const Duration(hours: 23));
    final domain.MediaBlob third = await uploadedVoice(5);
    await voiceEntry(third);
    final BlobReport changed = await media.unusedBlobs.report(client);
    expect(changed.referenced, <String>[third.id]);

    await mac.clock.advance(const Duration(hours: 1));
    final BlobReport daily = await media.unusedBlobs.report(client);
    expect(daily.referenced.toSet(), <String>{first.id, second.id, third.id});
    expect(mac.http.countOf('POST', _referenced), 3);
    expect(await media.uploads.pendingUploads(), isEmpty);
  });
}
