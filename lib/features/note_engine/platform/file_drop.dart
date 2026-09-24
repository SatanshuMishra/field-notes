import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String fileDropChannelName = 'field_notes/file_drop';

sealed class FileDropEvent {
  const FileDropEvent();
}

final class FileDropHover extends FileDropEvent {
  const FileDropHover(this.position);

  final Offset position;

  @override
  bool operator ==(Object other) =>
      other is FileDropHover && other.position == position;

  @override
  int get hashCode => position.hashCode;
}

final class FileDropLeave extends FileDropEvent {
  const FileDropLeave();

  @override
  bool operator ==(Object other) => other is FileDropLeave;

  @override
  int get hashCode => (FileDropLeave).hashCode;
}

final class FileDropped extends FileDropEvent {
  const FileDropped({required this.position, required this.paths});

  final Offset position;
  final List<String> paths;

  @override
  bool operator ==(Object other) =>
      other is FileDropped &&
      other.position == position &&
      listEquals(other.paths, paths);

  @override
  int get hashCode => Object.hash(position, Object.hashAll(paths));
}

final class FileDropChannel {
  FileDropChannel({this._channel = const MethodChannel(fileDropChannelName)});

  static final FileDropChannel instance = FileDropChannel();

  final MethodChannel _channel;
  late final StreamController<FileDropEvent> _controller =
      StreamController<FileDropEvent>.broadcast(
        onListen: () => _channel.setMethodCallHandler(_handle),
        onCancel: () => _channel.setMethodCallHandler(null),
      );

  Stream<FileDropEvent> get events => _controller.stream;

  Future<void> _handle(MethodCall call) async {
    final FileDropEvent? event = _eventFrom(call);
    if (event != null) {
      _controller.add(event);
    }
  }
}

FileDropEvent? _eventFrom(MethodCall call) {
  final Object? arguments = call.arguments;
  return switch (call.method) {
    'hover' => switch (_positionFrom(arguments)) {
      final Offset position => FileDropHover(position),
      null => null,
    },
    'leave' => const FileDropLeave(),
    'drop' => _droppedFrom(arguments),
    _ => null,
  };
}

Offset? _positionFrom(Object? arguments) {
  if (arguments is! Map<Object?, Object?>) {
    return null;
  }
  final Object? x = arguments['x'];
  final Object? y = arguments['y'];
  if (x is! num || y is! num) {
    return null;
  }
  return Offset(x.toDouble(), y.toDouble());
}

FileDropped? _droppedFrom(Object? arguments) {
  final Offset? position = _positionFrom(arguments);
  if (position == null || arguments is! Map<Object?, Object?>) {
    return null;
  }
  final Object? paths = arguments['paths'];
  if (paths is! List<Object?> || paths.any((Object? path) => path is! String)) {
    return null;
  }
  return FileDropped(
    position: position,
    paths: List<String>.unmodifiable(paths.cast<String>()),
  );
}
