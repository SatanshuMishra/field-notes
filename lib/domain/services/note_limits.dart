const int maxNoteCharacters = 1000000;
const int maxNoteSyncedBytes = 3 * 1024 * 1024;

const String noteTooLongMessage =
    'This note is too long to save. A note can hold up to '
    '1,000,000 characters.';

int noteSyncedBytes(String text) {
  int bytes = 2;
  for (int index = 0; index < text.length; index++) {
    final int unit = text.codeUnitAt(index);
    if (unit == 0x22 || unit == 0x5c) {
      bytes += 2;
    } else if (unit == 0x08 ||
        unit == 0x09 ||
        unit == 0x0a ||
        unit == 0x0c ||
        unit == 0x0d) {
      bytes += 2;
    } else if (unit < 0x20) {
      bytes += 6;
    } else if (unit < 0x80) {
      bytes += 1;
    } else if (unit < 0x800) {
      bytes += 2;
    } else if (unit >= 0xd800 && unit < 0xdc00 && index + 1 < text.length) {
      final int next = text.codeUnitAt(index + 1);
      if (next >= 0xdc00 && next < 0xe000) {
        bytes += 4;
        index += 1;
      } else {
        bytes += 6;
      }
    } else if (unit >= 0xd800 && unit < 0xe000) {
      bytes += 6;
    } else {
      bytes += 3;
    }
  }
  return bytes;
}

bool noteFitsSync(String text) =>
    text.length <= maxNoteCharacters &&
    noteSyncedBytes(text) <= maxNoteSyncedBytes;
