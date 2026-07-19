abstract interface class DeleteAllService {
  Future<DeleteAllResult> deleteAll();
}

class DeleteAllResult {
  const DeleteAllResult({
    required this.deletedDays,
    required this.deletedEntries,
    required this.deletedPhotos,
    required this.deletedMediaBlobs,
    required this.deletedFiles,
  });

  final int deletedDays;
  final int deletedEntries;
  final int deletedPhotos;
  final int deletedMediaBlobs;
  final int deletedFiles;
}
