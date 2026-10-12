import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:field_notes/data/updates/github_release_source.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _downloads =
    'https://github.com/SatanshuMishra/field-notes/releases/download/v1.2.0/';
const String _page =
    'https://github.com/SatanshuMishra/field-notes/releases/tag/v1.2.0';
const String _body = '''
Settings has a **new** look.

### New
- An About page with the [version](https://github.com/SatanshuMishra/field-notes).
- Checks for updates
  once a day.

### Fixed
- <em>Faster</em> start.

## Installing
- Download field-notes-1.2.0-macos.dmg and open it.
''';

final DateTime _now = DateTime.utc(2026, 10, 11, 9);

Map<String, Object?> _asset(String name, int size, {String? url}) =>
    <String, Object?>{
      'name': name,
      'size': size,
      'browser_download_url': url ?? '$_downloads$name',
    };

Map<String, Object?> _release([Map<String, Object?> changes = const {}]) =>
    <String, Object?>{
      'tag_name': 'v1.2.0',
      'name': 'Field Notes 1.2.0',
      'draft': false,
      'prerelease': false,
      'published_at': '2026-10-09T15:30:00Z',
      'html_url': _page,
      'body': _body,
      'assets': <Object?>[
        _asset('field-notes-1.2.0-macos.dmg', 41000000),
        _asset('field-notes-1.2.0-windows-x64-setup.exe', 38000000),
        _asset('field-notes-1.2.0-android.apk', 52000000),
        _asset('SHA256SUMS.txt', 300),
        _asset('SHA256SUMS.txt.sig', 89),
        _asset(
          'elsewhere.dmg',
          10,
          url: 'https://evil.example.com/field-notes.dmg',
        ),
        _asset('plain.dmg', 10, url: 'http://github.com/plain.dmg'),
        _asset(
          'objects.dmg',
          10,
          url: 'https://objects.githubusercontent.com/objects.dmg',
        ),
        <String, Object?>{
          'name': 'sizeless.dmg',
          'browser_download_url': '${_downloads}sizeless.dmg',
        },
        _asset('', 10),
      ],
      ...changes,
    };

ReleaseInfo _expectedRelease() => ReleaseInfo(
  version: AppVersion.tryParse('1.2.0')!,
  tag: 'v1.2.0',
  publishedAt: DateTime.utc(2026, 10, 9, 15, 30),
  notes: ReleaseNotes(
    intro: 'Settings has a new look.',
    groups: <ReleaseNoteGroup>[
      ReleaseNoteGroup(
        title: 'New',
        items: <String>[
          'An About page with the version.',
          'Checks for updates once a day.',
        ],
      ),
      ReleaseNoteGroup(title: 'Fixed', items: <String>['Faster start.']),
    ],
  ),
  pageUrl: Uri.parse(_page),
  assets: <ReleaseAsset>[
    for (final (String name, int size) in <(String, int)>[
      ('field-notes-1.2.0-macos.dmg', 41000000),
      ('field-notes-1.2.0-windows-x64-setup.exe', 38000000),
      ('field-notes-1.2.0-android.apk', 52000000),
      ('SHA256SUMS.txt', 300),
      ('SHA256SUMS.txt.sig', 89),
    ])
      ReleaseAsset(name: name, url: Uri.parse('$_downloads$name'), size: size),
  ],
);

final class _Recorder {
  final List<http.BaseRequest> requests = <http.BaseRequest>[];
}

Future<ReleaseLookup> _lookup(
  Future<http.Response> Function(http.Request request) answer, {
  _Recorder? recorder,
}) {
  final MockClient client = MockClient((http.Request request) {
    recorder?.requests.add(request);
    return answer(request);
  });
  return GitHubReleaseSource(client: client, clock: () => _now).latest();
}

Future<ReleaseLookup> _answer(
  int status, {
  Object? json,
  String? body,
  Map<String, String> headers = const <String, String>{},
}) => _lookup(
  (http.Request request) async =>
      http.Response(body ?? jsonEncode(json), status, headers: headers),
);

Future<ReleaseLookup> _throwing(Object error) =>
    _lookup((http.Request request) async => throw error);

void main() {
  test('the release source reads the latest release and reports each failure', () async {
    final _Recorder recorder = _Recorder();
    final ReleaseLookup found = await _lookup(
      (http.Request request) async =>
          http.Response(jsonEncode(_release()), 200),
      recorder: recorder,
    );
    expect(recorder.requests, hasLength(1));
    final http.Request sent = recorder.requests.single as http.Request;
    expect(sent.method, 'GET');
    expect(
      sent.url,
      Uri.parse(
        'https://api.github.com/repos/SatanshuMishra/field-notes/releases/latest',
      ),
    );
    expect(sent.headers, <String, String>{
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'FieldNotes',
    });
    expect(sent.headers.keys, hasLength(3));
    expect(sent.headers.containsKey('cookie'), isFalse);
    expect(sent.headers.containsKey('authorization'), isFalse);
    expect(sent.bodyBytes, isEmpty);
    expect(found, ReleaseFound(_expectedRelease()));
    final ReleaseInfo release = (found as ReleaseFound).release;
    expect(
      release.assets.map((ReleaseAsset asset) => asset.url.host).toSet(),
      <String>{'github.com'},
    );
    expect(
      release.assets.map((ReleaseAsset asset) => asset.url.scheme).toSet(),
      <String>{'https'},
    );

    final ReleaseLookup noBody = await _answer(
      200,
      json: _release(<String, Object?>{'body': null}),
    );
    expect((noBody as ReleaseFound).release.notes, ReleaseNotes.empty);

    expect(await _answer(404, json: <String, Object?>{}), const NoRelease());

    expect(
      await _answer(
        403,
        json: <String, Object?>{'message': 'API rate limit exceeded'},
        headers: <String, String>{
          'x-ratelimit-remaining': '0',
          'x-ratelimit-reset': '1791000000',
        },
      ),
      LookupRateLimited(
        DateTime.fromMillisecondsSinceEpoch(1791000000 * 1000, isUtc: true),
      ),
    );
    expect(
      await _answer(
        429,
        json: <String, Object?>{},
        headers: <String, String>{
          'x-ratelimit-remaining': '0',
          'x-ratelimit-reset': '1791000600',
        },
      ),
      LookupRateLimited(
        DateTime.fromMillisecondsSinceEpoch(1791000600 * 1000, isUtc: true),
      ),
    );
    expect(
      await _answer(
        429,
        json: <String, Object?>{},
        headers: <String, String>{'retry-after': '120'},
      ),
      LookupRateLimited(_now.add(const Duration(seconds: 120))),
    );
    expect(
      await _answer(
        403,
        json: <String, Object?>{},
        headers: <String, String>{
          'x-ratelimit-remaining': '12',
          'retry-after': '30',
        },
      ),
      LookupRateLimited(_now.add(const Duration(seconds: 30))),
    );
    expect(
      await _answer(403, json: <String, Object?>{}),
      LookupRateLimited(_now.add(const Duration(seconds: 60))),
    );

    expect(
      await _throwing(const SocketException('no route to host')),
      const LookupFailed(LookupFailure.offline),
    );
    expect(
      await _throwing(const HandshakeException('bad certificate')),
      const LookupFailed(LookupFailure.offline),
    );
    expect(
      await _throwing(http.ClientException('connection closed')),
      const LookupFailed(LookupFailure.offline),
    );
    expect(
      await _throwing(TimeoutException('slow')),
      const LookupFailed(LookupFailure.offline),
    );

    fakeAsync((FakeAsync async) {
      ReleaseLookup? waited;
      GitHubReleaseSource(
        client: MockClient(
          (http.Request request) => Completer<http.Response>().future,
        ),
        clock: () => _now,
      ).latest().then((ReleaseLookup lookup) => waited = lookup);
      async.elapse(const Duration(seconds: 19));
      expect(waited, isNull);
      async.elapse(const Duration(seconds: 2));
      expect(waited, const LookupFailed(LookupFailure.offline));
    });

    const LookupFailed refused = LookupFailed(LookupFailure.badResponse);
    expect(await _answer(500, json: <String, Object?>{}), refused);
    expect(await _answer(302, json: <String, Object?>{}), refused);
    expect(await _answer(200, body: '{"tag_name": "v1.2.0"'), refused);
    expect(await _answer(200, body: 'not json'), refused);
    expect(await _answer(200, json: <Object?>[_release()]), refused);
    for (final Map<String, Object?> change in <Map<String, Object?>>[
      <String, Object?>{'draft': true},
      <String, Object?>{'prerelease': true},
      <String, Object?>{'draft': null},
      <String, Object?>{'prerelease': 'false'},
      <String, Object?>{'tag_name': 'latest'},
      <String, Object?>{'tag_name': 'v1.2'},
      <String, Object?>{'tag_name': null},
      <String, Object?>{'published_at': 'yesterday'},
      <String, Object?>{'published_at': null},
      <String, Object?>{
        'html_url':
            'http://github.com/SatanshuMishra/field-notes/releases/tag/v1.2.0',
      },
      <String, Object?>{'html_url': 'https://evil.example.com/releases'},
      <String, Object?>{'html_url': null},
      <String, Object?>{'assets': 'none'},
      <String, Object?>{'body': 12},
    ]) {
      expect(
        await _answer(200, json: _release(change)),
        refused,
        reason: '$change',
      );
    }

    final List<int> oversized = utf8.encode(
      jsonEncode(_release(<String, Object?>{'body': 'x' * (1024 * 1024 + 10)})),
    );
    expect(
      await _lookup(
        (http.Request request) async => http.Response.bytes(oversized, 200),
      ),
      refused,
    );

    int delivered = 0;
    Stream<List<int>> endless() async* {
      while (true) {
        delivered++;
        yield List<int>.filled(64 * 1024, 0x20);
      }
    }

    final ReleaseLookup streamed = await GitHubReleaseSource(
      client: MockClient.streaming(
        (http.BaseRequest request, http.ByteStream body) async =>
            http.StreamedResponse(endless(), 200),
      ),
      clock: () => _now,
    ).latest();
    expect(streamed, refused);
    expect(delivered, lessThanOrEqualTo(18));
  });
}
