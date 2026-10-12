import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:field_notes/data/updates/release_download.dart';
import 'package:field_notes/data/updates/release_verifier.dart';
import 'package:field_notes/data/updates/windows_update_installer.dart';
import 'package:field_notes/domain/updates/app_version.dart';
import 'package:field_notes/domain/updates/release_info.dart';
import 'package:field_notes/domain/updates/update_installer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sodium/sodium.dart';

const String _setupName = 'field-notes-1.2.0-windows-x64-setup.exe';
const String _dmgName = 'field-notes-1.2.0-macos.dmg';
const String _downloads =
    'https://github.com/SatanshuMishra/field-notes/releases/download/v1.2.0/';
const int _chunk = 1024;
const int _setupLength = 4 * _chunk;
const String _started = 'started';
const String _exitRequested = 'exit requested';

typedef _Answer = Future<http.StreamedResponse> Function();

Uri _github(String name) => Uri.parse('$_downloads$name');

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 31 + seed) % 256);

List<List<int>> _pieces(List<int> bytes) => <List<int>>[
  for (int start = 0; start < bytes.length; start += _chunk)
    bytes.sublist(
      start,
      start + _chunk > bytes.length ? bytes.length : start + _chunk,
    ),
];

_Answer _status(int code) =>
    () async => http.StreamedResponse(
      Stream<List<int>>.fromIterable(const <List<int>>[]),
      code,
    );

_Answer _body(List<int> bytes) =>
    () async => http.StreamedResponse(
      Stream<List<int>>.fromIterable(_pieces(bytes)),
      200,
      contentLength: bytes.length,
    );

_Answer _streamed(Stream<List<int>> body, int length) =>
    () async => http.StreamedResponse(body, 200, contentLength: length);

ReleaseInfo _release({bool withSetup = true, bool withSignature = true}) =>
    ReleaseInfo(
      version: AppVersion.tryParse('1.2.0')!,
      tag: 'v1.2.0',
      publishedAt: DateTime.utc(2026, 10, 11, 9),
      notes: ReleaseNotes.empty,
      pageUrl: Uri.parse(
        'https://github.com/SatanshuMishra/field-notes/releases/tag/v1.2.0',
      ),
      assets: <ReleaseAsset>[
        ReleaseAsset(name: _dmgName, url: _github(_dmgName), size: 2048),
        if (withSetup)
          ReleaseAsset(
            name: _setupName,
            url: _github(_setupName),
            size: _setupLength,
          ),
        ReleaseAsset(
          name: releaseSumsName,
          url: _github(releaseSumsName),
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
  _Published(this.signer, this.setup)
    : sums = utf8.encode(
        '${sha256.convert(utf8.encode('mac'))}  $_dmgName\n'
        '${sha256.convert(setup)}  $_setupName\n',
      );

  final _Signer signer;
  final List<int> setup;
  final List<int> sums;

  Map<Uri, _Answer> answers() => <Uri, _Answer>{
    _github(releaseSumsName): _body(sums),
    _github(releaseSignatureName): _body(utf8.encode('${signer.sign(sums)}\n')),
    _github(_setupName): _body(setup),
  };
}

final class _Github {
  _Github(Map<Uri, _Answer> answers)
    : _answers = Map<Uri, _Answer>.unmodifiable(answers);

  final Map<Uri, _Answer> _answers;
  final List<Uri> requested = <Uri>[];

  late final MockClient client = MockClient.streaming((
    http.BaseRequest request,
    http.ByteStream _,
  ) {
    requested.add(request.url);
    final _Answer? answer = _answers[request.url];
    return answer == null ? _status(404)() : answer();
  });
}

final class _Start {
  const _Start(this.executable, this.arguments, this.bytes);

  final String executable;
  final List<String> arguments;
  final List<int>? bytes;
}

final class _Machine {
  _Machine(this.root, {this.startFailure, this.folderFailure});

  final Directory root;
  final Exception? startFailure;
  final FileSystemException? folderFailure;
  final Stopwatch clock = Stopwatch()..start();
  final List<Object> timeline = <Object>[];
  final List<Duration> times = <Duration>[];
  final List<Directory> folders = <Directory>[];
  final List<_Start> starts = <_Start>[];

  void record(Object entry) {
    timeline.add(entry);
    times.add(clock.elapsed);
  }

  Duration at(Object entry) => times[timeline.indexOf(entry)];

  Future<Directory> makeTempDirectory() async {
    final FileSystemException? failure = folderFailure;
    if (failure != null) {
      throw failure;
    }
    final Directory folder = await root.createTemp('field-notes-update-');
    folders.add(folder);
    return folder;
  }

  Future<void> startDetached(String executable, List<String> arguments) async {
    final File setup = File(executable);
    starts.add(
      _Start(
        executable,
        List<String>.unmodifiable(arguments),
        setup.existsSync() ? setup.readAsBytesSync() : null,
      ),
    );
    record(_started);
    final Exception? failure = startFailure;
    if (failure != null) {
      throw failure;
    }
  }

  Future<void> requestExit() async => record(_exitRequested);
}

WindowsUpdateInstaller _installer(
  _Machine machine,
  _Github github,
  ReleaseVerifier verifier, {
  Duration splashDelay = Duration.zero,
}) => WindowsUpdateInstaller(
  downloader: ReleaseDownloader(
    client: github.client,
    verifier: verifier,
    progressInterval: Duration.zero,
  ),
  makeTempDirectory: machine.makeTempDirectory,
  startDetached: machine.startDetached,
  requestExit: machine.requestExit,
  splashDelay: splashDelay,
);

Future<void> _install(
  WindowsUpdateInstaller installer,
  _Machine machine, {
  ReleaseInfo? release,
}) async {
  await for (final InstallEvent event in installer.install(
    release ?? _release(),
  )) {
    machine.record(event);
  }
}

List<InstallEvent> _downloaded() => <InstallEvent>[
  for (int count = 1; count <= _setupLength ~/ _chunk; count++)
    InstallDownloading(count * _chunk, _setupLength),
  const InstallVerifying(),
];

void main() {
  late Directory root;
  late _Signer signer;
  late _Published published;

  setUp(() {
    root = Directory.systemTemp.createTempSync('windows_update_installer_test');
    signer = _Signer();
    published = _Published(signer, _bytes(_setupLength, 7));
  });

  tearDown(() {
    signer.dispose();
    root.deleteSync(recursive: true);
  });

  test('Windows installs a verified setup silently and relaunches', () async {
    final _Github github = _Github(published.answers());
    final _Machine machine = _Machine(root);
    final WindowsUpdateInstaller installer = _installer(
      machine,
      github,
      signer.verifier,
      splashDelay: const Duration(milliseconds: 150),
    );
    expect(installer.route, InstallRoute.restartInPlace);

    await _install(installer, machine);

    expect(machine.timeline, <Object>[
      ..._downloaded(),
      const InstallRestarting(),
      _started,
      _exitRequested,
    ]);
    final Directory folder = machine.folders.single;
    final _Start start = machine.starts.single;
    expect(start.executable, p.join(folder.path, _setupName));
    expect(start.arguments, <String>[
      '/VERYSILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      '/CLOSEAPPLICATIONS',
      '/RELAUNCH=1',
    ]);
    expect(start.bytes, published.setup);
    expect(File(start.executable).existsSync(), isTrue);
    expect(
      machine.at(_started) - machine.at(const InstallRestarting()),
      greaterThanOrEqualTo(const Duration(milliseconds: 140)),
    );
    expect(github.requested, <Uri>[
      _github(releaseSumsName),
      _github(releaseSignatureName),
      _github(_setupName),
    ]);

    final _Machine again = _Machine(root);
    await _install(_installer(again, github, signer.verifier), again);
    expect(again.timeline.last, _exitRequested);
    expect(again.folders.single.path, isNot(folder.path));
    expect(
      again.starts.single.executable,
      p.join(again.folders.single.path, _setupName),
    );

    final List<int> tampered = <int>[...published.setup];
    tampered[100] = tampered[100] ^ 0x01;
    final _Machine fooled = _Machine(root);
    await _install(
      _installer(
        fooled,
        _Github(<Uri, _Answer>{
          ...published.answers(),
          _github(_setupName): _body(tampered),
        }),
        signer.verifier,
      ),
      fooled,
    );
    expect(fooled.timeline, <Object>[
      ..._downloaded(),
      const InstallFailed(InstallFailure.verification),
    ]);
    expect(fooled.starts, isEmpty);
    expect(fooled.folders.single.existsSync(), isFalse);

    final _Signer stranger = _Signer();
    addTearDown(stranger.dispose);
    final _Machine foreign = _Machine(root);
    await _install(
      _installer(foreign, _Github(published.answers()), stranger.verifier),
      foreign,
    );
    expect(foreign.timeline, <Object>[
      ..._downloaded(),
      const InstallFailed(InstallFailure.verification),
    ]);
    expect(foreign.starts, isEmpty);
    expect(foreign.folders.single.existsSync(), isFalse);

    for (final ReleaseInfo unfinished in <ReleaseInfo>[
      _release(withSetup: false),
      _release(withSignature: false),
    ]) {
      final _Github untouched = _Github(published.answers());
      final _Machine waiting = _Machine(root);
      await _install(
        _installer(waiting, untouched, signer.verifier),
        waiting,
        release: unfinished,
      );
      expect(waiting.timeline, const <Object>[
        InstallFailed(InstallFailure.notReady),
      ]);
      expect(untouched.requested, isEmpty);
      expect(waiting.folders.single.existsSync(), isFalse);
    }

    Stream<List<int>> broken() async* {
      yield _bytes(_chunk, 2);
      yield _bytes(_chunk, 3);
      throw const SocketException('connection reset');
    }

    final List<(Uri, _Answer, List<Object>)> outages =
        <(Uri, _Answer, List<Object>)>[
          (
            _github(_setupName),
            () async => throw http.ClientException('connection reset'),
            const <Object>[InstallFailed(InstallFailure.network)],
          ),
          (
            _github(releaseSumsName),
            _status(503),
            const <Object>[InstallFailed(InstallFailure.network)],
          ),
          (
            _github(_setupName),
            _streamed(broken(), _setupLength),
            const <Object>[
              InstallDownloading(_chunk, _setupLength),
              InstallDownloading(2 * _chunk, _setupLength),
              InstallFailed(InstallFailure.network),
            ],
          ),
        ];
    for (final (Uri url, _Answer answer, List<Object> expected) in outages) {
      final _Machine stranded = _Machine(root);
      await _install(
        _installer(
          stranded,
          _Github(<Uri, _Answer>{...published.answers(), url: answer}),
          signer.verifier,
        ),
        stranded,
      );
      expect(stranded.timeline, expected, reason: '$url');
      expect(stranded.starts, isEmpty);
      expect(stranded.folders.single.existsSync(), isFalse);
    }

    final _Machine blocked = _Machine(
      root,
      startFailure: const ProcessException(
        _setupName,
        <String>[],
        'The system cannot find the file specified.',
        2,
      ),
    );
    await _install(
      _installer(blocked, _Github(published.answers()), signer.verifier),
      blocked,
    );
    expect(blocked.timeline, <Object>[
      ..._downloaded(),
      const InstallRestarting(),
      _started,
      const InstallFailed(InstallFailure.installer),
    ]);
    expect(blocked.folders.single.existsSync(), isFalse);

    final _Github unasked = _Github(published.answers());
    final _Machine full = _Machine(
      root,
      folderFailure: const FileSystemException('No space left on device'),
    );
    await _install(_installer(full, unasked, signer.verifier), full);
    expect(full.timeline, const <Object>[
      InstallFailed(InstallFailure.installer),
    ]);
    expect(unasked.requested, isEmpty);

    expect(
      WindowsUpdateInstaller(
        downloader: ReleaseDownloader(
          client: github.client,
          verifier: signer.verifier,
        ),
      ).splashDelay,
      const Duration(milliseconds: 600),
    );
  });

  test('an update nobody follows any more starts nothing', () async {
    final StreamController<List<int>> body = StreamController<List<int>>();
    final _Machine machine = _Machine(root);
    final WindowsUpdateInstaller installer = _installer(
      machine,
      _Github(<Uri, _Answer>{
        ...published.answers(),
        _github(_setupName): _streamed(body.stream, _setupLength),
      }),
      signer.verifier,
    );
    final Completer<void> left = Completer<void>();
    late final StreamSubscription<InstallEvent> subscription;
    subscription = installer.install(_release()).listen((InstallEvent event) {
      machine.record(event);
      if (!left.isCompleted) {
        left.complete(subscription.cancel());
      }
    });

    final List<List<int>> pieces = _pieces(published.setup);
    body.add(pieces.first);
    await left.future;
    for (final List<int> piece in pieces.skip(1)) {
      body.add(piece);
    }
    await body.close();
    final Directory folder = machine.folders.single;
    for (int wait = 0; wait < 300 && folder.existsSync(); wait++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(folder.existsSync(), isFalse);
    expect(machine.timeline, const <Object>[
      InstallDownloading(_chunk, _setupLength),
    ]);
    expect(machine.starts, isEmpty);
  });
}
