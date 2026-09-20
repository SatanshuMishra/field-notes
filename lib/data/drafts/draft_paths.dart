import 'package:path/path.dart' as p;

const String draftsSubdir = 'drafts';
const String draftExtension = '.md';
const int draftKeyLength = 26;

final RegExp _draftKeyPattern = RegExp(
  r'^[0-9A-HJKMNP-TV-Za-hjkmnp-tv-z]{26}$',
);

bool isDraftKey(String key) => _draftKeyPattern.hasMatch(key);

String draftFileName(String key) {
  if (!isDraftKey(key)) {
    throw ArgumentError.value(key, 'key', 'not a ULID-shaped draft key');
  }
  return '$key$draftExtension';
}

String relPathForDraft(String key) => p.join(draftsSubdir, draftFileName(key));
