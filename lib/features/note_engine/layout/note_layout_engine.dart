import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/caret_geometry.dart';
import 'package:field_notes/features/note_engine/layout/float_flow.dart';
import 'package:field_notes/features/note_engine/layout/hit_testing.dart';
import 'package:field_notes/features/note_engine/layout/layout_cache.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/photo_planner.dart';
import 'package:field_notes/features/note_engine/layout/table_layout.dart';
import 'package:field_notes/features/note_engine/layout/vertical_motion.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show TextSelectionPoint;

const int _lineFeed = 0x0A;

final class NoteLayoutEngine {
  NoteLayoutEngine({
    this._projector = const NoteVisibleProjector(),
    LayoutCache? cache,
  }) : _cache = cache ?? LayoutCache();

  final NoteVisibleProjector _projector;
  final LayoutCache _cache;
  _PassRecord? _last;
  List<int> _lastRelaidBlocks = const <int>[];

  List<int> get lastRelaidBlocks => _lastRelaidBlocks;

  LaidOutNote layout(LayoutInputs inputs) {
    _cache.beginPass();
    final _PassRecord? last = _last;
    final _Pass pass = _Pass(
      _cache,
      last != null && last.servesInputs(inputs) ? last : null,
      inputs,
      mark: true,
    );
    final NoteFlow flow = pass.flow();
    _cache.evictUnused();
    final _PassRecord record = pass.record();
    _last = record;
    final Set<int> relaid = <int>{
      ...pass.rowMisses,
      for (final int call in pass.planMisses)
        if (call < flow.photos.length)
          flow.rows[flow.photos[call].rowIndex].row.blockIndex,
    };
    _lastRelaidBlocks = List<int>.unmodifiable(relaid.toList()..sort());
    return LaidOutNote._(
      inputs: inputs,
      flow: flow,
      activeLayout: inputs.readerMode
          ? (int activeLine, {int? activeCell}) => flow
          : _activeLayoutFor(inputs, record),
    );
  }

  void clearCache() {
    _cache.clear();
    _last = null;
  }

  ActiveLayout _activeLayoutFor(LayoutInputs inputs, _PassRecord record) =>
      (int activeLine, {int? activeCell}) {
        final LayoutInputs active = LayoutInputs(
          source: inputs.source,
          tree: inputs.tree,
          visibleText: _projector.project(
            inputs.source,
            inputs.tree,
            activeLine,
            activeCell: activeCell,
          ),
          activeLine: activeLine,
          columnWidth: inputs.columnWidth,
          textScaler: inputs.textScaler,
          boldText: inputs.boldText,
          locale: inputs.locale,
          readerMode: inputs.readerMode,
          mediaDimensions: inputs.mediaDimensions,
          unavailableMedia: inputs.unavailableMedia,
        );
        return _Pass(_cache, record, active, mark: false).flow();
      };
}

typedef _Slot = ({double width, bool besideFloat, int? from, int? to});

typedef _Entry = ({_Slot slot, LaidOutRow layout});

final class _PassRecord {
  _PassRecord(this.plan, List<List<_Entry>?> entries)
    : _entries = List<List<_Entry>?>.unmodifiable(entries);

  final LayoutRowPlan plan;
  final List<List<_Entry>?> _entries;

  bool servesInputs(LayoutInputs inputs) {
    final LayoutInputs laid = plan.inputs;
    return laid.columnWidth == inputs.columnWidth &&
        laid.textScaler == inputs.textScaler &&
        laid.boldText == inputs.boldText &&
        laid.locale == inputs.locale;
  }

  LaidOutRow? layoutAt(int row, _Slot slot) {
    final List<_Entry>? entries = row < 0 || row >= _entries.length
        ? null
        : _entries[row];
    if (entries == null) {
      return null;
    }
    for (final _Entry entry in entries) {
      final _Slot kept = entry.slot;
      if (kept.width == slot.width &&
          kept.besideFloat == slot.besideFloat &&
          kept.from == slot.from &&
          kept.to == slot.to) {
        return entry.layout;
      }
    }
    return null;
  }
}

final class _Pass {
  factory _Pass(
    LayoutCache cache,
    _PassRecord? previous,
    LayoutInputs inputs, {
    required bool mark,
  }) => _Pass._(
    cache,
    previous,
    planLayoutRows(inputs, previous: previous?.plan),
    mark: mark,
  );

  _Pass._(this.cache, this.previous, this.plan, {required this.mark})
    : _laid = List<List<_Entry>?>.filled(plan.rows.length, null);

  final LayoutCache cache;
  final _PassRecord? previous;
  final LayoutRowPlan plan;
  final bool mark;
  final List<int> rowMisses = <int>[];
  final List<int> planMisses = <int>[];
  final List<List<_Entry>?> _laid;
  int _planCalls = 0;

  NoteFlow flow() => flowLayoutRows(
    plan.inputs,
    plan.rows,
    rowLayouter: _layoutRow,
    photoPlanner: _planPhoto,
  );

  _PassRecord record() => _PassRecord(plan, _laid);

  LaidOutRow _layoutRow(
    LayoutInputs inputs,
    LayoutRow row,
    RowRegion region, {
    int? visibleFrom,
    int? visibleTo,
  }) {
    final int base = row.visibleRange.start;
    final _Slot slot = (
      width: region.width,
      besideFloat: region.besideFloat,
      from: visibleFrom == null ? null : visibleFrom - base,
      to: visibleTo == null ? null : visibleTo - base,
    );
    final int? reused = row.index < plan.reusedFrom.length
        ? plan.reusedFrom[row.index]
        : null;
    final LaidOutRow? kept = reused == null
        ? null
        : previous?.layoutAt(reused, slot);
    if (kept != null) {
      _remember(row.index, slot, kept);
      return kept.shifted(Offset(region.left, region.top), base, row: row);
    }
    final LaidOutRow fresh = row.kind == LayoutRowKind.table
        ? layoutTableRow(
            inputs,
            row,
            region,
            visibleFrom: visibleFrom,
            visibleTo: visibleTo,
          )
        : layoutRow(
            inputs,
            row,
            region,
            visibleFrom: visibleFrom,
            visibleTo: visibleTo,
          );
    _remember(
      row.index,
      slot,
      fresh.shifted(Offset(-region.left, -region.top), -base, row: row),
    );
    rowMisses.add(row.blockIndex);
    return fresh;
  }

  void _remember(int row, _Slot slot, LaidOutRow layout) {
    (_laid[row] ??= <_Entry>[]).add((slot: slot, layout: layout));
  }

  PhotoLayoutPlan _planPhoto({
    required MdPhotoPlacement placement,
    required double columnWidth,
    required TextScaler textScaler,
    double? aspect,
    bool unavailable = false,
    String caption = '',
    bool boldText = false,
    Locale? locale,
  }) {
    final int call = _planCalls++;
    final PhotoPlanKey key = PhotoPlanKey(
      placement: placement,
      columnWidth: columnWidth,
      textScaler: textScaler,
      aspect: aspect,
      unavailable: unavailable,
      caption: caption,
      boldText: boldText,
      locale: locale,
    );
    final PhotoLayoutPlan? hit = cache.lookupPlan(key, mark: mark);
    if (hit != null) {
      return hit;
    }
    final PhotoLayoutPlan plan = planPhoto(
      placement: placement,
      columnWidth: columnWidth,
      textScaler: textScaler,
      aspect: aspect,
      unavailable: unavailable,
      caption: caption,
      boldText: boldText,
      locale: locale,
    );
    cache.storePlan(key, plan, mark: mark);
    planMisses.add(call);
    return plan;
  }
}

final class LaidOutNote implements NoteLayout {
  LaidOutNote._({
    required this.inputs,
    required this.flow,
    required this._activeLayout,
  });

  @override
  final LayoutInputs inputs;

  final NoteFlow flow;
  final ActiveLayout _activeLayout;

  late final CaretGeometry geometry = CaretGeometry(flow: flow);

  late final NoteHitTester hitTester = NoteHitTester(flow: flow);

  @override
  late final List<FragmentInfo> fragments = _fragmentsOf();

  @override
  late final List<PhotoRect> photoRects = List<PhotoRect>.unmodifiable(
    <PhotoRect>[
      for (final PlacedPhoto photo in flow.photos)
        PhotoRect(
          sourceRange: MdRange(photo.sourceRange.start, photo.sourceRange.end),
          reference: photo.reference,
          occurrence: photo.occurrence,
          rect: photo.figureRect,
          imageRect: photo.imageRect,
          flow: switch (photo.plan.mode) {
            PhotoMode.floatLeft => PhotoFlow.floatLeft,
            PhotoMode.floatRight => PhotoFlow.floatRight,
            PhotoMode.centred => PhotoFlow.block,
          },
        ),
    ],
  );

  @override
  Size get size => Size(inputs.columnWidth, flow.height);

  @override
  Rect caretRect(int position, TextAffinity affinity) =>
      geometry.caretRect(position, affinity);

  @override
  List<Rect> selectionBoxes(NoteSelection selection) => geometry.selectionBoxes(
    TextRange(start: selection.start, end: selection.end),
  );

  @override
  SelectionEndpoints selectionEndpoints(NoteSelection selection) {
    final ({
      TextSelectionPoint start,
      double startLineHeight,
      TextSelectionPoint end,
      double endLineHeight,
    })
    endpoints = geometry.selectionEndpoints(
      TextRange(start: selection.start, end: selection.end),
      collapsedAffinity: selection.affinity,
    );
    return SelectionEndpoints(
      start: endpoints.start,
      end: endpoints.end,
      startLineHeight: endpoints.startLineHeight,
      endLineHeight: endpoints.endLineHeight,
    );
  }

  @override
  Rect rangeBounds(MdRange range) =>
      geometry.rangeBounds(TextRange(start: range.start, end: range.end));

  @override
  LineBox lineBoxAt(int position, TextAffinity affinity) => LineBox(
    rect: geometry.lineBoxAt(position, affinity),
    baseline: geometry.locate(position, affinity).line.baseline,
  );

  @override
  TextPosition positionAt(Offset point) => hitTester.positionAt(point);

  @override
  MdRange wordBoundary(int position) =>
      _mdRange(hitTester.wordBoundary(position));

  @override
  MdRange lineBoundary(int position, TextAffinity affinity) =>
      _mdRange(hitTester.lineBoundary(position, affinity));

  @override
  MdRange paragraphBoundary(int position) =>
      _mdRange(hitTester.paragraphBoundary(position));

  @override
  MdRange get documentBoundary => MdRange(0, inputs.source.length);

  @override
  TextPosition verticalTarget(
    int position,
    TextAffinity affinity,
    double goalX,
    VerticalMove direction,
  ) => findVerticalTarget(
    flow: flow,
    position: position,
    affinity: affinity,
    goalX: goalX,
    direction: direction,
    layoutWithActive: _activeLayout,
  );

  List<FragmentInfo> _fragmentsOf() {
    final VisibleText visible = inputs.visibleText;
    final OffsetMap map = visible.map;
    final String text = visible.text;
    final List<FragmentInfo> infos = <FragmentInfo>[];
    for (final LaidOutRow row in flow.rows) {
      for (final LineFragment fragment in row.fragments) {
        if (fragment.kind == FragmentKind.photo) {
          continue;
        }
        for (final VisualLine line in fragment.lines) {
          final int end = line.visibleRange.end;
          final bool endsSourceLine =
              end >= text.length || text.codeUnitAt(end) == _lineFeed;
          final int sourceStart = map
              .visibleToSource(line.visibleRange.start)
              .upstream;
          final SourceOffsets endOffsets = map.visibleToSource(end);
          final int sourceEnd = endsSourceLine
              ? endOffsets.downstream
              : endOffsets.upstream;
          infos.add(
            FragmentInfo(
              blockIndex: row.row.blockIndex,
              sourceRange: MdRange(
                sourceStart,
                sourceEnd < sourceStart ? sourceStart : sourceEnd,
              ),
              visibleRange: MdRange(line.visibleRange.start, end),
              lineBox: LineBox(
                rect: Rect.fromLTWH(
                  fragment.origin.dx,
                  line.top,
                  fragment.layoutWidth,
                  line.height,
                ),
                baseline: line.baseline,
              ),
              besideFloat: fragment.besideFloat,
            ),
          );
        }
      }
    }
    return List<FragmentInfo>.unmodifiable(infos);
  }

  static MdRange _mdRange(TextRange range) => MdRange(range.start, range.end);
}

Future<({Map<String, Size> dimensions, Set<String> unavailable})>
readPhotoDimensions(MdTree tree, MediaResolver resolver) async {
  final List<MdPhotoLineData> photos = <MdPhotoLineData>[];
  final Set<String> seen = <String>{};
  for (final MdBlock block in tree.blocks) {
    final MdBlockData? data = block.data;
    if (block.kind == MdBlockKind.photoLine &&
        data is MdPhotoLineData &&
        seen.add(data.reference)) {
      photos.add(data);
    }
  }
  final List<(String, ResolvedMedia?)> results =
      await Future.wait(<Future<(String, ResolvedMedia?)>>[
        for (final MdPhotoLineData photo in photos)
          if (photo.canResolve) _lookUp(resolver, photo.reference),
      ]);
  final Map<String, Size> dimensions = <String, Size>{};
  final Set<String> unavailable = <String>{
    for (final MdPhotoLineData photo in photos)
      if (!photo.canResolve) photo.reference,
  };
  for (final (String reference, ResolvedMedia? media) in results) {
    if (media == null || !media.isAvailable) {
      unavailable.add(reference);
      continue;
    }
    final int? width = media.blob?.width;
    final int? height = media.blob?.height;
    if (width != null && height != null && width > 0 && height > 0) {
      dimensions[reference] = Size(width.toDouble(), height.toDouble());
    }
  }
  return (
    dimensions: Map<String, Size>.unmodifiable(dimensions),
    unavailable: Set<String>.unmodifiable(unavailable),
  );
}

Future<(String, ResolvedMedia?)> _lookUp(
  MediaResolver resolver,
  String reference,
) async {
  final ResolvedMedia? known = resolver.resolved(reference);
  if (known != null) {
    return (reference, known);
  }
  try {
    return (reference, await resolver.resolve(reference));
  } on Object {
    return (reference, null);
  }
}
