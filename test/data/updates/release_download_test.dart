import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:field_notes/data/updates/release_download.dart';
import 'package:field_notes/data/updates/release_verifier.dart';
import 'package:field_notes/domain/updates/app_version.dart';
import 'package:field_notes/domain/updates/release_info.dart';
import 'package:field_notes/domain/updates/update_installer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sodium/sodium.dart';

const String _assetName = 'field-notes-1.2.0-windows-x64-setup.exe';
const String _downloads =
    'https://github.com/SatanshuMishra/field-notes/releases/download/v1.2.0/';
const String _assetStore =
    'https://release-assets.githubusercontent.com/github-production-release-asset/1/';
const int _chunk = 1024;

typedef _Answer = Future<http.StreamedResponse> Function();

Uri _github(String name) => Uri.parse('$_downloads$name');

Uri _stored(String name) => Uri.parse('$_assetStore$name?sp=r&sv=2018-11-09');

Uri _hop(int index) => Uri.parse('${_downloads}hop/$index/$_assetName');

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 17 + seed) % 256);

List<List<int>> _pieces(List<int> bytes, int size) => <List<int>>[
  for (int start = 0; start < bytes.length; start += size)
    bytes.sublist(
      start,
      start + size > bytes.length ? bytes.length : start + size,
    ),
];

_Answer _status(int code) =>
    () async => http.StreamedResponse(
      Stream<List<int>>.fromIterable(const <List<int>>[]),
      code,
    );

_Answer _redirect(Uri to, {int status = 302}) =>
    () async => http.StreamedResponse(
      Stream<List<int>>.fromIterable(const <List<int>>[]),
      status,
      headers: <String, String>{'location': to.toString()},
    );

_Answer _body(List<int> bytes, {bool withLength = true, int? claimedLength}) =>
    () async => http.StreamedResponse(
      Stream<List<int>>.fromIterable(_pieces(bytes, _chunk)),
      200,
      contentLength: claimedLength ?? (withLength ? bytes.length : null),
    );

_Answer _streamed(Stream<List<int>> Function() body, {int? length}) =>
    () async => http.StreamedResponse(body(), 200, contentLength: length);

final class _Hollow extends ListBase<int> {
  _Hollow(this._length);

  final int _length;

  @override
  int get length => _length;

  @override
  set length(int value) => throw UnsupportedError('A hollow chunk is fixed');

  @override
  int operator [](int index) => 0;

  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('A hollow chunk is read-only');
}

final class _Signer {
  _Signer() : _pair = loadSodium().crypto.sign.keyPair();

  final KeyPair _pair;

  ReleaseVerifier get verifier => ReleaseVerifier(_pair.publicKey);

  String sign(List<int> message) => base64.encode(
    loadSodium().crypto.sign.detached(
      message: Uint8List.fromList(message),
      secretKey: _pair.secretKey,
    ),
  );

  void dispose() => _pair.dispose();
}

final class _Published {
  _Published(this.signer, {required this.setup, List<int>? sums})
    : sums =
          sums ??
          utf8.encode(
            '${sha256.convert(utf8.encode('mac'))}  field-notes-1.2.0-macos.dmg\n'
            '${sha256.convert(setup)}  $_assetName\n',
          );

  final _Signer signer;
  final List<int> setup;
  final List<int> sums;

  String get signature => signer.sign(sums);

  Map<Uri, _Answer> answers() => <Uri, _Answer>{
    _github(releaseSumsName): _redirect(_stored(releaseSumsName)),
    _stored(releaseSumsName): _body(sums),
    _github(releaseSignatureName): _redirect(_stored(releaseSignatureName)),
    _stored(releaseSignatureName): _body(utf8.encode('$signature\n')),
    _github(_assetName): _redirect(_stored(_assetName)),
    _stored(_assetName): _body(setup),
  };
}

final class _Github {
  _Github(Map<Uri, _Answer> answers)
    : _answers = Map<Uri, _Answer>.unmodifiable(answers);

  final Map<Uri, _Answer> _answers;
  final List<http.BaseRequest> _requests = <http.BaseRequest>[];

  List<Uri> get requested => <Uri>[
    for (final http.BaseRequest request in _requests) request.url,
  ];

  bool get everyRequestIsAPlainGet => _requests.every(
    (http.BaseRequest request) =>
        request.method == 'GET' && !request.followRedirects,
  );

  late final MockClient client = MockClient.streaming((
    http.BaseRequest request,
    http.ByteStream _,
  ) {
    _requests.add(request);
    final _Answer? answer = _answers[request.url];
    return answer == null ? _status(404)() : answer();
  });
}

final class _Run {
  const _Run(this.outcome, this.events, this.left, this.into);

  final DownloadOutcome outcome;
  final List<InstallEvent> events;
  final List<FileSystemEntity> left;
  final Directory into;

  File get file => File('${into.path}/$_assetName');

  List<InstallDownloading> get progress =>
      events.whereType<InstallDownloading>().toList();
}

ReleaseInfo _release({
  bool withAsset = true,
  bool withSums = true,
  bool withSignature = true,
  Uri? assetUrl,
  Uri? sumsUrl,
}) => ReleaseInfo(
  version: AppVersion.tryParse('1.2.0')!,
  tag: 'v1.2.0',
  publishedAt: DateTime.utc(2026, 10, 11, 9),
  notes: ReleaseNotes.empty,
  pageUrl: Uri.parse(
    'https://github.com/SatanshuMishra/field-notes/releases/tag/v1.2.0',
  ),
  assets: <ReleaseAsset>[
    if (withAsset)
      ReleaseAsset(
        name: _assetName,
        url: assetUrl ?? _github(_assetName),
        size: 40960,
      ),
    if (withSums)
      ReleaseAsset(
        name: releaseSumsName,
        url: sumsUrl ?? _github(releaseSumsName),
        size: 180,
      ),
    if (withSignature)
      ReleaseAsset(
        name: releaseSignatureName,
        url: _github(releaseSignatureName),
        size: 89,
      ),
  ],
);

Future<_Run> _download(
  _Github github,
  ReleaseVerifier verifier, {
  ReleaseInfo? release,
  String assetName = _assetName,
  Duration interval = const Duration(milliseconds: 100),
  Duration timeout = releaseDownloadTimeout,
}) async {
  final Directory into = Directory.systemTemp.createTempSync(
    'release_download_test',
  );
  addTearDown(() => into.deleteSync(recursive: true));
  final List<InstallEvent> events = <InstallEvent>[];
  final DownloadOutcome outcome =
      await ReleaseDownloader(
        client: github.client,
        verifier: verifier,
        progressInterval: interval,
        timeout: timeout,
      ).downloadVerified(
        release: release ?? _release(),
        assetName: assetName,
        into: into,
        onEvent: events.add,
      );
  return _Run(outcome, events, into.listSync(), into);
}

const DownloadFailed _network = DownloadFailed(InstallFailure.network);
const DownloadFailed _notReady = DownloadFailed(InstallFailure.notReady);
const DownloadFailed _unverified = DownloadFailed(InstallFailure.verification);

void main() {
  late _Signer signer;
  late _Published published;

  setUp(() {
    signer = _Signer();
    published = _Published(signer, setup: _bytes(40 * _chunk, 5));
  });

  tearDown(() => signer.dispose());

  Future<_Run> expectRefused(
    Map<Uri, _Answer> changes, {
    ReleaseInfo? release,
    DownloadOutcome expected = _network,
    ReleaseVerifier? verifier,
  }) async {
    final _Github github = _Github(<Uri, _Answer>{
      ...published.answers(),
      ...changes,
    });
    final _Run run = await _download(
      github,
      verifier ?? signer.verifier,
      release: release,
    );
    expect(run.outcome, expected);
    expect(run.left, isEmpty);
    expect(github.everyRequestIsAPlainGet, isTrue);
    return run;
  }

  test("release files download only from GitHub's hosts", () async {
    final _Github github = _Github(published.answers());
    final _Run verified = await _download(github, signer.verifier);
    expect(verified.outcome, DownloadVerified(verified.file));
    expect(verified.file.readAsBytesSync(), published.setup);
    expect(verified.left.map((FileSystemEntity entry) => entry.path), <String>[
      verified.file.path,
    ]);
    expect(github.requested, <Uri>[
      _github(releaseSumsName),
      _stored(releaseSumsName),
      _github(releaseSignatureName),
      _stored(releaseSignatureName),
      _github(_assetName),
      _stored(_assetName),
    ]);
    expect(github.everyRequestIsAPlainGet, isTrue);
    expect(verified.events.last, const InstallVerifying());
    expect(
      verified.progress.last,
      InstallDownloading(published.setup.length, published.setup.length),
    );

    for (final int status in <int>[301, 303, 307, 308]) {
      final _Github moved = _Github(<Uri, _Answer>{
        ...published.answers(),
        _github(_assetName): _redirect(_stored(_assetName), status: status),
      });
      final _Run run = await _download(moved, signer.verifier);
      expect(run.outcome, DownloadVerified(run.file), reason: '$status');
    }

    final Uri older = Uri.parse(
      'https://objects.githubusercontent.com/github-production-release-asset-2e65be/1/$_assetName',
    );
    final _Github olderHost = _Github(<Uri, _Answer>{
      ...published.answers(),
      _github(_assetName): _redirect(older),
      older: _body(published.setup),
    });
    final _Run fromOlderHost = await _download(olderHost, signer.verifier);
    expect(fromOlderHost.outcome, DownloadVerified(fromOlderHost.file));

    final Uri mirror = Uri.parse(
      'https://github.com/SatanshuMishra/field-notes/mirror/$_assetName',
    );
    final _Github relative = _Github(<Uri, _Answer>{
      ...published.answers(),
      _github(_assetName): _redirect(
        Uri.parse('/SatanshuMishra/field-notes/mirror/$_assetName'),
      ),
      mirror: _body(published.setup),
    });
    final _Run fromRelative = await _download(relative, signer.verifier);
    expect(fromRelative.outcome, DownloadVerified(fromRelative.file));
    expect(relative.requested.last, mirror);

    for (final String elsewhere in <String>[
      'https://evil.example.com/$_assetName',
      'https://github.com.evil.example/$_assetName',
      'https://release-assets.githubusercontent.com.evil.example/$_assetName',
      'https://evilgithub.com/$_assetName',
      'https://githubusercontent.com/$_assetName',
      'https://user@release-assets.githubusercontent.com/$_assetName',
      'https://release-assets.githubusercontent.com:8443/$_assetName',
      'http://release-assets.githubusercontent.com/$_assetName',
      'http://release-assets.githubusercontent.com:443/$_assetName',
      'ftp://github.com/$_assetName',
    ]) {
      final Uri target = Uri.parse(elsewhere);
      final _Github redirected = _Github(<Uri, _Answer>{
        ...published.answers(),
        _github(_assetName): _redirect(target),
        target: _body(published.setup),
      });
      final _Run run = await _download(redirected, signer.verifier);
      expect(run.outcome, _network, reason: elsewhere);
      expect(run.left, isEmpty, reason: elsewhere);
      expect(redirected.requested, isNot(contains(target)), reason: elsewhere);
      expect(redirected.requested.last, _github(_assetName));
      expect(run.events, isEmpty, reason: elsewhere);
    }

    final Uri evilSums = Uri.parse('https://evil.example.com/$releaseSumsName');
    final _Run sumsElsewhere = await expectRefused(<Uri, _Answer>{
      _github(releaseSumsName): _redirect(evilSums),
      evilSums: _body(published.sums),
    });
    expect(sumsElsewhere.events, isEmpty);

    final Uri plain = Uri.parse(
      'http://github.com/SatanshuMishra/field-notes/releases/download/v1.2.0/$_assetName',
    );
    final _Github plainGithub = _Github(<Uri, _Answer>{
      ...published.answers(),
      plain: _body(published.setup),
    });
    final _Run overHttp = await _download(
      plainGithub,
      signer.verifier,
      release: _release(assetUrl: plain),
    );
    expect(overHttp.outcome, _network);
    expect(overHttp.left, isEmpty);
    expect(
      plainGithub.requested.where((Uri url) => url.scheme != 'https'),
      isEmpty,
    );
    final Uri plainSums = Uri.parse(
      'http://github.com/SatanshuMishra/field-notes/releases/download/v1.2.0/$releaseSumsName',
    );
    final _Github plainSumsGithub = _Github(<Uri, _Answer>{
      ...published.answers(),
      plainSums: _body(published.sums),
    });
    final _Run sumsOverHttp = await _download(
      plainSumsGithub,
      signer.verifier,
      release: _release(sumsUrl: plainSums),
    );
    expect(sumsOverHttp.outcome, _network);
    expect(plainSumsGithub.requested, isEmpty);

    Map<Uri, _Answer> chain(int redirects) => <Uri, _Answer>{
      ...published.answers(),
      for (int index = 0; index < redirects; index++)
        _hop(index): _redirect(_hop(index + 1)),
      _hop(redirects): _body(published.setup),
    };
    final _Github fiveHops = _Github(chain(5));
    final _Run afterFive = await _download(
      fiveHops,
      signer.verifier,
      release: _release(assetUrl: _hop(0)),
    );
    expect(afterFive.outcome, DownloadVerified(afterFive.file));
    expect(fiveHops.requested.sublist(4), <Uri>[
      for (int index = 0; index <= 5; index++) _hop(index),
    ]);
    final _Github sixHops = _Github(chain(6));
    final _Run afterSix = await _download(
      sixHops,
      signer.verifier,
      release: _release(assetUrl: _hop(0)),
    );
    expect(afterSix.outcome, _network);
    expect(afterSix.left, isEmpty);
    expect(sixHops.requested.sublist(4), <Uri>[
      for (int index = 0; index <= 5; index++) _hop(index),
    ]);
    expect(sixHops.requested, isNot(contains(_hop(6))));

    final _Run sumsClaimTooLong = await expectRefused(<Uri, _Answer>{
      _stored(releaseSumsName): _body(
        published.sums,
        claimedLength: releaseSumsCap + 1,
      ),
    });
    expect(sumsClaimTooLong.events, isEmpty);
    final List<int> longSums = <int>[
      ...published.sums,
      ...List<int>.filled(releaseSumsCap + 1 - published.sums.length, 0x23),
    ];
    final _Github longSumsGithub = _Github(<Uri, _Answer>{
      ...published.answers(),
      _stored(releaseSumsName): _body(longSums, withLength: false),
    });
    final _Run sumsTooLong = await _download(longSumsGithub, signer.verifier);
    expect(sumsTooLong.outcome, _network);
    expect(longSumsGithub.requested, isNot(contains(_github(_assetName))));
    expect(sumsTooLong.left, isEmpty);
    final String sumsText = utf8.decode(published.sums);
    final List<int> fullSums = utf8.encode(
      '$sumsText${'#' * (releaseSumsCap - sumsText.length - 1)}\n',
    );
    expect(fullSums.length, releaseSumsCap);
    final _Github fullSumsGithub = _Github(
      _Published(signer, setup: published.setup, sums: fullSums).answers(),
    );
    final _Run atSumsCap = await _download(fullSumsGithub, signer.verifier);
    expect(atSumsCap.outcome, DownloadVerified(atSumsCap.file));
    await expectRefused(<Uri, _Answer>{
      _stored(releaseSignatureName): _body(
        utf8.encode(published.signature),
        claimedLength: releaseSumsCap + 1,
      ),
    });
    await expectRefused(<Uri, _Answer>{
      _stored(releaseSignatureName): _body(
        List<int>.filled(releaseSumsCap + 1, 0x41),
        withLength: false,
      ),
    });

    final _Run setupClaimTooLong = await expectRefused(<Uri, _Answer>{
      _stored(_assetName): _body(
        published.setup,
        claimedLength: releaseInstallerCap + 1,
      ),
    });
    expect(setupClaimTooLong.events, isEmpty);
    final _Run setupTooLong = await expectRefused(<Uri, _Answer>{
      _stored(_assetName): _streamed(
        () => Stream<List<int>>.fromIterable(<List<int>>[
          _bytes(_chunk, 1),
          _Hollow(releaseInstallerCap - _chunk + 1),
        ]),
      ),
    });
    expect(setupTooLong.events, const <InstallEvent>[
      InstallDownloading(_chunk, null),
    ]);

    final List<int> eight = _bytes(8 * _chunk, 9);
    final _Published small = _Published(signer, setup: eight);
    final _Run everyChunk = await _download(
      _Github(small.answers()),
      signer.verifier,
      interval: Duration.zero,
    );
    expect(everyChunk.events, <InstallEvent>[
      for (int count = 1; count <= 8; count++)
        InstallDownloading(count * _chunk, eight.length),
      const InstallVerifying(),
    ]);
    final _Run throttled = await _download(
      _Github(small.answers()),
      signer.verifier,
      interval: const Duration(hours: 1),
    );
    expect(throttled.events, <InstallEvent>[
      InstallDownloading(_chunk, eight.length),
      InstallDownloading(eight.length, eight.length),
      const InstallVerifying(),
    ]);
    final _Run unknownSize = await _download(
      _Github(<Uri, _Answer>{
        ...small.answers(),
        _stored(_assetName): _body(eight, withLength: false),
      }),
      signer.verifier,
      interval: const Duration(hours: 1),
    );
    expect(unknownSize.outcome, DownloadVerified(unknownSize.file));
    expect(unknownSize.events, <InstallEvent>[
      const InstallDownloading(_chunk, null),
      InstallDownloading(eight.length, null),
      const InstallVerifying(),
    ]);
    Stream<List<int>> trickle() async* {
      for (final List<int> piece in _pieces(eight, _chunk)) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        yield piece;
      }
    }

    final Stopwatch watch = Stopwatch()..start();
    final _Run paced = await _download(
      _Github(<Uri, _Answer>{
        ...small.answers(),
        _stored(_assetName): _streamed(trickle, length: eight.length),
      }),
      signer.verifier,
    );
    watch.stop();
    expect(paced.outcome, DownloadVerified(paced.file));
    expect(
      paced.progress.length,
      lessThanOrEqualTo(watch.elapsedMilliseconds ~/ 100 + 2),
    );
    expect(paced.progress.last, InstallDownloading(eight.length, eight.length));

    final _Github noSignature = _Github(published.answers());
    final _Run withoutSignature = await _download(
      noSignature,
      signer.verifier,
      release: _release(withSignature: false),
    );
    expect(withoutSignature.outcome, _notReady);
    expect(noSignature.requested, isEmpty);
    for (final ReleaseInfo halfFilled in <ReleaseInfo>[
      _release(withSums: false),
      _release(withAsset: false),
    ]) {
      final _Github untouched = _Github(published.answers());
      final _Run run = await _download(
        untouched,
        signer.verifier,
        release: halfFilled,
      );
      expect(run.outcome, _notReady);
      expect(untouched.requested, isEmpty);
      expect(run.left, isEmpty);
    }
    final _Github escaping = _Github(published.answers());
    final _Run escaped = await _download(
      escaping,
      signer.verifier,
      assetName: '../$_assetName',
    );
    expect(escaped.outcome, _notReady);
    expect(escaping.requested, isEmpty);

    for (final int status in <int>[404, 500, 204]) {
      final _Run run = await expectRefused(<Uri, _Answer>{
        _stored(_assetName): _status(status),
      });
      expect(run.events, isEmpty, reason: '$status');
    }
    await expectRefused(<Uri, _Answer>{_stored(releaseSumsName): _status(500)});
    await expectRefused(<Uri, _Answer>{
      _github(_assetName): () async => http.StreamedResponse(
        Stream<List<int>>.fromIterable(const <List<int>>[]),
        302,
      ),
    });
    await expectRefused(<Uri, _Answer>{
      _stored(_assetName): () async =>
          throw http.ClientException('connection reset'),
    });
    await expectRefused(<Uri, _Answer>{
      _stored(_assetName): () async =>
          throw const HandshakeException('bad certificate'),
    });
    Stream<List<int>> broken() async* {
      yield _bytes(_chunk, 2);
      yield _bytes(_chunk, 3);
      throw const SocketException('connection reset');
    }

    final _Run interrupted = await expectRefused(<Uri, _Answer>{
      _stored(_assetName): _streamed(broken, length: published.setup.length),
    });
    expect(interrupted.progress, isNotEmpty);
    expect(interrupted.events, isNot(contains(const InstallVerifying())));
    await expectRefused(<Uri, _Answer>{
      _stored(_assetName): _body(
        published.setup.sublist(0, 4 * _chunk),
        claimedLength: published.setup.length,
      ),
    });

    final List<int> tampered = <int>[...published.setup];
    tampered[100] = tampered[100] ^ 0x01;
    final _Run altered = await expectRefused(<Uri, _Answer>{
      _stored(_assetName): _body(tampered),
    }, expected: _unverified);
    expect(altered.events.last, const InstallVerifying());
    expect(altered.file.existsSync(), isFalse);
    final _Signer stranger = _Signer();
    addTearDown(stranger.dispose);
    final _Run foreign = await expectRefused(
      const <Uri, _Answer>{},
      expected: _unverified,
      verifier: stranger.verifier,
    );
    expect(foreign.events.last, const InstallVerifying());
    await expectRefused(<Uri, _Answer>{
      _stored(releaseSignatureName): _body(
        utf8.encode(stranger.sign(published.sums)),
      ),
    }, expected: _unverified);
    await expectRefused(<Uri, _Answer>{
      _stored(releaseSignatureName): _body(<int>[0xff, 0xfe, 0x00]),
    }, expected: _unverified);
  });

  test('a download that stops answering fails and leaves no file', () async {
    final StreamController<List<int>> stalled = StreamController<List<int>>();
    addTearDown(stalled.close);
    stalled.add(_bytes(_chunk, 4));
    final Completer<http.StreamedResponse> never =
        Completer<http.StreamedResponse>();

    final _Github quietBody = _Github(<Uri, _Answer>{
      ...published.answers(),
      _stored(_assetName): () async => http.StreamedResponse(
        stalled.stream,
        200,
        contentLength: published.setup.length,
      ),
    });
    final _Run bodyStalled = await _download(
      quietBody,
      signer.verifier,
      timeout: const Duration(milliseconds: 200),
    );
    expect(bodyStalled.outcome, _network);
    expect(bodyStalled.left, isEmpty);
    expect(bodyStalled.progress, const <InstallDownloading>[
      InstallDownloading(_chunk, 40 * _chunk),
    ]);

    final _Github quietHeaders = _Github(<Uri, _Answer>{
      ...published.answers(),
      _stored(_assetName): () => never.future,
    });
    final _Run headersStalled = await _download(
      quietHeaders,
      signer.verifier,
      timeout: const Duration(milliseconds: 200),
    );
    expect(headersStalled.outcome, _network);
    expect(headersStalled.left, isEmpty);
    expect(headersStalled.events, isEmpty);
  });
}
