import 'dart:io';

import '../models/media_blob.dart';
import '../models/media_kind.dart';

abstract interface class MediaStore {
  Future<MediaBlob> putBytes({
    required List<int> bytes,
    required String mime,
    required MediaKind kind,
    int? width,
    int? height,
    int? durationMs,
  });

  Future<MediaBlob> putFile({
    required File source,
    required String mime,
    required MediaKind kind,
    int? width,
    int? height,
    int? durationMs,
  });

  Future<MediaBlob?> blobById(String id);

  Future<MediaBlob?> blobByPrefix(String prefix);

  Future<String> uniquePrefixFor(String id);

  String absolutePath(MediaBlob blob);

  Future<int> collectGarbage();
}
