import 'media_kind.dart';

class MediaBlob {
  const MediaBlob({
    required this.id,
    required this.relPath,
    required this.mime,
    required this.kind,
    required this.bytes,
    required this.createdAt,
    this.width,
    this.height,
    this.durationMs,
  });

  final String id;
  final String relPath;
  final String mime;
  final MediaKind kind;
  final int bytes;
  final int? width;
  final int? height;
  final int? durationMs;
  final int createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaBlob &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          relPath == other.relPath &&
          mime == other.mime &&
          kind == other.kind &&
          bytes == other.bytes &&
          width == other.width &&
          height == other.height &&
          durationMs == other.durationMs &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        relPath,
        mime,
        kind,
        bytes,
        width,
        height,
        durationMs,
        createdAt,
      );

  @override
  String toString() =>
      'MediaBlob(id: $id, relPath: $relPath, mime: $mime, kind: $kind, '
      'bytes: $bytes, width: $width, height: $height, '
      'durationMs: $durationMs, createdAt: $createdAt)';
}
