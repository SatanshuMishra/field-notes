import 'dart:io';

import 'package:flutter/services.dart';

const String videoJoinChannelName = 'field_notes/video_join';
const String videoJoinMethod = 'join';

class VideoJoinException implements Exception {
  const VideoJoinException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'VideoJoinException: $message';
}

class VideoJoiner {
  const VideoJoiner([
    this._channel = const MethodChannel(videoJoinChannelName),
  ]);

  final MethodChannel _channel;

  Future<File> join(List<String> segments, String output) async {
    final Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>(
        videoJoinMethod,
        <String, Object?>{'segments': segments, 'output': output},
      );
    } on PlatformException catch (error) {
      throw VideoJoinException(
        'the platform could not join the video parts: ${error.code}',
        error,
      );
    } on MissingPluginException catch (error) {
      throw VideoJoinException('no platform video joiner', error);
    }
    if (reply is! String || reply.isEmpty) {
      throw VideoJoinException(
        'expected the joined file path, got ${reply.runtimeType}',
      );
    }
    return File(reply);
  }
}
