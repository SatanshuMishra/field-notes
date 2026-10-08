import 'dart:io';

import 'package:field_notes/data/media/media_probe.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/services/media_store.dart';

import 'capture_date.dart';

const Duration _mediaReadyPollInterval = Duration(milliseconds: 50);
const int _mediaReadyPollAttempts = 20;
const Duration _mediaProbeTimeout = Duration(seconds: 5);

const String blankTextMessage = 'Add a few words before saving your note.';
const String invalidDateMessage =
    'That day could not be identified. Nothing was saved.';
const String invalidDurationMessage =
    'That recording has no length. Nothing was saved.';
const String mediaWriteMessage =
    'Could not save your media. Check your available space and try again.';
const String mediaMissingMessage =
    'That recording did not finish saving. Nothing was saved — please try again.';
const String entryWriteMessage =
    'Could not save your entry. Nothing was saved — please try again.';
const String photoAttachMessage =
    'Your entry was saved, but some photos could not be attached.';

typedef _Resolved = ({
  String? text,
  MediaBlob? media,
  MediaBlob? thumbnail,
  int? durationMs,
});

typedef _StoredVideo = ({MediaBlob blob, MediaMeasure? measured});

typedef _Dimensions = ({int width, int height});

class JournalCaptureService implements CaptureService {
  const JournalCaptureService({
    required this.journal,
    required this.media,
    this.probe,
  });

  final JournalRepository journal;
  final MediaStore media;
  final MediaProbe? probe;

  @override
  Future<CaptureResult> capture(CaptureRequest request) async {
    if (!isCaptureDateKey(request.date)) {
      throw const CaptureException(invalidDateMessage);
    }

    final _Resolved resolved = await _resolve(request);
    final List<MediaBlob> photoBlobs = <MediaBlob>[];
    for (final CaptureMedia photo in request.photos) {
      photoBlobs.add(await _finalize(photo, MediaKind.photo));
    }

    final Day day;
    final Entry entry;
    try {
      day = await journal.ensureDayForDate(request.date);
      entry = await journal.createEntry(
        dayId: day.id,
        type: request.type,
        textContent: resolved.text,
        mediaId: resolved.media?.id,
        thumbnailMediaId: resolved.thumbnail?.id,
        durationMs: resolved.durationMs,
      );
    } catch (error) {
      throw CaptureException(entryWriteMessage, cause: error);
    }

    final List<EntryPhoto> photos = <EntryPhoto>[];
    try {
      for (var index = 0; index < photoBlobs.length; index++) {
        photos.add(
          await journal.addPhoto(
            entryId: entry.id,
            mediaId: photoBlobs[index].id,
            sortOrder: index,
          ),
        );
      }
    } catch (error) {
      throw CaptureException(
        photoAttachMessage,
        savedEntryId: entry.id,
        cause: error,
      );
    }

    return CaptureResult(day: day, entry: entry, photos: photos);
  }

  Future<_Resolved> _resolve(CaptureRequest request) => switch (request) {
    TextCaptureRequest r => _resolveText(r),
    VoiceCaptureRequest r => _resolveVoice(r),
    VideoCaptureRequest r => _resolveVideo(r),
  };

  Future<_Resolved> _resolveText(TextCaptureRequest request) async {
    final String text = request.text.trim();
    if (text.isEmpty) {
      throw const CaptureException(blankTextMessage);
    }
    return (text: text, media: null, thumbnail: null, durationMs: null);
  }

  Future<_Resolved> _resolveVoice(VoiceCaptureRequest request) async {
    _requireDuration(request.durationMs);
    final MediaBlob audio = await _finalize(request.audio, MediaKind.audio);
    final MediaMeasure? measured = await _measure(
      File(media.absolutePath(audio)),
      MediaKind.audio,
    );
    return (
      text: null,
      media: audio,
      thumbnail: null,
      durationMs: _finishedDuration(measured, request.durationMs),
    );
  }

  Future<_Resolved> _resolveVideo(VideoCaptureRequest request) async {
    _requireDuration(request.durationMs);
    final _StoredVideo video = await _finalizeVideo(request.video);
    final CaptureMedia? source = request.thumbnail;
    final MediaBlob? thumbnail = source == null
        ? null
        : await _finalize(source, MediaKind.photo);
    return (
      text: null,
      media: video.blob,
      thumbnail: thumbnail,
      durationMs: _finishedDuration(video.measured, request.durationMs),
    );
  }

  Future<_StoredVideo> _finalizeVideo(CaptureMedia payload) async {
    switch (payload) {
      case CaptureBytes():
        final MediaBlob blob = await _finalize(payload, MediaKind.video);
        return (
          blob: blob,
          measured: await _measure(
            File(media.absolutePath(blob)),
            MediaKind.video,
          ),
        );
      case CaptureFile(:final File file):
        await _awaitFileReady(file);
        final MediaMeasure? measured = await _measure(file, MediaKind.video);
        final bool sizeGiven = payload.width != null || payload.height != null;
        final _Dimensions? size = _dimensionsOf(measured);
        final MediaBlob blob = await _store(
          payload,
          MediaKind.video,
          width: sizeGiven ? payload.width : size?.width,
          height: sizeGiven ? payload.height : size?.height,
        );
        return (blob: blob, measured: measured);
    }
  }

  Future<MediaMeasure?> _measure(File file, MediaKind kind) async {
    final MediaProbe? measurer = probe;
    if (measurer == null) {
      return null;
    }
    try {
      return await measurer
          .measure(file: file, kind: kind)
          .timeout(_mediaProbeTimeout);
    } catch (_) {
      return null;
    }
  }

  int _finishedDuration(MediaMeasure? measured, int recordedMs) {
    final int? measuredMs = measured?.duration?.inMilliseconds;
    if (measuredMs == null || measuredMs <= 0) {
      return recordedMs;
    }
    return measuredMs;
  }

  _Dimensions? _dimensionsOf(MediaMeasure? measured) {
    final int? width = measured?.width;
    final int? height = measured?.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return (width: width, height: height);
  }

  void _requireDuration(int durationMs) {
    if (durationMs <= 0) {
      throw const CaptureException(invalidDurationMessage);
    }
  }

  Future<MediaBlob> _finalize(CaptureMedia payload, MediaKind kind) async {
    if (payload is CaptureFile &&
        (kind == MediaKind.audio || kind == MediaKind.video)) {
      await _awaitFileReady(payload.file);
    }
    return _store(payload, kind, width: payload.width, height: payload.height);
  }

  Future<MediaBlob> _store(
    CaptureMedia payload,
    MediaKind kind, {
    required int? width,
    required int? height,
  }) async {
    try {
      return await switch (payload) {
        CaptureBytes m => media.putBytes(
          bytes: m.bytes,
          mime: m.mime,
          kind: kind,
          width: width,
          height: height,
          durationMs: m.durationMs,
        ),
        CaptureFile m => media.putFile(
          source: m.file,
          mime: m.mime,
          kind: kind,
          width: width,
          height: height,
          durationMs: m.durationMs,
        ),
      };
    } catch (error) {
      throw CaptureException(mediaWriteMessage, cause: error);
    }
  }

  Future<void> _awaitFileReady(File file) async {
    for (var attempt = 0; ; attempt++) {
      if (_isFileReady(file)) {
        return;
      }
      if (attempt >= _mediaReadyPollAttempts) {
        throw const CaptureException(mediaMissingMessage);
      }
      await Future<void>.delayed(_mediaReadyPollInterval);
    }
  }

  bool _isFileReady(File file) {
    try {
      return file.existsSync() && file.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }
}
