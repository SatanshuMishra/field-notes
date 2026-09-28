final class MdRange {
  const MdRange(this.start, this.end)
    : assert(start >= 0, 'start must not be negative'),
      assert(end >= start, 'end must not precede start');

  final int start;
  final int end;

  int get length => end - start;

  bool get isEmpty => start == end;

  bool contains(int offset) => start <= offset && offset < end;

  MdRange shifted(int delta) => MdRange(start + delta, end + delta);

  String sliceOf(String source) => source.substring(start, end);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'MdRange($start, $end)';
}

enum MdBlockKind {
  heading,
  thematicBreak,
  fencedCode,
  paragraph,
  blankLine,
  blockQuote,
  bulletList,
  orderedList,
  listItem,
  table,
  tableRow,
  tableCell,
  photoLine,
}

enum MdInlineKind {
  text,
  softBreak,
  hardBreak,
  codeSpan,
  emphasis,
  strong,
  strikethrough,
  highlight,
  link,
  autolink,
  escape,
}

enum MdTaskState { none, unchecked, checked }

enum MdListDelimiter { period, paren }

enum MdCellAlignment { none, left, centre, right }

enum MdAutolinkKind { uri, email }

sealed class MdNode {
  MdNode({
    required this.sourceRange,
    required this.contentRange,
    required List<MdRange> markerRanges,
  }) : assert(
         _isInside(contentRange, sourceRange),
         'content range must lie inside the source range',
       ),
       assert(
         markerRanges.every((MdRange r) => _isInside(r, sourceRange)),
         'every marker range must lie inside the source range',
       ),
       assert(
         _areOrdered(markerRanges),
         'marker ranges must be sorted and must not overlap',
       ),
       markerRanges = List<MdRange>.unmodifiable(markerRanges);

  final MdRange sourceRange;
  final MdRange contentRange;
  final List<MdRange> markerRanges;

  List<MdNode> get children;

  MdNode shifted(int delta);
}

final class MdBlock extends MdNode {
  MdBlock({
    required this.kind,
    required super.sourceRange,
    required super.contentRange,
    super.markerRanges = const <MdRange>[],
    List<MdBlock> blocks = const <MdBlock>[],
    List<MdInline> inlines = const <MdInline>[],
    this.data,
  }) : assert(
         _containerKinds.contains(kind) || blocks.isEmpty,
         'only container blocks hold blocks',
       ),
       assert(
         _inlineHostKinds.contains(kind) || inlines.isEmpty,
         'only headings, paragraphs and table cells hold inlines',
       ),
       assert(
         _childKindsFit(kind, blocks),
         'lists hold list items, tables hold rows and rows hold cells',
       ),
       assert(_blockDataFits(kind, data), 'block data must match its kind'),
       assert(
         _taskBoxFits(data, markerRanges),
         'a task box spans three units and is one of the item markers',
       ),
       assert(
         _childrenFit(<MdRange>[
           for (final MdBlock b in blocks) b.sourceRange,
         ], sourceRange),
         'child blocks must be sorted, disjoint and inside their parent',
       ),
       assert(
         _childrenFit(<MdRange>[
           for (final MdInline i in inlines) i.sourceRange,
         ], sourceRange),
         'inlines must be sorted, disjoint and inside their parent',
       ),
       blocks = List<MdBlock>.unmodifiable(blocks),
       inlines = List<MdInline>.unmodifiable(inlines);

  final MdBlockKind kind;
  final List<MdBlock> blocks;
  final List<MdInline> inlines;
  final MdBlockData? data;

  @override
  List<MdNode> get children =>
      _containerKinds.contains(kind) ? blocks : inlines;

  @override
  MdBlock shifted(int delta) => MdBlock(
    kind: kind,
    sourceRange: sourceRange.shifted(delta),
    contentRange: contentRange.shifted(delta),
    markerRanges: <MdRange>[
      for (final MdRange r in markerRanges) r.shifted(delta),
    ],
    blocks: <MdBlock>[for (final MdBlock b in blocks) b.shifted(delta)],
    inlines: <MdInline>[for (final MdInline i in inlines) i.shifted(delta)],
    data: data?.shifted(delta),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdBlock &&
          kind == other.kind &&
          sourceRange == other.sourceRange &&
          contentRange == other.contentRange &&
          data == other.data &&
          _listEquals(markerRanges, other.markerRanges) &&
          _listEquals(blocks, other.blocks) &&
          _listEquals(inlines, other.inlines);

  @override
  int get hashCode => Object.hash(
    kind,
    sourceRange,
    contentRange,
    Object.hashAll(markerRanges),
    Object.hashAll(blocks),
    Object.hashAll(inlines),
    data,
  );

  @override
  String toString() =>
      'MdBlock(${kind.name} $sourceRange, '
      'content: $contentRange, markers: $markerRanges'
      '${data == null ? '' : ', data: $data'}'
      '${children.isEmpty ? '' : ', children: $children'})';
}

final class MdInline extends MdNode {
  MdInline({
    required this.kind,
    required super.sourceRange,
    required super.contentRange,
    super.markerRanges = const <MdRange>[],
    List<MdInline> children = const <MdInline>[],
    this.data,
  }) : assert(
         _inlineParentKinds.contains(kind) || children.isEmpty,
         'only emphasis, strong, strikethrough, highlight and links nest',
       ),
       assert(_inlineDataFits(kind, data), 'inline data must match its kind'),
       assert(
         _childrenFit(<MdRange>[
           for (final MdInline c in children) c.sourceRange,
         ], sourceRange),
         'inline children must be sorted, disjoint and inside their parent',
       ),
       children = List<MdInline>.unmodifiable(children);

  final MdInlineKind kind;
  @override
  final List<MdInline> children;
  final MdInlineData? data;

  @override
  MdInline shifted(int delta) => MdInline(
    kind: kind,
    sourceRange: sourceRange.shifted(delta),
    contentRange: contentRange.shifted(delta),
    markerRanges: <MdRange>[
      for (final MdRange r in markerRanges) r.shifted(delta),
    ],
    children: <MdInline>[for (final MdInline c in children) c.shifted(delta)],
    data: data?.shifted(delta),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdInline &&
          kind == other.kind &&
          sourceRange == other.sourceRange &&
          contentRange == other.contentRange &&
          data == other.data &&
          _listEquals(markerRanges, other.markerRanges) &&
          _listEquals(children, other.children);

  @override
  int get hashCode => Object.hash(
    kind,
    sourceRange,
    contentRange,
    Object.hashAll(markerRanges),
    Object.hashAll(children),
    data,
  );

  @override
  String toString() =>
      'MdInline(${kind.name} $sourceRange, '
      'content: $contentRange, markers: $markerRanges'
      '${data == null ? '' : ', data: $data'}'
      '${children.isEmpty ? '' : ', children: $children'})';
}

sealed class MdBlockData {
  const MdBlockData();

  MdBlockData shifted(int delta);
}

final class MdHeadingData extends MdBlockData {
  const MdHeadingData(this.level)
    : assert(level >= 1 && level <= 6, 'heading level must be 1 to 6');

  final int level;

  @override
  MdHeadingData shifted(int delta) => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MdHeadingData && level == other.level;

  @override
  int get hashCode => level.hashCode;

  @override
  String toString() => 'MdHeadingData($level)';
}

final class MdFenceData extends MdBlockData {
  const MdFenceData({
    required this.fence,
    required this.info,
    required this.isClosed,
  }) : assert(fence.length >= 3, 'a fence is three or more characters');

  final String fence;
  final String info;
  final bool isClosed;

  @override
  MdFenceData shifted(int delta) => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdFenceData &&
          fence == other.fence &&
          info == other.info &&
          isClosed == other.isClosed;

  @override
  int get hashCode => Object.hash(fence, info, isClosed);

  @override
  String toString() =>
      "MdFenceData('$fence', info: '$info', isClosed: $isClosed)";
}

final class MdBulletListData extends MdBlockData {
  const MdBulletListData({required this.bullet, required this.isTight})
    : assert(
        bullet == '-' || bullet == '*' || bullet == '+',
        "bullet must be '-', '*' or '+'",
      );

  final String bullet;
  final bool isTight;

  @override
  MdBulletListData shifted(int delta) => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdBulletListData &&
          bullet == other.bullet &&
          isTight == other.isTight;

  @override
  int get hashCode => Object.hash(bullet, isTight);

  @override
  String toString() => "MdBulletListData('$bullet', isTight: $isTight)";
}

final class MdOrderedListData extends MdBlockData {
  const MdOrderedListData({
    required this.start,
    required this.delimiter,
    required this.isTight,
  }) : assert(start >= 0 && start <= 999999999, 'start must be 0 to 999999999');

  final int start;
  final MdListDelimiter delimiter;
  final bool isTight;

  @override
  MdOrderedListData shifted(int delta) => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdOrderedListData &&
          start == other.start &&
          delimiter == other.delimiter &&
          isTight == other.isTight;

  @override
  int get hashCode => Object.hash(start, delimiter, isTight);

  @override
  String toString() =>
      'MdOrderedListData($start, ${delimiter.name}, '
      'isTight: $isTight)';
}

final class MdListItemData extends MdBlockData {
  const MdListItemData({required this.taskState, this.taskBoxRange})
    : assert(
        (taskState == MdTaskState.none) == (taskBoxRange == null),
        'a task box range is present exactly when the item is a task',
      );

  final MdTaskState taskState;
  final MdRange? taskBoxRange;

  @override
  MdListItemData shifted(int delta) => MdListItemData(
    taskState: taskState,
    taskBoxRange: taskBoxRange?.shifted(delta),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdListItemData &&
          taskState == other.taskState &&
          taskBoxRange == other.taskBoxRange;

  @override
  int get hashCode => Object.hash(taskState, taskBoxRange);

  @override
  String toString() =>
      'MdListItemData(${taskState.name}'
      '${taskBoxRange == null ? '' : ', box: $taskBoxRange'})';
}

final class MdTableCellData extends MdBlockData {
  const MdTableCellData({required this.alignment});

  final MdCellAlignment alignment;

  @override
  MdTableCellData shifted(int delta) => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdTableCellData && alignment == other.alignment;

  @override
  int get hashCode => alignment.hashCode;

  @override
  String toString() => 'MdTableCellData(${alignment.name})';
}

final class MdPhotoLineData extends MdBlockData {
  const MdPhotoLineData({
    required this.reference,
    required this.referenceRange,
    required this.caption,
    required this.captionRange,
    required this.title,
    required this.titleRange,
  }) : assert(
         (title == null) == (titleRange == null),
         'title and title range are both null or both set',
       );

  final String reference;
  final MdRange referenceRange;
  final String caption;
  final MdRange captionRange;
  final String? title;
  final MdRange? titleRange;

  bool get canResolve {
    if (reference.length < 12 || reference.length > 64) {
      return false;
    }
    for (final int code in reference.codeUnits) {
      final bool isDigit = code >= 0x30 && code <= 0x39;
      final bool isLowerAToF = code >= 0x61 && code <= 0x66;
      if (!isDigit && !isLowerAToF) {
        return false;
      }
    }
    return true;
  }

  @override
  MdPhotoLineData shifted(int delta) => MdPhotoLineData(
    reference: reference,
    referenceRange: referenceRange.shifted(delta),
    caption: caption,
    captionRange: captionRange.shifted(delta),
    title: title,
    titleRange: titleRange?.shifted(delta),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdPhotoLineData &&
          reference == other.reference &&
          referenceRange == other.referenceRange &&
          caption == other.caption &&
          captionRange == other.captionRange &&
          title == other.title &&
          titleRange == other.titleRange;

  @override
  int get hashCode => Object.hash(
    reference,
    referenceRange,
    caption,
    captionRange,
    title,
    titleRange,
  );

  @override
  String toString() =>
      "MdPhotoLineData('$reference' $referenceRange, "
      "caption: '$caption' $captionRange"
      "${title == null ? '' : ", title: '$title' $titleRange"})";
}

sealed class MdInlineData {
  const MdInlineData();

  MdInlineData shifted(int delta);
}

final class MdLinkData extends MdInlineData {
  const MdLinkData({
    required this.destination,
    required this.destinationRange,
    this.title,
    this.titleRange,
  }) : assert(
         (title == null) == (titleRange == null),
         'title and title range are both null or both set',
       );

  final String destination;
  final MdRange destinationRange;
  final String? title;
  final MdRange? titleRange;

  @override
  MdLinkData shifted(int delta) => MdLinkData(
    destination: destination,
    destinationRange: destinationRange.shifted(delta),
    title: title,
    titleRange: titleRange?.shifted(delta),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdLinkData &&
          destination == other.destination &&
          destinationRange == other.destinationRange &&
          title == other.title &&
          titleRange == other.titleRange;

  @override
  int get hashCode =>
      Object.hash(destination, destinationRange, title, titleRange);

  @override
  String toString() =>
      "MdLinkData('$destination' $destinationRange"
      "${title == null ? '' : ", title: '$title' $titleRange"})";
}

final class MdAutolinkData extends MdInlineData {
  const MdAutolinkData({required this.kind, required this.target});

  final MdAutolinkKind kind;
  final String target;

  @override
  MdAutolinkData shifted(int delta) => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdAutolinkData && kind == other.kind && target == other.target;

  @override
  int get hashCode => Object.hash(kind, target);

  @override
  String toString() => "MdAutolinkData(${kind.name}, '$target')";
}

final class MdTree {
  MdTree({required this.sourceLength, required List<MdBlock> blocks})
    : assert(sourceLength >= 0, 'source length must not be negative'),
      assert(
        _childrenFit(<MdRange>[
          for (final MdBlock b in blocks) b.sourceRange,
        ], MdRange(0, sourceLength < 0 ? 0 : sourceLength)),
        'top-level blocks must be sorted, disjoint and inside the source',
      ),
      blocks = List<MdBlock>.unmodifiable(blocks);

  final int sourceLength;
  final List<MdBlock> blocks;

  MdBlock? blockAt(int offset) {
    final int? index = blockIndexAt(offset);
    return index == null ? null : blocks[index];
  }

  int? blockIndexAt(int offset) {
    if (offset < 0 || offset > sourceLength) {
      throw RangeError.range(offset, 0, sourceLength, 'offset');
    }
    int low = 0;
    int high = blocks.length - 1;
    int found = -1;
    while (low <= high) {
      final int mid = (low + high) >> 1;
      if (blocks[mid].sourceRange.start <= offset) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    if (found < 0 || offset > blocks[found].sourceRange.end) {
      return null;
    }
    return found;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdTree &&
          sourceLength == other.sourceLength &&
          _listEquals(blocks, other.blocks);

  @override
  int get hashCode => Object.hash(sourceLength, Object.hashAll(blocks));

  @override
  String toString() => 'MdTree($sourceLength, $blocks)';
}

const Set<MdBlockKind> _containerKinds = <MdBlockKind>{
  MdBlockKind.blockQuote,
  MdBlockKind.bulletList,
  MdBlockKind.orderedList,
  MdBlockKind.listItem,
  MdBlockKind.table,
  MdBlockKind.tableRow,
};

const Set<MdBlockKind> _inlineHostKinds = <MdBlockKind>{
  MdBlockKind.heading,
  MdBlockKind.paragraph,
  MdBlockKind.tableCell,
};

const Set<MdInlineKind> _inlineParentKinds = <MdInlineKind>{
  MdInlineKind.emphasis,
  MdInlineKind.strong,
  MdInlineKind.strikethrough,
  MdInlineKind.highlight,
  MdInlineKind.link,
};

bool _isInside(MdRange inner, MdRange outer) =>
    inner.start >= outer.start && inner.end <= outer.end;

bool _areOrdered(List<MdRange> ranges) {
  for (int i = 1; i < ranges.length; i++) {
    if (ranges[i - 1].end > ranges[i].start) {
      return false;
    }
  }
  return true;
}

bool _childrenFit(List<MdRange> ranges, MdRange parent) =>
    _areOrdered(ranges) && ranges.every((MdRange r) => _isInside(r, parent));

bool _childKindsFit(MdBlockKind kind, List<MdBlock> blocks) {
  final MdBlockKind? childKind = switch (kind) {
    MdBlockKind.bulletList || MdBlockKind.orderedList => MdBlockKind.listItem,
    MdBlockKind.table => MdBlockKind.tableRow,
    MdBlockKind.tableRow => MdBlockKind.tableCell,
    _ => null,
  };
  return childKind == null || blocks.every((MdBlock b) => b.kind == childKind);
}

bool _blockDataFits(MdBlockKind kind, MdBlockData? data) => switch (kind) {
  MdBlockKind.heading => data is MdHeadingData,
  MdBlockKind.fencedCode => data is MdFenceData,
  MdBlockKind.bulletList => data is MdBulletListData,
  MdBlockKind.orderedList => data is MdOrderedListData,
  MdBlockKind.listItem => data is MdListItemData,
  MdBlockKind.tableCell => data is MdTableCellData,
  MdBlockKind.photoLine => data is MdPhotoLineData,
  MdBlockKind.thematicBreak ||
  MdBlockKind.paragraph ||
  MdBlockKind.blankLine ||
  MdBlockKind.blockQuote ||
  MdBlockKind.table ||
  MdBlockKind.tableRow => data == null,
};

bool _inlineDataFits(MdInlineKind kind, MdInlineData? data) => switch (kind) {
  MdInlineKind.link => data is MdLinkData,
  MdInlineKind.autolink => data is MdAutolinkData,
  _ => data == null,
};

bool _taskBoxFits(MdBlockData? data, List<MdRange> markerRanges) {
  if (data is! MdListItemData) {
    return true;
  }
  final MdRange? box = data.taskBoxRange;
  return box == null || (box.length == 3 && markerRanges.contains(box));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
