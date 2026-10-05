import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relay_server/relay_server.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

final class CapturedOutput implements Stdout {
  final StringBuffer text = StringBuffer();

  @override
  void write(Object? object) => text.write(object);

  @override
  void writeln([Object? object = '']) => text.writeln(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      text.writeAll(objects, separator);

  @override
  void add(List<int> data) =>
      text.write(utf8.decode(data, allowMalformed: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final bool runningAsRoot =
    '${Process.runSync('id', <String>['-u']).stdout}'.trim() == '0';

void main() {
  test(
    'a failed blob read is logged as one internal error line without the blob name',
    () async {
      final CapturedOutput errors = CapturedOutput();
      final RelayHarness harness = await IOOverrides.runZoned(
        RelayHarness.start,
        stderr: () => errors,
      );
      addTearDown(harness.dispose);
      final TestAccount account = await harness.enrol();
      final SignedIn mac = await harness.signIn(account.firstDevice);
      final String name = harness.blobName();
      final Uint8List blob = harness.randomOpaque(3000);
      await harness.uploadBlob(mac.session, name, blob);
      final String path = blobPath(
        harness.mediaDirectory,
        account.accountId,
        name,
      );
      Process.runSync('chmod', <String>['000', path]);
      addTearDown(() => Process.runSync('chmod', <String>['644', path]));
      harness.logLines.clear();

      http.Response? downloaded;
      try {
        downloaded = await harness.send(
          SyncRoutes.downloadBlob,
          parameters: <String, Object>{SyncRoutes.nameParameter: name},
          credential: mac.session,
        );
      } on http.ClientException {
        downloaded = null;
      }
      await harness.logLine(
        (String line) => line.contains('"event":"internal_error"'),
      );

      expect(downloaded?.bodyBytes, isNot(blob));
      final List<Map<String, Object?>> lines = <Map<String, Object?>>[
        for (final String line in harness.logLines)
          jsonDecode(line) as Map<String, Object?>,
      ];
      final List<Map<String, Object?>> internal = <Map<String, Object?>>[
        for (final Map<String, Object?> line in lines)
          if (line['event'] == 'internal_error') line,
      ];
      expect(internal, hasLength(1));
      expect(internal.single.keys.toSet(), <String>{'ts', 'event'});
      expect(DateTime.tryParse(internal.single['ts']! as String), isNotNull);
      for (final String line in harness.logLines) {
        expect(line, isNot(contains(name)));
        expect(line, isNot(contains(harness.mediaDirectory)));
      }
      expect('${errors.text}', isEmpty);
    },
    skip: runningAsRoot
        ? 'chmod does not stop root from reading a file'
        : false,
  );
}
