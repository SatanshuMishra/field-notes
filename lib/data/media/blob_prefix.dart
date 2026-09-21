const int blobIdLength = 64;
const int photoRefPrefixLength = 12;
const int photoRefPrefixStep = 4;
const String photoReferenceScheme = 'photo/';

final RegExp _photoReferencePattern = RegExp(
  '$photoReferenceScheme([0-9a-f]{$photoRefPrefixLength,$blobIdLength})',
);

bool isLowerHex(String value) {
  if (value.isEmpty) {
    return false;
  }
  for (final int code in value.codeUnits) {
    final bool isDigit = code >= 0x30 && code <= 0x39;
    final bool isLowerAToF = code >= 0x61 && code <= 0x66;
    if (!isDigit && !isLowerAToF) {
      return false;
    }
  }
  return true;
}

bool isBlobPrefix(String value) =>
    value.length >= photoRefPrefixLength &&
    value.length <= blobIdLength &&
    isLowerHex(value);

bool isShortBlobReference(String value) =>
    value.length < blobIdLength && isBlobPrefix(value);

String blobPrefixOf(String id, {int length = photoRefPrefixLength}) {
  if (length <= 0) {
    throw ArgumentError.value(length, 'length', 'must be positive');
  }
  return id.length <= length ? id : id.substring(0, length);
}

int nextPrefixLength(int length) {
  final int extended = length + photoRefPrefixStep;
  return extended >= blobIdLength ? blobIdLength : extended;
}

String? blobPrefixUpperBound(String prefix) {
  final List<int> units = List<int>.of(prefix.codeUnits);
  for (int i = units.length - 1; i >= 0; i--) {
    final int? next = _nextHexCodeUnit(units[i]);
    if (next != null) {
      units[i] = next;
      return String.fromCharCodes(units.sublist(0, i + 1));
    }
  }
  return null;
}

int? _nextHexCodeUnit(int code) {
  if (code >= 0x30 && code <= 0x38) {
    return code + 1;
  }
  if (code == 0x39) {
    return 0x61;
  }
  if (code >= 0x61 && code <= 0x65) {
    return code + 1;
  }
  return null;
}

List<String> blobPrefixesIn(String source) {
  final Set<String> found = <String>{};
  for (final RegExpMatch match in _photoReferencePattern.allMatches(source)) {
    final String? prefix = match.group(1);
    if (prefix != null) {
      found.add(prefix);
    }
  }
  return List<String>.unmodifiable(found);
}
