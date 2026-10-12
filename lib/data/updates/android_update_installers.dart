import 'dart:async';
import 'dart:io';

import 'package:field_notes/data/links/link_opener.dart';
import 'package:field_notes/data/updates/release_download.dart';
import 'package:field_notes/domain/updates/release_info.dart';
import 'package:field_notes/domain/updates/update_installer.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String appUpdateChannelName = 'field_notes/app_update';
const MethodChannel appUpdateChannel = MethodChannel(appUpdateChannelName);
const String androidApplicationId = 'dev.satanshumishra.field_notes';
const String updateCacheFolderName = 'updates';

final Uri googlePlayAppLink = Uri.parse(
  'market://details?id=$androidApplicationId',
);
final Uri googlePlayWebLink = Uri.parse(
  'https://play.google.com/store/apps/details?id=$androidApplicationId',
);

Future<Directory> updateCacheDirectory() async {
  final Directory cache = await getApplicationCacheDirectory();
  return Directory(p.join(cache.path, updateCacheFolderName));
}

Future<bool> androidCanSelfUpdate() async {
  try {
    return await appUpdateChannel.invokeMethod<bool>('canSelfUpdate') ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

final class GooglePlayInstaller implements UpdateInstaller {
  const GooglePlayInstaller({this._openLink = openInBrowser});

  final LinkOpener _openLink;

  @override
  InstallRoute get route => InstallRoute.googlePlay;

  @override
  Stream<InstallEvent> install(ReleaseInfo release) async* {
    for (final Uri listing in <Uri>[googlePlayAppLink, googlePlayWebLink]) {
      if (await _open(listing)) {
        yield const InstallHandedOff();
        return;
      }
    }
    yield const InstallFailed(InstallFailure.installer);
  }

  Future<bool> _open(Uri listing) async {
    try {
      return await _openLink(listing);
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

final class ApkUpdateInstaller implements UpdateInstaller {
  ApkUpdateInstaller({
    required this._downloader,
    this._cacheDirectory = updateCacheDirectory,
    this._channel = appUpdateChannel,
  });

  final ReleaseDownloader _downloader;
  final Future<Directory> Function() _cacheDirectory;
  final MethodChannel _channel;

  @override
  InstallRoute get route => InstallRoute.systemInstaller;

  @override
  Stream<InstallEvent> install(ReleaseInfo release) {
    late final StreamController<InstallEvent> events;
    events = StreamController<InstallEvent>(
      onListen: () => unawaited(
        _install(
          release,
          events,
        ).catchError(events.addError).whenComplete(events.close),
      ),
    );
    return events.stream;
  }

  Future<void> _install(
    ReleaseInfo release,
    StreamController<InstallEvent> events,
  ) async {
    final bool? allowed = await _canRequestInstalls();
    if (allowed == null) {
      events.add(const InstallFailed(InstallFailure.installer));
      return;
    }
    if (!allowed) {
      await _openInstallPermission();
      events.add(const InstallFailed(InstallFailure.permission));
      return;
    }
    final String? assetName = platformAssetName(
      TargetPlatform.android,
      release,
    );
    if (assetName == null) {
      events.add(const InstallFailed(InstallFailure.notReady));
      return;
    }
    final Directory folder;
    try {
      folder = await _emptyCache();
    } on FileSystemException {
      events.add(const InstallFailed(InstallFailure.installer));
      return;
    } on MissingPlatformDirectoryException {
      events.add(const InstallFailed(InstallFailure.installer));
      return;
    }
    final DownloadOutcome outcome = await _downloader.downloadVerified(
      release: release,
      assetName: assetName,
      into: folder,
      onEvent: events.add,
    );
    switch (outcome) {
      case DownloadFailed(:final InstallFailure failure):
        events.add(InstallFailed(failure));
      case DownloadVerified(:final File file):
        await _handOff(file, events);
    }
  }

  Future<bool?> _canRequestInstalls() async {
    try {
      return await _channel.invokeMethod<bool>('canRequestInstalls') ?? false;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _openInstallPermission() async {
    try {
      await _channel.invokeMethod<void>('openInstallPermission');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<Directory> _emptyCache() async {
    final Directory folder = await _cacheDirectory();
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
    return folder.create(recursive: true);
  }

  Future<void> _handOff(File apk, StreamController<InstallEvent> events) async {
    if (!events.hasListener) {
      await _remove(apk);
      return;
    }
    final bool committed = await _commit(apk);
    await _remove(apk);
    events.add(
      committed
          ? const InstallHandedOff()
          : const InstallFailed(InstallFailure.installer),
    );
  }

  Future<bool> _commit(File apk) async {
    try {
      return await _channel.invokeMethod<bool>('install', <String, Object?>{
            'path': apk.path,
          }) ==
          true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> _remove(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      return;
    }
  }
}
