import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../integration_test/probe/composer_probe_main.dart'
    show probeCaretAuditOffsets, probeStyledRunCount;
import '../../../integration_test/probe/probe_server.dart';
import '../../../integration_test/probe/probe_storage.dart';
// ignore: avoid_relative_lib_imports
import '../../../tool/probe/lib/gates.dart';

const List<String> _h1Endpoints = <String>[
  'state',
  'keys',
  'find',
  'open',
  'save',
  'close',
  'set',
  'select',
  'focus',
  'errors',
  'timings',
  'clock',
  'caretAudit',
  'boxes',
  'hit',
  'offsetAt',
  'semantics',
  'settings',
  'viewport',
  'pid',
  'shot',
  'nextPhoto',
  'watch',
  'log',
  'flags',
];

final class _DirectHttpOverrides extends HttpOverrides {}

ProbeHandler _echo(String name) =>
    (ProbeRequest request) async =>
        ProbeReply.json(<String, Object?>{'endpoint': name});

Map<String, ProbeHandler> _handlers({
  Map<String, ProbeHandler> replace = const <String, ProbeHandler>{},
  Set<String> omit = const <String>{},
}) {
  final Map<String, ProbeHandler> handlers = <String, ProbeHandler>{
    for (final String name in <String>[..._h1Endpoints, probeScenarioEndpoint])
      if (!omit.contains(name)) name: _echo(name),
    'shot': (ProbeRequest request) async =>
        const ProbeReply.png(<int>[137, 80, 78, 71, 13, 10, 26, 10]),
  };
  return <String, ProbeHandler>{...handlers, ...replace}
    ..removeWhere((String name, ProbeHandler _) => omit.contains(name));
}

ProbeRequest _request(String name, {String body = ''}) =>
    ProbeRequest(name: name, query: const <String, String>{}, body: body);

Future<HttpServer> _serve(ProbeServer probe) async {
  final HttpServer server = await probe.bind(port: 0);
  addTearDown(() => server.close(force: true));
  return server;
}

HttpClient _client() {
  final HttpClient client = HttpOverrides.runWithHttpOverrides<HttpClient>(
    () => HttpClient(),
    _DirectHttpOverrides(),
  );
  addTearDown(() => client.close(force: true));
  return client;
}

Future<Directory> _base() async {
  final Directory base = await Directory.systemTemp.createTemp('probe-store-');
  addTearDown(() async {
    if (await base.exists()) {
      await base.delete(recursive: true);
    }
  });
  return base;
}

Future<bool> _isEmpty(Directory directory) async =>
    (await directory.list().toList()).isEmpty;

void main() {
  test('the probe routes every endpoint of h1', () async {
    expect(probeEndpoints, _h1Endpoints);
    final ProbeServer probe = ProbeServer(_handlers());
    for (final String name in <String>[
      ..._h1Endpoints.where((String name) => name != 'shot'),
      probeScenarioEndpoint,
    ]) {
      final ProbeReply reply = await probe.route(_request(name));
      expect(reply.status, 200, reason: name);
      expect(reply.body, <String, Object?>{'endpoint': name}, reason: name);
    }
    final ProbeReply shot = await probe.route(_request('shot'));
    expect(shot.status, 200);
    expect(shot.body, isNull);
    expect(shot.png, hasLength(8));
    final ProbeReply unknown = await probe.route(_request('nope'));
    expect(unknown.status, 404);
    expect(unknown.body, <String, Object?>{'error': 'unknown endpoint nope'});
    expect(
      () => ProbeServer(_handlers(omit: <String>{'state'})),
      throwsArgumentError,
    );

    final HttpServer server = await _serve(probe);
    expect(server.address.isLoopback, isTrue);
    final HttpClient client = _client();
    final HttpClientResponse pid = await (await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/pid?x=1'),
    )).close();
    expect(pid.statusCode, 200);
    expect(pid.headers.contentType?.mimeType, 'application/json');
    expect(jsonDecode(await utf8.decoder.bind(pid).join()), <String, Object?>{
      'endpoint': 'pid',
    });
    final HttpClientResponse png = await (await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/shot'),
    )).close();
    expect(png.statusCode, 200);
    expect(png.headers.contentType?.mimeType, 'image/png');
    expect(
      await png.fold<List<int>>(
        <int>[],
        (List<int> all, List<int> chunk) => <int>[...all, ...chunk],
      ),
      hasLength(8),
    );
  });

  test('a keystroke reports its handler time apart from its build', () {
    final Map<String, Object?> keystroke = probeKeystrokeJson(
      handlerMicros: 500,
      buildMicros: 2000,
      rasterFinishMicros: 9000,
      keyDownMicros: 100,
    );
    expect(keystroke['handlerMs'], 0.5);
    expect(keystroke['buildMs'], 2.0);
    final RowOutcome gp1 = evaluateResult(<String, Object?>{
      'scenario': 'perf-keystroke',
      'platform': 'macos',
      'build': 'profile',
      'commit': 'abc',
      'samples': <Object?>[
        <String, Object?>{
          'row': 'GP1',
          'kind': 'keystroke',
          'note': 'c500-p0',
          'timings': <String, Object?>{
            'keystrokes': <Object?>[keystroke],
          },
        },
      ],
    }).singleWhere((RowOutcome outcome) => outcome.row == 'GP1');
    expect(gp1.values['worstP95'], 2.5);
    expect(gp1.verdict, GateVerdict.pass);
    expect(
      probeKeystrokeJson(
        handlerMicros: 700,
        buildMicros: null,
        rasterFinishMicros: null,
        keyDownMicros: null,
      )['handlerMs'],
      0.7,
    );
  });

  test('the error log keeps a scenario scope that clearing does not wipe', () {
    final Object first = Object();
    final Object second = Object();
    final ProbeErrorLog cleared = const ProbeErrorLog()
        .recordError(<String, Object?>{'error': 'assertion'})
        .observe(first, <String>['stale'])
        .clearWindow();
    expect(cleared.json(scenario: false), <String, Object?>{
      'errors': const <Object?>[],
      'drops': const <Object?>[],
    });
    expect(cleared.json(scenario: true)['errors'], hasLength(1));
    expect(cleared.json(scenario: true)['drops'], <Object?>[
      <String, Object?>{'reason': 'stale'},
    ]);
    final ProbeErrorLog later = cleared
        .observe(first, <String>['stale', 'window'])
        .observe(second, <String>['other']);
    expect(later.json(scenario: true)['drops'], <Object?>[
      <String, Object?>{'reason': 'stale'},
      <String, Object?>{'reason': 'window'},
      <String, Object?>{'reason': 'other'},
    ]);
    expect(later.json(scenario: false)['drops'], <Object?>[
      <String, Object?>{'reason': 'window'},
      <String, Object?>{'reason': 'other'},
    ]);
    expect(
      later.observe(second, <String>['other']).json(scenario: true)['drops'],
      hasLength(3),
    );
    final ProbeErrorLog reset = later.resetScenario();
    expect(reset.json(scenario: true), <String, Object?>{
      'errors': const <Object?>[],
      'drops': const <Object?>[],
    });
    expect(
      reset.observe(second, <String>['other']).json(scenario: true)['drops'],
      isEmpty,
    );
  });

  test('styled runs skip plain text runs and the audit reaches the end', () {
    expect(
      probeStyledRunCount(<String>[
        'paragraph',
        'text',
        'text',
        'softBreak',
        'hardBreak',
        'text',
      ]),
      0,
    );
    expect(
      probeStyledRunCount(<String>['paragraph', 'text', 'strong', 'text']),
      1,
    );
    expect(
      probeCaretAuditOffsets(from: 4000, to: 4003, length: 4003).toList(),
      <int>[4000, 4001, 4002, 4003],
    );
    expect(probeCaretAuditOffsets(from: 0, to: 3, length: 4003).toList(), <int>[
      0,
      1,
      2,
    ]);
  });

  test('a throwing handler gives 500 with its message', () async {
    final ProbeServer probe = ProbeServer(
      _handlers(
        replace: <String, ProbeHandler>{
          'focus': (ProbeRequest request) async =>
              throw StateError('no editor on screen'),
        },
      ),
    );
    final ProbeReply reply = await probe.route(_request('focus'));
    expect(reply.status, 500);
    expect(
      (reply.body! as Map<String, Object?>)['error'],
      contains('no editor on screen'),
    );
  });

  test('a post body and query reach the handler as utf-8 text', () async {
    final List<ProbeRequest> seen = <ProbeRequest>[];
    final ProbeServer probe = ProbeServer(
      _handlers(
        replace: <String, ProbeHandler>{
          'set': (ProbeRequest request) async {
            seen.add(request);
            return ProbeReply.json(<String, Object?>{
              'length': request.body.length,
            });
          },
        },
      ),
    );
    final HttpServer server = await _serve(probe);
    final HttpClient client = _client();
    const String source = '# Café 日本 \u{20BB7}\n\nA ==line==.';
    final HttpClientRequest post = await client.postUrl(
      Uri.parse('http://127.0.0.1:${server.port}/set?base=2&extent=4'),
    );
    post.headers.contentType = ContentType('text', 'plain', charset: 'utf-8');
    post.add(utf8.encode(source));
    final HttpClientResponse response = await post.close();
    expect(response.statusCode, 200);
    expect(
      jsonDecode(await utf8.decoder.bind(response).join()),
      <String, Object?>{'length': source.length},
    );
    expect(seen.single.name, 'set');
    expect(seen.single.body, source);
    expect(seen.single.query, <String, String>{'base': '2', 'extent': '4'});
    final HttpClientResponse missing = await (await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/nope'),
    )).close();
    expect(missing.statusCode, 404);
    expect(
      jsonDecode(await utf8.decoder.bind(missing).join()),
      <String, Object?>{'error': 'unknown endpoint nope'},
    );
  });

  test(
    'scenario storage persists across a relaunch and is wiped between scenarios',
    () async {
      final Directory base = await _base();
      final ProbeStorage first = await (await ProbeStorage.open(
        base,
      )).begin('draft-recovery');
      final File photo = File(p.join(first.media.path, 'ab', 'photo.png'));
      await photo.create(recursive: true);
      await photo.writeAsBytes(<int>[1, 2, 3]);
      final File draft = File(p.join(first.drafts.path, 'new-2026-09-24.md'));
      await draft.writeAsString('typed');
      await File(first.database).writeAsBytes(<int>[4, 5, 6]);

      final ProbeStorage relaunched = await ProbeStorage.open(base);
      expect(relaunched.scenario, 'draft-recovery');
      expect(await photo.exists(), isTrue);
      expect(await draft.readAsString(), 'typed');
      expect(await File(relaunched.database).readAsBytes(), <int>[4, 5, 6]);

      final ProbeStorage kept = await relaunched.begin('draft-recovery');
      expect(kept.wiped, isFalse);
      expect(await photo.exists(), isTrue);
      expect(await draft.exists(), isTrue);
      expect(await File(kept.database).exists(), isTrue);

      final ProbeStorage next = await kept.begin('perf-idle');
      expect(next.scenario, 'perf-idle');
      expect(next.wiped, isTrue);
      expect(await next.media.exists(), isTrue);
      expect(await next.drafts.exists(), isTrue);
      expect(await _isEmpty(next.media), isTrue);
      expect(await _isEmpty(next.drafts), isTrue);
      expect(await File(next.database).exists(), isFalse);

      expect((await ProbeStorage.open(base)).scenario, 'perf-idle');
    },
  );

  test('a fresh begin wipes the current scenario', () async {
    final Directory base = await _base();
    final ProbeStorage idle = await (await ProbeStorage.open(
      base,
    )).begin('perf-idle');
    await File(idle.database).writeAsBytes(<int>[1]);
    final ProbeStorage same = await idle.begin('perf-idle');
    expect(same.wiped, isFalse);
    expect(await File(same.database).exists(), isTrue);
    final ProbeStorage fresh = await same.begin('perf-idle', fresh: true);
    expect(fresh.wiped, isTrue);
    expect(fresh.scenario, 'perf-idle');
    expect(await File(fresh.database).exists(), isFalse);
    expect((await ProbeStorage.open(base)).scenario, 'perf-idle');
  });

  test('storage opens empty with its folders under base/data', () async {
    final Directory base = await _base();
    final ProbeStorage storage = await ProbeStorage.open(base);
    expect(storage.scenario, '');
    expect(storage.wiped, isFalse);
    final String root = p.join(base.path, 'data');
    final String documents = p.join(root, 'documents');
    expect(storage.root.path, root);
    expect(storage.documents.path, documents);
    expect(storage.database, p.join(documents, 'field_notes.sqlite'));
    expect(storage.media.path, p.join(documents, 'media'));
    expect(storage.drafts.path, p.join(documents, 'drafts'));
    expect(await storage.media.exists(), isTrue);
    expect(await storage.drafts.exists(), isTrue);
    expect(await File(storage.database).exists(), isFalse);
  });
}
