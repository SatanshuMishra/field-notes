import 'package:path/path.dart' as p;

const String draftsSubdir = 'drafts';
const String draftExtension = '.md';
const int draftKeyLength = 26;

final RegExp _draftKeyPattern = RegExp(
  r'^[0-9A-HJKMNP-TV-Za-hjkmnp-tv-z]{26}$',
);

final RegExp _dateKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

final RegExp _newNoteDraftKeyPattern = RegExp(r'^new-\d{4}-\d{2}-\d{2}$');

bool isDraftKey(String key) =>
    _draftKeyPattern.hasMatch(key) || _newNoteDraftKeyPattern.hasMatch(key);

String newNoteDraftKey(String date) {
  if (!_dateKeyPattern.hasMatch(date)) {
    throw ArgumentError.value(date, 'date', 'not a YYYY-MM-DD date key');
  }
  return 'new-$date';
}

String draftFileName(String key) {
  if (!isDraftKey(key)) {
    throw ArgumentError.value(key, 'key', 'not a draft key');
  }
  return '$key$draftExtension';
}

String relPathForDraft(String key) => p.join(draftsSubdir, draftFileName(key));
