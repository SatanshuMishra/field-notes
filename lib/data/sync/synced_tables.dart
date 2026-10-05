abstract final class SyncedTables {
  static const String days = 'days';
  static const String entries = 'entries';
  static const String entryPhotos = 'entry_photos';
  static const String mediaBlobs = 'media_blobs';
  static const String journalSettings = 'journal_settings';

  static const List<String> dayFields = <String>[
    'id',
    'date',
    'moodId',
    'createdAt',
    'updatedAt',
    'deletedAt',
  ];

  static const List<String> entryFields = <String>[
    'id',
    'dayId',
    'type',
    'textContent',
    'mediaId',
    'thumbnailMediaId',
    'durationMs',
    'createdAt',
    'updatedAt',
    'deletedAt',
    'conflictSourceDevice',
    'textVersion',
  ];

  static const List<String> entryPhotoFields = <String>[
    'id',
    'entryId',
    'mediaId',
    'sortOrder',
    'createdAt',
    'updatedAt',
    'deletedAt',
  ];

  static const List<String> mediaBlobFields = <String>[
    'id',
    'mime',
    'kind',
    'bytes',
    'width',
    'height',
    'durationMs',
    'createdAt',
    'posterId',
  ];

  static const List<String> journalSettingFields = <String>['key', 'value'];

  static const Map<String, List<String>> fields = <String, List<String>>{
    days: dayFields,
    entries: entryFields,
    entryPhotos: entryPhotoFields,
    mediaBlobs: mediaBlobFields,
    journalSettings: journalSettingFields,
  };
}
