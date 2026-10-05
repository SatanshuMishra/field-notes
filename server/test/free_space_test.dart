import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/probes.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

const String linuxDf = '''
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/nvme0n1p2   976761560 123456789 850000000      13% /srv
''';

const String spacedDf = '''
Filesystem    1024-blocks       Used Available Capacity  Mounted on
map auto_home           0          0         0   100%    /System/Volumes/Data/home share
''';

void main() {
  test('a part is refused while the media disk is nearly full', () async {
    final RelayHarness harness = await RelayHarness.start();
    addTearDown(harness.dispose);
    final TestAccount account = await harness.enrol();
    final SignedIn me = await harness.signIn(account.firstDevice);
    Future<http.Response> sendPart() => harness.putPart(
      me.session,
      name: harness.blobName(),
      uploadId: newSyncId(),
      index: 0,
      blobSize: 1500,
      partSize: 1024,
      bytes: Uint8List(1024),
    );
    expect(harness.config.minFreeBytes, RelayConfig.defaultMinFreeBytes);

    harness.freeBytes = RelayConfig.defaultMinFreeBytes - 1;
    final http.Response refused = await sendPart();

    expect(refused.statusCode, HttpStatus.insufficientStorage);
    expect(errorOf(refused).code, SyncErrorCode.storageFull);
    expect(harness.database.count('SELECT count(*) FROM uploads'), 0);

    harness.freeBytes = RelayConfig.defaultMinFreeBytes + 1024;
    expect(
      errorOf(await sendPart()).code,
      SyncErrorCode.storageFull,
      reason: 'the free space reading is kept for five seconds',
    );
    harness.advance(const Duration(seconds: 5));
    expect((await sendPart()).statusCode, HttpStatus.ok);
  });

  test('free space is read from df', () async {
    expect(parseDfAvailableBytes(linuxDf), 850000000 * 1024);
    expect(parseDfAvailableBytes(spacedDf), 0);
    expect(parseDfAvailableBytes('df: /missing: No such file\n'), isNull);

    for (final String folder in <String>[
      Directory.systemTemp.path,
      '${Directory.systemTemp.path}/no-such-folder-${newSyncId()}',
    ]) {
      final int? free = await dfFreeBytes(folder);
      expect(
        free == null || free > 0,
        isTrue,
        reason: 'a positive number or null for $folder, got $free',
      );
    }
  });

  test('the minimum free space is read from RELAY_MIN_FREE_BYTES', () {
    expect(
      RelayConfig.fromEnvironment(const <String, String>{}).minFreeBytes,
      2 * 1024 * 1024 * 1024,
    );
    expect(
      RelayConfig.fromEnvironment(const <String, String>{
        'RELAY_MIN_FREE_BYTES': '5000000000',
      }).minFreeBytes,
      5000000000,
    );
    for (final String invalid in <String>['-1', 'lots', '2GB']) {
      expect(
        () => RelayConfig.fromEnvironment(<String, String>{
          'RELAY_MIN_FREE_BYTES': invalid,
        }),
        throwsA(isA<ConfigException>()),
        reason: invalid,
      );
    }
  });
}
