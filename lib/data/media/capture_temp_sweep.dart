import 'dart:io';

import 'package:path/path.dart' as p;

final RegExp _captureFileName = RegExp(
  r'^(?:voice_.*\.m4a|video_thumb_.*\.jpg|output\.mp4|REC.*\.mp4|CAP.*\.jpg'
  r'|field-notes-export-.*\.zip)$',
);

final RegExp _pickerFolderName = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}'
  r'-[0-9a-fA-F]{12}$',
);

const Set<String> _imageExtensions = <String>{
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.heic',
  '.heif',
  '.bmp',
};

Future<int> sweepCaptureTemp(Directory temporary) async {
  if (!await temporary.exists()) {
    return 0;
  }
  var removed = 0;
  try {
    await for (final FileSystemEntity entity
        in temporary.list(followLinks: false)) {
      final String name = p.basename(entity.path);
      if (entity is File && _captureFileName.hasMatch(name)) {
        removed += await _deleteFile(entity);
      } else if (entity is Directory && _pickerFolderName.hasMatch(name)) {
        removed += await _sweepPickerCopies(entity);
      }
    }
  } on FileSystemException {
    return removed;
  }
  return removed;
}

Future<int> _sweepPickerCopies(Directory folder) async {
  final List<FileSystemEntity> entries;
  try {
    entries = await folder.list(followLinks: false).toList();
  } on FileSystemException {
    return 0;
  }
  final List<File> images = <File>[
    for (final File file in entries.whereType<File>())
      if (_imageExtensions.contains(p.extension(file.path).toLowerCase())) file,
  ];
  if (images.isEmpty || images.length != entries.length) {
    return 0;
  }
  var removed = 0;
  for (final File image in images) {
    removed += await _deleteFile(image);
  }
  try {
    await folder.delete();
  } on FileSystemException {
    return removed;
  }
  return removed;
}

Future<int> _deleteFile(File file) async {
  try {
    await file.delete();
    return 1;
  } on FileSystemException {
    return 0;
  }
}
