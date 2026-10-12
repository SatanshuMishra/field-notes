import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitType;

import 'package:field_notes/data/updates/release_download.dart';
import 'package:field_notes/domain/updates/release_info.dart';
import 'package:field_notes/domain/updates/update_installer.dart';
import 'package:flutter/services.dart';

const List<String> windowsSilentUpdateArguments = <String>[
  '/VERYSILENT',
  '/SUPPRESSMSGBOXES',
  '/NORESTART',
  '/CLOSEAPPLICATIONS',
  '/RELAUNCH=1',
];

const Duration windowsRestartSplashDelay = Duration(milliseconds: 600);

Future<Directory> _newUpdateFolder() =>
    Directory.systemTemp.createTemp('field-notes-update-');

Future<void> _startDetachedProcess(
  String executable,
  List<String> arguments,
) async {
  await Process.start(executable, arguments, mode: ProcessStartMode.detached);
}

Future<void> _exitApplication() async {
  await ServicesBinding.instance.exitApplication(AppExitType.cancelable);
}

final class WindowsUpdateInstaller implements UpdateInstaller {
  WindowsUpdateInstaller({
    required this._downloader,
    this._makeTempDirectory = _newUpdateFolder,
    this._startDetached = _startDetachedProcess,
    this._requestExit = _exitApplication,
    this.splashDelay = windowsRestartSplashDelay,
  });

  final Duration splashDelay;
  final ReleaseDownloader _downloader;
  final Future<Directory> Function() _makeTempDirectory;
  final Future<void> Function(String executable, List<String> arguments)
  _startDetached;
  final Future<void> Function() _requestExit;

  @override
  InstallRoute get route => InstallRoute.restartInPlace;

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
    final String? assetName = platformAssetName(
      TargetPlatform.windows,
      release,
    );
    if (assetName == null) {
      events.add(const InstallFailed(InstallFailure.notReady));
      return;
    }
    final Directory folder;
    try {
      folder = await _makeTempDirectory();
    } on FileSystemException {
      events.add(const InstallFailed(InstallFailure.installer));
      return;
    }
    final DownloadOutcome outcome;
    try {
      outcome = await _downloader.downloadVerified(
        release: release,
        assetName: assetName,
        into: folder,
        onEvent: events.add,
      );
    } catch (_) {
      await _remove(folder);
      rethrow;
    }
    switch (outcome) {
      case DownloadFailed(:final InstallFailure failure):
        await _remove(folder);
        events.add(InstallFailed(failure));
      case DownloadVerified(:final File file):
        await _start(file, folder, events);
    }
  }

  Future<void> _start(
    File setup,
    Directory folder,
    StreamController<InstallEvent> events,
  ) async {
    if (!events.hasListener) {
      await _remove(folder);
      return;
    }
    events.add(const InstallRestarting());
    await Future<void>.delayed(splashDelay);
    try {
      await _startDetached(setup.path, windowsSilentUpdateArguments);
    } on Exception {
      await _remove(folder);
      events.add(const InstallFailed(InstallFailure.installer));
      return;
    }
    await _requestExit();
  }

  static Future<void> _remove(Directory folder) async {
    try {
      if (await folder.exists()) {
        await folder.delete(recursive: true);
      }
    } on FileSystemException {
      return;
    }
  }
}
