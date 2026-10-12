import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:field_notes/data/updates/android_update_installers.dart';
import 'package:field_notes/data/updates/release_download.dart';
import 'package:field_notes/data/updates/release_verifier.dart';
import 'package:field_notes/domain/updates/app_version.dart';
import 'package:field_notes/domain/updates/release_info.dart';
import 'package:field_notes/domain/updates/update_installer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sodium/sodium.dart';

const String _apkName = 'field-notes-1.2.0-android.apk';
const String _downloads =
    'https://github.com/SatanshuMishra/field-notes/releases/download/v1.2.0/';
const int _chunk = 1024;

final Uri _playApp = Uri.parse(
  'market://details?id=dev.satanshumishra.field_notes',
);
final Uri _playWeb = Uri.parse(
  'https://play.google.com/store/apps/details?id=dev.satanshumishra.field_notes',
);
final List<int> _apk = List<int>.generate(
  48 * _chunk,
  (int index) => (index * 31 + 7) % 256,
);

Uri _github(String name) => Uri.parse('$_downloads$name');

List<List<int>> _pieces(List<int> bytes) => <List<int>>[
  for (int start = 0; start < bytes.length; start += _chunk)
    bytes.sublist(
      start,
      start + _chunk > bytes.length ? bytes.length : start + _chunk,
    ),
];

ReleaseInfo _release() => ReleaseInfo(
  version: AppVersion.tryParse('1.2.0')!,
  tag: 'v1.2.0',
  publishedAt: DateTime.utc(2026, 10, 11, 9),
  notes: ReleaseNotes.empty,
  pageUrl: Uri.parse(
    'https://github.com/SatanshuMishra/field-notes/releases/tag/v1.2.0',
  ),
  assets: <ReleaseAsset>[
    ReleaseAsset(name: _apkName, url: _github(_apkName), size: _apk.length),
    ReleaseAsset(
      name: releaseSumsName,
      url: _github(releaseSumsName),
      size: 180,
    ),
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

Map<Uri, List<int>> _published(_Signer signer, {List<int>? served}) {
  final List<int> sums = utf8.encode(
    '${sha256.convert(utf8.encode('mac'))}  field-notes-1.2.0-macos.dmg\n'
    '${sha256.convert(_apk)}  $_apkName\n',
  );
  return <Uri, List<int>>{
    _github(releaseSumsName): sums,
    _github(releaseSignatureName): utf8.encode('${signer.sign(sums)}\n'),
    _github(_apkName): served ?? _apk,
  };
}

final class _Github {
  _Github(Map<Uri, List<int>> files)
    : _files = Map<Uri, List<int>>.unmodifiable(files);

  final Map<Uri, List<int>> _files;
  final List<Uri> requested = <Uri>[];

  late final MockClient client = MockClient.streaming((
    http.BaseRequest request,
    http.ByteStream _,
  ) async {
    requested.add(request.url);
    final List<int>? body = _files[request.url];
    if (body == null) {
      return http.StreamedResponse(const Stream<List<int>>.empty(), 404);
    }
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(_pieces(body)),
      200,
      contentLength: body.length,
    );
  });
}

final class _CacheOnly extends PathProviderPlatform {
  _CacheOnly(this.cache);

  final String cache;

  @override
  Future<String?> getApplicationCachePath() async => cache;
}

List<String> _methods(List<MethodCall> calls) => <String>[
  for (final MethodCall call in calls) call.method,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Android updates through Google Play or installs the verified APK',
    () async {
      final TestDefaultBinaryMessenger messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(
        () => messenger.setMockMethodCallHandler(appUpdateChannel, null),
      );
      final _Signer signer = _Signer();
      addTearDown(signer.dispose);
      final Directory root = Directory.systemTemp.createTempSync(
        'android_update_installers_test',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final Directory cache = Directory('${root.path}/updates');

      final List<MethodCall> calls = <MethodCall>[];
      bool canRequestInstalls = false;
      bool installFails = false;
      List<String> cacheAtInstall = <String>[];
      List<int> bytesAtInstall = <int>[];
      messenger.setMockMethodCallHandler(appUpdateChannel, (
        MethodCall call,
      ) async {
        calls.add(call);
        switch (call.method) {
          case 'canRequestInstalls':
            return canRequestInstalls;
          case 'openInstallPermission':
            return null;
          case 'install':
            final Object? path =
                (call.arguments as Map<Object?, Object?>)['path'];
            cacheAtInstall = <String>[
              for (final FileSystemEntity entry in cache.listSync())
                entry.uri.pathSegments.last,
            ];
            bytesAtInstall = File(path! as String).readAsBytesSync();
            if (installFails) {
              throw PlatformException(code: 'install_failed');
            }
            return true;
        }
        throw MissingPluginException();
      });

      expect(appUpdateChannelName, 'field_notes/app_update');
      expect(googlePlayAppLink, _playApp);
      expect(googlePlayWebLink, _playWeb);

      final List<Uri> opened = <Uri>[];
      Set<Uri> opens = <Uri>{};
      Set<Uri> throws = <Uri>{};
      Future<bool> openLink(Uri link) async {
        opened.add(link);
        if (throws.contains(link)) {
          throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
        }
        return opens.contains(link);
      }

      final GooglePlayInstaller play = GooglePlayInstaller(openLink: openLink);
      expect(play.route, InstallRoute.googlePlay);

      opens = <Uri>{_playApp, _playWeb};
      expect(await play.install(_release()).toList(), <InstallEvent>[
        const InstallHandedOff(),
      ]);
      expect(opened, <Uri>[_playApp]);

      opened.clear();
      opens = <Uri>{_playWeb};
      expect(await play.install(_release()).toList(), <InstallEvent>[
        const InstallHandedOff(),
      ]);
      expect(opened, <Uri>[_playApp, _playWeb]);

      opened.clear();
      throws = <Uri>{_playApp};
      expect(await play.install(_release()).toList(), <InstallEvent>[
        const InstallHandedOff(),
      ]);
      expect(opened, <Uri>[_playApp, _playWeb]);

      opened.clear();
      opens = <Uri>{};
      throws = <Uri>{};
      expect(await play.install(_release()).toList(), <InstallEvent>[
        const InstallFailed(InstallFailure.installer),
      ]);
      expect(opened, <Uri>[_playApp, _playWeb]);
      expect(calls, isEmpty);

      ApkUpdateInstaller apkInstaller(_Github github) => ApkUpdateInstaller(
        downloader: ReleaseDownloader(
          client: github.client,
          verifier: signer.verifier,
          progressInterval: Duration.zero,
        ),
        cacheDirectory: () async => cache,
      );

      final _Github github = _Github(_published(signer));
      expect(apkInstaller(github).route, InstallRoute.systemInstaller);

      expect(
        await apkInstaller(github).install(_release()).toList(),
        <InstallEvent>[const InstallFailed(InstallFailure.permission)],
      );
      expect(_methods(calls), <String>[
        'canRequestInstalls',
        'openInstallPermission',
      ]);
      expect(github.requested, isEmpty);

      calls.clear();
      canRequestInstalls = true;
      cache.createSync(recursive: true);
      File('${cache.path}/field-notes-1.1.0-android.apk')
          .writeAsBytesSync(<int>[1, 2, 3]);
      final List<InstallEvent> installed = await apkInstaller(github)
          .install(_release())
          .toList();
      final List<InstallDownloading> progress = installed
          .whereType<InstallDownloading>()
          .toList();
      expect(progress.length, greaterThan(1));
      expect(installed.sublist(0, progress.length), progress);
      expect(
        progress.map((InstallDownloading event) => event.received).toList(),
        <int>[
          for (int sent = _chunk; sent <= _apk.length; sent += _chunk) sent,
        ],
      );
      expect(progress.last, InstallDownloading(_apk.length, _apk.length));
      expect(installed.sublist(progress.length), <InstallEvent>[
        const InstallVerifying(),
        const InstallHandedOff(),
      ]);
      expect(_methods(calls), <String>['canRequestInstalls', 'install']);
      expect(calls.last.arguments, <String, Object?>{
        'path': '${cache.path}/$_apkName',
      });
      expect(cacheAtInstall, <String>[_apkName]);
      expect(bytesAtInstall, _apk);
      expect(cache.listSync(), isEmpty);
      expect(github.requested, <Uri>[
        _github(releaseSumsName),
        _github(releaseSignatureName),
        _github(_apkName),
      ]);

      calls.clear();
      final List<int> tampered = <int>[..._apk.sublist(1), 0];
      final List<InstallEvent> refused = await apkInstaller(
        _Github(_published(signer, served: tampered)),
      ).install(_release()).toList();
      expect(refused, contains(const InstallVerifying()));
      expect(refused.last, const InstallFailed(InstallFailure.verification));
      expect(refused.whereType<InstallHandedOff>(), isEmpty);
      expect(_methods(calls), <String>['canRequestInstalls']);
      expect(cache.listSync(), isEmpty);

      calls.clear();
      final List<InstallEvent> offline = await apkInstaller(
        _Github(<Uri, List<int>>{}),
      ).install(_release()).toList();
      expect(offline, <InstallEvent>[
        const InstallFailed(InstallFailure.network),
      ]);
      expect(_methods(calls), <String>['canRequestInstalls']);
      expect(cache.listSync(), isEmpty);

      calls.clear();
      installFails = true;
      final List<InstallEvent> rejected = await apkInstaller(
        _Github(_published(signer)),
      ).install(_release()).toList();
      expect(rejected.last, const InstallFailed(InstallFailure.installer));
      expect(_methods(calls), <String>['canRequestInstalls', 'install']);
      expect(bytesAtInstall, _apk);
      expect(cache.listSync(), isEmpty);

      messenger.setMockMethodCallHandler(appUpdateChannel, null);
      expect(await androidCanSelfUpdate(), isFalse);
      messenger.setMockMethodCallHandler(
        appUpdateChannel,
        (MethodCall call) async => call.method == 'canSelfUpdate',
      );
      expect(await androidCanSelfUpdate(), isTrue);
      messenger.setMockMethodCallHandler(
        appUpdateChannel,
        (MethodCall call) async => false,
      );
      expect(await androidCanSelfUpdate(), isFalse);
      messenger.setMockMethodCallHandler(
        appUpdateChannel,
        (MethodCall call) async => throw PlatformException(code: 'unavailable'),
      );
      expect(await androidCanSelfUpdate(), isFalse);

      final PathProviderPlatform previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _CacheOnly(root.path);
      addTearDown(() => PathProviderPlatform.instance = previous);
      expect((await updateCacheDirectory()).path, '${root.path}/updates');
    },
  );
}
