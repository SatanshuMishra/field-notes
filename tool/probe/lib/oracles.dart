enum RelocationOp { remove, moveUp, moveDown, drag }

final class OracleBlock {
  const OracleBlock(
    this.source, {
    this.isPhoto = false,
    this.unclosedFence = false,
  });

  final String source;
  final bool isPhoto;
  final bool unclosedFence;
}

final class OracleNote {
  OracleNote({
    required List<OracleBlock> blocks,
    required List<String> separators,
  }) : blocks = List<OracleBlock>.unmodifiable(blocks),
       separators = List<String>.unmodifiable(separators) {
    if (blocks.isEmpty) {
      throw ArgumentError.value(blocks, 'blocks', 'must not be empty');
    }
    if (separators.length != blocks.length - 1) {
      throw ArgumentError.value(
        separators,
        'separators',
        'must number one fewer than the blocks',
      );
    }
  }

  final List<OracleBlock> blocks;
  final List<String> separators;

  String get source {
    final StringBuffer buffer = StringBuffer(blocks.first.source);
    for (int index = 1; index < blocks.length; index++) {
      buffer
        ..write(separators[index - 1])
        ..write(blocks[index].source);
    }
    return buffer.toString();
  }

  int blockStart(int index) {
    final int before = blocks
        .take(index)
        .fold<int>(
          0,
          (int sum, OracleBlock block) => sum + block.source.length,
        );
    final int gaps = separators
        .take(index)
        .fold<int>(0, (int sum, String separator) => sum + separator.length);
    return before + gaps;
  }

  int blockEnd(int index) => blockStart(index) + blocks[index].source.length;
}

int _lineBreaks(String separator) => '\n'.allMatches(separator).length;

String _noteLineBreak(String source) {
  final int first = source.indexOf('\n');
  return first > 0 && source[first - 1] == '\r' ? '\r\n' : '\n';
}

String _photoToken(String line) {
  final int start = line.indexOf(RegExp(r'[^ \t]'));
  if (start < 0) {
    return '';
  }
  final int end = line.lastIndexOf(RegExp(r'[^ \t]')) + 1;
  return line.substring(start, end);
}

(int, int) _removalRange(OracleNote note, int photo) {
  final int last = note.blocks.length - 1;
  if (last == 0) {
    return (note.blockStart(0), note.blockEnd(0));
  }
  if (photo == 0) {
    return (note.blockStart(0), note.blockStart(1));
  }
  if (photo == last) {
    return (note.blockEnd(photo - 1), note.blockEnd(photo));
  }
  final int before = _lineBreaks(note.separators[photo - 1]);
  final int after = _lineBreaks(note.separators[photo]);
  if (before == 1 && after == 1) {
    return (note.blockStart(photo), note.blockEnd(photo));
  }
  if (before >= after) {
    return (note.blockStart(photo), note.blockStart(photo + 1));
  }
  return (note.blockEnd(photo - 1), note.blockEnd(photo));
}

String? expectedRelocation(
  OracleNote note, {
  required int photo,
  required RelocationOp op,
  int? afterBlock,
}) {
  final int count = note.blocks.length;
  if (photo < 0 || photo >= count) {
    throw RangeError.range(photo, 0, count - 1, 'photo');
  }
  final String source = note.source;
  final (int, int) removal = _removalRange(note, photo);
  if (op == RelocationOp.remove) {
    return source.substring(0, removal.$1) + source.substring(removal.$2);
  }
  final int? target = switch (op) {
    RelocationOp.remove => null,
    RelocationOp.moveUp =>
      photo == 0 ? null : boundaryOffset(note, afterBlock: photo - 2),
    RelocationOp.moveDown =>
      photo == count - 1 || note.blocks[photo + 1].unclosedFence
          ? null
          : boundaryOffset(note, afterBlock: photo + 1),
    RelocationOp.drag => _dragTarget(note, photo, afterBlock),
  };
  if (target == null) {
    return null;
  }
  final String lineBreak = _noteLineBreak(source);
  final String token = _photoToken(note.blocks[photo].source);
  final String inserted = target == 0 ? '$token$lineBreak' : '$lineBreak$token';
  if (target <= removal.$1) {
    return source.substring(0, target) +
        inserted +
        source.substring(target, removal.$1) +
        source.substring(removal.$2);
  }
  return source.substring(0, removal.$1) +
      source.substring(removal.$2, target) +
      inserted +
      source.substring(target);
}

int? _dragTarget(OracleNote note, int photo, int? afterBlock) {
  if (afterBlock == null) {
    throw ArgumentError.notNull('afterBlock');
  }
  if (afterBlock < -1 || afterBlock >= note.blocks.length) {
    throw RangeError.range(
      afterBlock,
      -1,
      note.blocks.length - 1,
      'afterBlock',
    );
  }
  if (afterBlock == photo - 1 || afterBlock == photo) {
    return null;
  }
  if (afterBlock >= 0 && note.blocks[afterBlock].unclosedFence) {
    return null;
  }
  return boundaryOffset(note, afterBlock: afterBlock);
}

bool _isBlankLine(String line) => RegExp(r'^[ \t]*$').hasMatch(line);

int expectedRestoreCaret(OracleNote note) {
  final String source = note.source;
  if (!note.blocks.last.isPhoto) {
    return source.length;
  }
  final List<(int, int)> photoRanges = <(int, int)>[
    for (int index = 0; index < note.blocks.length; index++)
      if (note.blocks[index].isPhoto)
        (note.blockStart(index), note.blockEnd(index)),
  ];
  final int lastStart = note.blockStart(note.blocks.length - 1);
  final List<String> lines = source.split('\n');
  final List<int> lineStarts = <int>[
    0,
    for (final RegExpMatch match in RegExp('\n').allMatches(source)) match.end,
  ];
  final int lastLine = lineStarts.lastIndexWhere(
    (int start) => start <= lastStart,
  );
  for (int index = lastLine - 1; index >= 0; index--) {
    final int start = lineStarts[index];
    final bool inPhoto = photoRanges.any(
      ((int, int) range) => start >= range.$1 && start < range.$2,
    );
    final String raw = lines[index];
    final String line = raw.endsWith('\r')
        ? raw.substring(0, raw.length - 1)
        : raw;
    if (inPhoto || _isBlankLine(line)) {
      continue;
    }
    return start + line.length;
  }
  return 0;
}

int boundaryOffset(OracleNote note, {required int afterBlock}) {
  if (afterBlock < -1 || afterBlock >= note.blocks.length) {
    throw RangeError.range(
      afterBlock,
      -1,
      note.blocks.length - 1,
      'afterBlock',
    );
  }
  return afterBlock == -1 ? 0 : note.blockEnd(afterBlock);
}

bool isValidBoundary(OracleNote note, int offset) {
  if (offset == 0) {
    return true;
  }
  for (int index = 0; index < note.blocks.length; index++) {
    if (note.blockEnd(index) == offset && !note.blocks[index].unclosedFence) {
      return true;
    }
  }
  return false;
}

enum PhotoCommand { remove, moveUp, moveDown, restyle }

List<(int, int)> photoCommandRanges(
  OracleNote note, {
  required int photo,
  required PhotoCommand command,
}) {
  final int count = note.blocks.length;
  if (photo < 0 || photo >= count) {
    throw RangeError.range(photo, 0, count - 1, 'photo');
  }
  final (int, int) removal = _removalRange(note, photo);
  final int? target = switch (command) {
    PhotoCommand.remove || PhotoCommand.restyle => null,
    PhotoCommand.moveUp =>
      photo == 0 ? null : boundaryOffset(note, afterBlock: photo - 2),
    PhotoCommand.moveDown =>
      photo == count - 1 || note.blocks[photo + 1].unclosedFence
          ? null
          : boundaryOffset(note, afterBlock: photo + 1),
  };
  return switch (command) {
    PhotoCommand.restyle => <(int, int)>[
      (note.blockStart(photo), note.blockEnd(photo)),
    ],
    PhotoCommand.remove => <(int, int)>[removal],
    PhotoCommand.moveUp || PhotoCommand.moveDown => <(int, int)>[
      removal,
      if (target != null) (target, target),
    ],
  };
}

bool changesWithin(List<(int, int)> allowed, List<(int, int, int)> changes) =>
    changes.every(
      ((int, int, int) change) => allowed.any(
        ((int, int) range) => range.$1 <= change.$1 && change.$2 <= range.$2,
      ),
    );

bool roundTripHolds({required String sourceAtSave, required String reopened}) =>
    reopened == sourceAtSave.trim();

final class ProbeRect {
  const ProbeRect(this.left, this.top, this.width, this.height);

  factory ProbeRect.fromJson(List<Object?> json) {
    if (json.length != 4 || json.any((Object? value) => value is! num)) {
      throw FormatException('a rect is [left, top, width, height]', '$json');
    }
    return ProbeRect(
      (json[0]! as num).toDouble(),
      (json[1]! as num).toDouble(),
      (json[2]! as num).toDouble(),
      (json[3]! as num).toDouble(),
    );
  }

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  @override
  String toString() => 'ProbeRect($left, $top, $width, $height)';
}

bool rectsMatch(ProbeRect a, ProbeRect b, {double tolerance = 0.5}) =>
    (a.left - b.left).abs() <= tolerance &&
    (a.top - b.top).abs() <= tolerance &&
    (a.width - b.width).abs() <= tolerance &&
    (a.height - b.height).abs() <= tolerance;

bool rectInside(ProbeRect inner, ProbeRect outer, {double tolerance = 0.5}) =>
    inner.left >= outer.left - tolerance &&
    inner.top >= outer.top - tolerance &&
    inner.right <= outer.right + tolerance &&
    inner.bottom <= outer.bottom + tolerance;

bool rectsOverlapOrTouch(ProbeRect a, ProbeRect b, {double tolerance = 0.5}) =>
    a.left <= b.right + tolerance &&
    b.left <= a.right + tolerance &&
    a.top <= b.bottom + tolerance &&
    b.top <= a.bottom + tolerance;

bool caretWithin({
  required double dx,
  required double dTop,
  required double dBottom,
  double tolerance = 1,
}) =>
    dx.abs() <= tolerance &&
    dTop.abs() <= tolerance &&
    dBottom.abs() <= tolerance;

enum OracleSize {
  small(1 / 3),
  medium(1 / 2),
  large(2 / 3),
  full(1);

  const OracleSize(this.fraction);

  final double fraction;
}

enum OracleSide { left, centre, right }

final class PhotoPlanExpectation {
  const PhotoPlanExpectation({
    required this.width,
    required this.height,
    required this.floats,
  });

  final double width;
  final double height;
  final bool floats;
}

PhotoPlanExpectation expectedPhotoPlan({
  required double column,
  required double em,
  required OracleSize size,
  required OracleSide side,
  required bool validPlacement,
  int? pixelWidth,
  int? pixelHeight,
}) {
  final bool phone = column < 30 * em;
  final OracleSize drawnSize = validPlacement ? size : OracleSize.medium;
  final OracleSide drawnSide = validPlacement ? side : OracleSide.centre;
  final double width = phone ? column : column * drawnSize.fraction;
  final bool floats =
      !phone &&
      drawnSide != OracleSide.centre &&
      drawnSize != OracleSize.full &&
      validPlacement &&
      column - width - em >= 12 * em;
  final double height =
      pixelWidth == null ||
          pixelHeight == null ||
          pixelWidth <= 0 ||
          pixelHeight <= 0
      ? width * 2 / 3
      : _clampedHeight(width, pixelWidth / pixelHeight);
  return PhotoPlanExpectation(width: width, height: height, floats: floats);
}

double _clampedHeight(double width, double aspect) {
  final double natural = width / aspect;
  final double ceiling = 1.6 * width;
  return natural < ceiling ? natural : ceiling;
}

bool verticalGoalHolds({
  required double caretX,
  required double goalX,
  required double glyphAdvance,
  required bool lineShorterThanGoal,
  required double lineEndX,
}) => lineShorterThanGoal
    ? (caretX - lineEndX).abs() <= 0.5
    : (caretX - goalX).abs() <= glyphAdvance;

bool clickLandsOnNearerEdge({
  required double clickX,
  required double glyphLeft,
  required double glyphRight,
  required int offsetBefore,
  required int offsetAfter,
  required int landed,
}) =>
    landed ==
    (clickX >= (glyphLeft + glyphRight) / 2 ? offsetAfter : offsetBefore);

final class SelectionCoverage {
  const SelectionCoverage({
    required this.missing,
    required this.extra,
    required this.overlapping,
  });

  final int missing;
  final int extra;
  final int overlapping;
}

bool _intersectsBeyond(ProbeRect a, ProbeRect b, double tolerance) {
  final double left = a.left > b.left ? a.left : b.left;
  final double right = a.right < b.right ? a.right : b.right;
  final double top = a.top > b.top ? a.top : b.top;
  final double bottom = a.bottom < b.bottom ? a.bottom : b.bottom;
  return right - left > tolerance && bottom - top > tolerance;
}

SelectionCoverage selectionCoverage({
  required List<ProbeRect> selection,
  required List<(ProbeRect, bool)> glyphs,
  required List<ProbeRect> photos,
  required List<ProbeRect> gutters,
}) {
  final int missing = glyphs
      .where(((ProbeRect, bool) glyph) => glyph.$2)
      .where(
        ((ProbeRect, bool) glyph) =>
            !selection.any((ProbeRect box) => rectInside(glyph.$1, box)),
      )
      .length;
  final int extra = glyphs
      .where(((ProbeRect, bool) glyph) => !glyph.$2)
      .where(
        ((ProbeRect, bool) glyph) => selection.any(
          (ProbeRect box) => _intersectsBeyond(glyph.$1, box, 0.5),
        ),
      )
      .length;
  final List<ProbeRect> forbidden = <ProbeRect>[...photos, ...gutters];
  final int overlapping = selection
      .where(
        (ProbeRect box) => forbidden.any(
          (ProbeRect area) => _intersectsBeyond(box, area, 0.5),
        ),
      )
      .length;
  return SelectionCoverage(
    missing: missing,
    extra: extra,
    overlapping: overlapping,
  );
}

bool fragmentsClearFloat({
  required ProbeRect float,
  required OracleSide side,
  required double em,
  required List<(double, double)> fragments,
}) => switch (side) {
  OracleSide.left => fragments.every(
    ((double, double) fragment) => fragment.$1 >= float.right + em - 0.5,
  ),
  OracleSide.right => fragments.every(
    ((double, double) fragment) => fragment.$2 <= float.left - em + 0.5,
  ),
  OracleSide.centre => true,
};
