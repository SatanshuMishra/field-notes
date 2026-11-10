import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String videoFramesChannelName = 'field_notes/video_frames';
const String videoFrameAtMethod = 'frameAt';
const int videoFrameWidthPixels = 320;
const int videoFrameCacheLimit = 120;

typedef VideoFrameKey = ({String path, int second});

class VideoFrameExtractor {
  const VideoFrameExtractor([
    this._channel = const MethodChannel(videoFramesChannelName),
  ]);

  final MethodChannel _channel;

  Future<Uint8List?> frameAt(String path, Duration position) async {
    final Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>(
        videoFrameAtMethod,
        <String, Object?>{
          'path': path,
          'positionMs': position.inMilliseconds,
          'width': videoFrameWidthPixels,
        },
      );
    } on Exception {
      return null;
    }
    return reply is Uint8List && reply.isNotEmpty ? reply : null;
  }
}

class VideoFrames {
  VideoFrames([this._extractor = const VideoFrameExtractor()]);

  final VideoFrameExtractor _extractor;
  _RecentFrames _recent = const _RecentFrames.empty();
  VideoFrameKey? _newest;
  _FrameRequest? _running;
  _FrameRequest? _waiting;

  Future<Uint8List?> frameAt(String path, Duration position) {
    final VideoFrameKey key = (
      path: path,
      second: math.max(position.inSeconds, 0),
    );
    _newest = key;
    final Uint8List? remembered = _recent[key];
    if (remembered != null) {
      _dropWaiting();
      _recent = _recent.remembering(key, remembered);
      return Future<Uint8List?>.value(remembered);
    }
    final _FrameRequest? waiting = _waiting;
    if (waiting != null && waiting.key == key) {
      return waiting.answer;
    }
    _dropWaiting();
    final _FrameRequest? running = _running;
    if (running != null && running.key == key) {
      return running.answer;
    }
    final _FrameRequest request = _FrameRequest(key);
    if (running == null) {
      unawaited(_run(request));
    } else {
      _waiting = request;
    }
    return request.answer;
  }

  void _dropWaiting() {
    _waiting?.settle(null);
    _waiting = null;
  }

  Future<void> _run(_FrameRequest request) async {
    _running = request;
    final Uint8List? frame = await _extractor.frameAt(
      request.key.path,
      Duration(seconds: request.key.second),
    );
    if (frame != null) {
      _recent = _recent.remembering(request.key, frame);
    }
    _running = null;
    request.settle(request.key == _newest ? frame : null);
    final _FrameRequest? next = _waiting;
    _waiting = null;
    if (next != null) {
      unawaited(_run(next));
    }
  }
}

final Provider<VideoFrames> videoFramesProvider = Provider<VideoFrames>(
  (Ref ref) => VideoFrames(),
);

class _FrameRequest {
  _FrameRequest(this.key);

  final VideoFrameKey key;
  final Completer<Uint8List?> _answer = Completer<Uint8List?>();

  Future<Uint8List?> get answer => _answer.future;

  void settle(Uint8List? frame) => _answer.complete(frame);
}

@immutable
class _RecentFrames {
  const _RecentFrames.empty()
    : _oldestFirst = const <VideoFrameKey, Uint8List>{};

  const _RecentFrames._(this._oldestFirst);

  final Map<VideoFrameKey, Uint8List> _oldestFirst;

  Uint8List? operator [](VideoFrameKey key) => _oldestFirst[key];

  _RecentFrames remembering(VideoFrameKey key, Uint8List frame) {
    final List<MapEntry<VideoFrameKey, Uint8List>> entries =
        <MapEntry<VideoFrameKey, Uint8List>>[
          ..._oldestFirst.entries.where(
            (MapEntry<VideoFrameKey, Uint8List> entry) => entry.key != key,
          ),
          MapEntry<VideoFrameKey, Uint8List>(key, frame),
        ];
    return _RecentFrames._(
      Map<VideoFrameKey, Uint8List>.unmodifiable(
        Map<VideoFrameKey, Uint8List>.fromEntries(
          entries.skip(math.max(entries.length - videoFrameCacheLimit, 0)),
        ),
      ),
    );
  }
}
