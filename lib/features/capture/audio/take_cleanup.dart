import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:field_notes/data/media/audio_clean_channel.dart';
import 'package:field_notes/data/media/media_work_budget.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_cleanup.dart';
import 'package:field_notes/features/capture/video/video_timeline.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum TakeKind { voice, video }

typedef AudioCleaner = Future<void> Function({
  required String input,
  required String output,
  required InputProfile profile,
  required int volume,
  IsolateRunner? run,
});

const String takeCleanupFolderPrefix = 'take-cleanup-';
const int unchangedInputVolume = 100;
const int voiceTakeBitRate = 48000;
const int videoTakeBitRate = 96000;
const String voiceCleanupStatus = 'Clearing background noise…';
const String volumeCleanupStatus = 'Adjusting the volume…';
const String _decodedName = 'decoded.wav';
const String _cleanedName = 'cleaned.wav';

class TakeCleanupAbandoned implements Exception {
  const TakeCleanupAbandoned();

  @override
  String toString() => 'TakeCleanupAbandoned';
}

class _Cleanup {
  _Cleanup({
    required this.take,
    required this.bitRate,
    required this.profile,
    required this.volume,
  });

  final File take;
  final int bitRate;
  final InputProfile profile;
  final int volume;
  Directory? folder;
  bool closed = false;

  void ensureOpen() {
    if (closed) {
      throw const TakeCleanupAbandoned();
    }
  }
}

class TakeCleanup {
  TakeCleanup({
    this._channel = const AudioCleanChannel(),
    this._cleaner = cleanAudio,
    Future<Directory> Function()? temporaryDirectory,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final AudioCleanChannel _channel;
  final AudioCleaner _cleaner;
  final Future<Directory> Function() _temporaryDirectory;
  final Random _random = Random();
  Set<String> _running = const <String>{};
  Set<String> _held = const <String>{};

  bool needsCleanup(InputProfile profile, int volume) =>
      profile != InputProfile.studio || volume != unchangedInputVolume;

  Future<File> clean(
    File take, {
    required TakeKind kind,
    required InputProfile profile,
    required int volume,
    required Duration duration,
  }) async {
    if (!needsCleanup(profile, volume) || duration > videoHardCap) {
      return take;
    }
    final _Cleanup cleanup = _Cleanup(
      take: take,
      bitRate: kind == TakeKind.voice ? voiceTakeBitRate : videoTakeBitRate,
      profile: profile,
      volume: volume,
    );
    final Future<File> work = _perform(cleanup);
    File? cleaned;
    try {
      cleaned = await work.timeout(mediaWorkBudget(duration));
    } on Object catch (error, stackTrace) {
      debugPrint('Take cleanup gave up: $error\n$stackTrace');
    }
    final Directory? folder = _close(cleanup);
    if (cleaned != null && folder != null) {
      _held = <String>{..._held, folder.path};
      return cleaned;
    }
    await _deleteFolder(folder);
    unawaited(_deleteWhenSettled(work, folder));
    return take;
  }

  Future<void> release(File cleaned) async {
    final String folder = p.normalize(cleaned.parent.path);
    if (!_held.contains(folder)) {
      return;
    }
    _held = _held.difference(<String>{folder});
    await _deleteFolder(Directory(folder));
  }

  Future<File> _perform(_Cleanup cleanup) async {
    final Directory temporary = await _temporaryDirectory();
    final Directory folder = _reserve(cleanup, temporary);
    await _sweep(temporary);
    cleanup.ensureOpen();
    await folder.create();
    final String decoded = p.join(folder.path, _decodedName);
    final String cleanedAudio = p.join(folder.path, _cleanedName);
    final String output = p.join(folder.path, p.basename(cleanup.take.path));
    cleanup.ensureOpen();
    await _channel.decodeAudio(cleanup.take.path, decoded);
    cleanup.ensureOpen();
    await _cleaner(
      input: decoded,
      output: cleanedAudio,
      profile: cleanup.profile,
      volume: cleanup.volume,
    );
    await _deleteFile(decoded);
    cleanup.ensureOpen();
    final File written = await _channel.replaceAudio(
      cleanup.take.path,
      cleanedAudio,
      output,
      cleanup.bitRate,
    );
    await _deleteFile(cleanedAudio);
    return written;
  }

  Directory _reserve(_Cleanup cleanup, Directory temporary) {
    cleanup.ensureOpen();
    final Directory folder = Directory(
      p.normalize(
        p.join(temporary.path, '$takeCleanupFolderPrefix${_uniqueId()}'),
      ),
    );
    cleanup.folder = folder;
    _running = <String>{..._running, folder.path};
    return folder;
  }

  Directory? _close(_Cleanup cleanup) {
    cleanup.closed = true;
    final Directory? folder = cleanup.folder;
    if (folder != null) {
      _running = _running.difference(<String>{folder.path});
    }
    return folder;
  }

  String _uniqueId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${_random.nextInt(1 << 32).toRadixString(36)}';

  Future<void> _sweep(Directory temporary) async {
    final List<FileSystemEntity> entries;
    try {
      entries = await temporary.list(followLinks: false).toList();
    } on FileSystemException catch (error, stackTrace) {
      debugPrint(
        'Take cleanup could not list ${temporary.path}: '
        '$error\n$stackTrace',
      );
      return;
    }
    for (final FileSystemEntity entry in entries) {
      final String path = p.normalize(entry.path);
      if (entry is Directory &&
          p.basename(path).startsWith(takeCleanupFolderPrefix) &&
          !_running.contains(path) &&
          !_held.contains(path)) {
        await _deleteFolder(entry);
      }
    }
  }

  Future<void> _deleteWhenSettled(Future<File> work, Directory? folder) async {
    try {
      await work;
    } on Object catch (error) {
      debugPrint('A take cleanup that was given up settled: $error');
    }
    await _deleteFolder(folder);
  }

  Future<void> _deleteFolder(Directory? folder) async {
    if (folder == null) {
      return;
    }
    try {
      if (await folder.exists()) {
        await folder.delete(recursive: true);
      }
    } on FileSystemException catch (error, stackTrace) {
      debugPrint(
        'Take cleanup could not delete ${folder.path}: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _deleteFile(String path) async {
    final File file = File(path);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException catch (error, stackTrace) {
      debugPrint('Take cleanup could not delete $path: $error\n$stackTrace');
    }
  }
}

AppSettings takeCleanupSettings(WidgetRef ref) =>
    ref.exists(appSettingsProvider)
    ? ref.read(appSettingsProvider).value ?? AppSettings.defaults
    : AppSettings.defaults;

String? takeCleanupStatus(AppSettings settings) =>
    switch (settings.inputProfile) {
      InputProfile.voiceIsolation => voiceCleanupStatus,
      InputProfile.studio =>
        settings.inputVolume == unchangedInputVolume
            ? null
            : volumeCleanupStatus,
    };

Future<CaptureMedia> cleanTakeMedia(
  TakeCleanup cleanup,
  CaptureMedia media, {
  required TakeKind kind,
  required AppSettings settings,
  required int durationMs,
}) async {
  if (media is! CaptureFile) {
    return media;
  }
  final File cleaned = await cleanup.clean(
    media.file,
    kind: kind,
    profile: settings.inputProfile,
    volume: settings.inputVolume,
    duration: Duration(milliseconds: durationMs),
  );
  if (cleaned.path == media.file.path) {
    return media;
  }
  return CaptureFile(
    file: cleaned,
    mime: media.mime,
    width: media.width,
    height: media.height,
    durationMs: media.durationMs,
  );
}

Future<void> releaseCleanedMedia(
  TakeCleanup cleanup,
  CaptureMedia recorded,
  CaptureMedia kept,
) async {
  if (identical(kept, recorded) || kept is! CaptureFile) {
    return;
  }
  try {
    await cleanup.release(kept.file);
  } catch (error, stackTrace) {
    debugPrint('Cleaned take release failed: $error\n$stackTrace');
  }
}

final Provider<TakeCleanup> takeCleanupProvider = Provider<TakeCleanup>(
  (Ref ref) => TakeCleanup(channel: ref.watch(audioCleanChannelProvider)),
);
