import 'dart:io';

import '../models/models.dart';

sealed class CaptureMedia {
  const CaptureMedia({
    required this.mime,
    this.width,
    this.height,
    this.durationMs,
  });

  final String mime;
  final int? width;
  final int? height;
  final int? durationMs;
}

final class CaptureBytes extends CaptureMedia {
  const CaptureBytes({
    required this.bytes,
    required super.mime,
    super.width,
    super.height,
    super.durationMs,
  });

  final List<int> bytes;
}

final class CaptureFile extends CaptureMedia {
  const CaptureFile({
    required this.file,
    required super.mime,
    super.width,
    super.height,
    super.durationMs,
  });

  final File file;
}

sealed class CaptureRequest {
  CaptureRequest({
    required this.date,
    required List<CaptureMedia> photos,
  }) : photos = List<CaptureMedia>.unmodifiable(photos);

  final String date;
  final List<CaptureMedia> photos;

  EntryType get type;
}

final class TextCaptureRequest extends CaptureRequest {
  TextCaptureRequest({
    required super.date,
    required this.text,
    super.photos = const <CaptureMedia>[],
  });

  final String text;

  @override
  EntryType get type => EntryType.text;
}

final class VoiceCaptureRequest extends CaptureRequest {
  VoiceCaptureRequest({
    required super.date,
    required this.audio,
    required this.durationMs,
    super.photos = const <CaptureMedia>[],
  });

  final CaptureMedia audio;
  final int durationMs;

  @override
  EntryType get type => EntryType.voice;
}

final class VideoCaptureRequest extends CaptureRequest {
  VideoCaptureRequest({
    required super.date,
    required this.video,
    required this.durationMs,
    this.thumbnail,
    super.photos = const <CaptureMedia>[],
  });

  final CaptureMedia video;
  final int durationMs;
  final CaptureMedia? thumbnail;

  @override
  EntryType get type => EntryType.video;
}

class CaptureResult {
  const CaptureResult({
    required this.day,
    required this.entry,
    required this.photos,
  });

  final Day day;
  final Entry entry;
  final List<EntryPhoto> photos;
}

class CaptureException implements Exception {
  const CaptureException(this.message, {this.savedEntryId, this.cause});

  final String message;
  final String? savedEntryId;
  final Object? cause;

  bool get isPartiallySaved => savedEntryId != null;

  @override
  String toString() => cause == null
      ? 'CaptureException: $message'
      : 'CaptureException: $message ($cause)';
}

abstract interface class CaptureService {
  Future<CaptureResult> capture(CaptureRequest request);
}
