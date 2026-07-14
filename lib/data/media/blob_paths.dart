import 'package:path/path.dart' as p;

const String blobsSubdir = 'blobs';

String relPathForId(String id) =>
    p.join(blobsSubdir, id.substring(0, 2), id.substring(2));

String? idFromRelPath(String relPath) {
  final parts = p.split(relPath);
  if (parts.length != 3 || parts[0] != blobsSubdir) {
    return null;
  }
  final shard = parts[1];
  final rest = parts[2];
  if (shard.length != 2) {
    return null;
  }
  final id = '$shard$rest';
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
