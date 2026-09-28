import 'syntax_tree.dart';

const int _space = 0x20;
const int _tab = 0x09;
const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const int _bang = 0x21;
const int _quote = 0x22;
const int _openBracket = 0x5B;
const int _closeBracket = 0x5D;
const int _closeParen = 0x29;
const String _referenceOpening = '](photo/';

enum MdPhotoSide {
  left('Left'),
  centre('Centre'),
  right('Right');

  const MdPhotoSide(this.label);

  final String label;
}

enum MdPhotoSize {
  small('Small', 'S', 1 / 3),
  medium('Medium', 'M', 1 / 2),
  large('Large', 'L', 2 / 3),
  full('Full', 'Full', 1.0);

  const MdPhotoSize(this.label, this.shortLabel, this.fraction);

  final String label;
  final String shortLabel;
  final double fraction;
}

final class MdPhotoPlacement {
  const MdPhotoPlacement({
    this.side = MdPhotoSide.right,
    this.size = MdPhotoSize.medium,
  }) : isValid = true;

  const MdPhotoPlacement.invalid()
    : side = MdPhotoSide.centre,
      size = MdPhotoSize.medium,
      isValid = false;

  factory MdPhotoPlacement.parse(String title) {
    MdPhotoSide? side;
    MdPhotoSize? size;
    int at = 0;
    while (at < title.length) {
      if (_isSpaceOrTab(title.codeUnitAt(at))) {
        at++;
        continue;
      }
      final int start = at;
      while (at < title.length && !_isSpaceOrTab(title.codeUnitAt(at))) {
        at++;
      }
      final String word = title.substring(start, at).toLowerCase();
      final MdPhotoSide? asSide = _sideWords[word];
      final MdPhotoSize? asSize = _sizeWords[word];
      if (asSide != null && side == null) {
        side = asSide;
      } else if (asSize != null && size == null) {
        size = asSize;
      } else {
        return const MdPhotoPlacement.invalid();
      }
    }
    return MdPhotoPlacement(
      side: side ?? MdPhotoSide.right,
      size: size ?? MdPhotoSize.medium,
    );
  }

  final MdPhotoSide side;
  final MdPhotoSize size;
  final bool isValid;

  MdPhotoPlacement copyWith({MdPhotoSide? side, MdPhotoSize? size}) =>
      MdPhotoPlacement(side: side ?? this.side, size: size ?? this.size);

  String format() => '${side.name} ${size.name}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdPhotoPlacement &&
          side == other.side &&
          size == other.size &&
          isValid == other.isValid;

  @override
  int get hashCode => Object.hash(side, size, isValid);

  @override
  String toString() =>
      'MdPhotoPlacement(${format()}${isValid ? '' : ', invalid'})';
}

const Map<String, MdPhotoSide> _sideWords = <String, MdPhotoSide>{
  'left': MdPhotoSide.left,
  'centre': MdPhotoSide.centre,
  'center': MdPhotoSide.centre,
  'right': MdPhotoSide.right,
};

const Map<String, MdPhotoSize> _sizeWords = <String, MdPhotoSize>{
  'small': MdPhotoSize.small,
  'medium': MdPhotoSize.medium,
  'large': MdPhotoSize.large,
  'full': MdPhotoSize.full,
};

String sanitizePhotoCaption(String caption) {
  final StringBuffer buffer = StringBuffer();
  for (int at = 0; at < caption.length; at++) {
    final int unit = caption.codeUnitAt(at);
    if (unit == _closeBracket) {
      continue;
    }
    buffer.writeCharCode(
      unit == _lineFeed || unit == _carriageReturn ? _space : unit,
    );
  }
  return buffer.toString();
}

String canonicalPhotoLine(
  String reference,
  String caption,
  MdPhotoPlacement placement,
) =>
    '![${sanitizePhotoCaption(caption).trim()}]'
    '(photo/$reference "${placement.format()}")';

final class MdPhotoLine {
  const MdPhotoLine(this.data);

  final MdPhotoLineData data;

  String get reference => data.reference;

  MdRange get referenceRange => data.referenceRange;

  String get caption => data.caption;

  MdRange get captionRange => data.captionRange;

  String? get title => data.title;

  MdRange? get titleRange => data.titleRange;

  bool get canResolve => data.canResolve;

  MdPhotoPlacement get placement => MdPhotoPlacement.parse(title ?? '');

  static MdPhotoLine ofBlock(MdBlock block, String source) {
    final MdBlockData? data = block.data;
    if (block.kind != MdBlockKind.photoLine ||
        data is! MdPhotoLineData ||
        block.sourceRange.end > source.length) {
      throw ArgumentError.value(block, 'block', 'is not a photo line');
    }
    return MdPhotoLine(data);
  }

  static MdPhotoLine? match(String source, int start, int end) {
    int at = start;
    while (at < end && _isSpaceOrTab(source.codeUnitAt(at))) {
      at++;
    }
    if (at + 2 > end ||
        source.codeUnitAt(at) != _bang ||
        source.codeUnitAt(at + 1) != _openBracket) {
      return null;
    }
    final int captionStart = at + 2;
    at = captionStart;
    while (at < end && source.codeUnitAt(at) != _closeBracket) {
      at++;
    }
    final int captionEnd = at;
    if (at + _referenceOpening.length > end ||
        !source.startsWith(_referenceOpening, at)) {
      return null;
    }
    final int referenceStart = at + _referenceOpening.length;
    at = referenceStart;
    while (at < end && _isHexDigit(source.codeUnitAt(at))) {
      at++;
    }
    final int referenceEnd = at;
    if (referenceEnd == referenceStart) {
      return null;
    }
    MdRange? titleRange;
    if (at < end && _isSpaceOrTab(source.codeUnitAt(at))) {
      while (at < end && _isSpaceOrTab(source.codeUnitAt(at))) {
        at++;
      }
      if (at >= end || source.codeUnitAt(at) != _quote) {
        return null;
      }
      final int titleStart = at + 1;
      at = titleStart;
      while (at < end && source.codeUnitAt(at) != _quote) {
        at++;
      }
      if (at >= end) {
        return null;
      }
      titleRange = MdRange(titleStart, at);
      at++;
    }
    if (at >= end || source.codeUnitAt(at) != _closeParen) {
      return null;
    }
    at++;
    while (at < end && _isSpaceOrTab(source.codeUnitAt(at))) {
      at++;
    }
    if (at != end) {
      return null;
    }
    final MdRange captionRange = MdRange(captionStart, captionEnd);
    final MdRange referenceRange = MdRange(referenceStart, referenceEnd);
    return MdPhotoLine(
      MdPhotoLineData(
        reference: referenceRange.sliceOf(source),
        referenceRange: referenceRange,
        caption: captionRange.sliceOf(source),
        captionRange: captionRange,
        title: titleRange?.sliceOf(source),
        titleRange: titleRange,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MdPhotoLine && data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'MdPhotoLine($data)';
}

extension MdPhotoLinePlacement on MdPhotoLineData {
  MdPhotoPlacement get placement => MdPhotoPlacement.parse(title ?? '');
}

extension MdBlockPhotoLine on MdBlock {
  MdPhotoLineData? get photoLine {
    final MdBlockData? blockData = data;
    return kind == MdBlockKind.photoLine && blockData is MdPhotoLineData
        ? blockData
        : null;
  }
}

bool _isSpaceOrTab(int unit) => unit == _space || unit == _tab;

bool _isHexDigit(int unit) =>
    (unit >= 0x30 && unit <= 0x39) ||
    (unit >= 0x41 && unit <= 0x46) ||
    (unit >= 0x61 && unit <= 0x66);
