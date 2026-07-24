import 'package:path/path.dart' as p;

import '../../domain/models/media_kind.dart';

const String blobsSubdir = 'blobs';
const int blobShardLength = 2;

const Map<String, String> _extensionByMime = <String, String>{
  'video/mp4': '.mp4',
  'video/quicktime': '.mov',
  'video/x-m4v': '.m4v',
  'video/3gpp': '.3gp',
  'video/webm': '.webm',
  'video/x-matroska': '.mkv',
  'audio/mp4': '.m4a',
  'audio/x-m4a': '.m4a',
  'audio/aac': '.aac',
  'audio/mpeg': '.mp3',
  'audio/mp3': '.mp3',
  'audio/wav': '.wav',
  'audio/x-wav': '.wav',
  'audio/wave': '.wav',
  'audio/vnd.wave': '.wav',
  'audio/aiff': '.aiff',
  'audio/x-aiff': '.aiff',
  'audio/flac': '.flac',
  'audio/x-flac': '.flac',
  'audio/ogg': '.ogg',
  'audio/opus': '.opus',
  'audio/webm': '.webm',
  'audio/amr': '.amr',
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/heic': '.heic',
  'image/heif': '.heif',
  'image/webp': '.webp',
  'image/gif': '.gif',
  'image/tiff': '.tiff',
  'image/bmp': '.bmp',
};

String blobExtensionFor({required String mime, required MediaKind kind}) {
  final normalized = mime.split(';').first.trim().toLowerCase();
  return _extensionByMime[normalized] ?? _extensionForKind(kind);
}

String _extensionForKind(MediaKind kind) => switch (kind) {
      MediaKind.photo => '.jpg',
      MediaKind.audio => '.m4a',
      MediaKind.video => '.mp4',
    };

String relPathForId(String id) => p.join(
      blobsSubdir,
      id.substring(0, blobShardLength),
      id.substring(blobShardLength),
    );

String relPathForBlob({
  required String id,
  required String mime,
  required MediaKind kind,
}) =>
    '${relPathForId(id)}${blobExtensionFor(mime: mime, kind: kind)}';

String? idFromRelPath(String relPath) {
  final parts = p.split(relPath);
  if (parts.length != 3 || parts[0] != blobsSubdir) {
    return null;
  }
  final shard = parts[1];
  if (shard.length != blobShardLength) {
    return null;
  }
  final id = '$shard${p.basenameWithoutExtension(parts[2])}';
  if (id.length != 64 || !_isLowerHex(id)) {
    return null;
  }
  return id;
}

bool _isLowerHex(String value) {
  for (final code in value.codeUnits) {
    final isDigit = code >= 0x30 && code <= 0x39;
    final isLowerAToF = code >= 0x61 && code <= 0x66;
    if (!isDigit && !isLowerAToF) {
      return false;
    }
  }
  return true;
}
