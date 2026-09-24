import 'dart:async';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/photos/photo_relocation.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

const double photoDragMouseThreshold = 4;
const Duration photoDragLongPress = Duration(milliseconds: 400);
const double photoDragAutoScrollBand = 48;
const double photoDragAutoScrollMaxSpeed = 1200;
const double photoInsertionLineThickness = 2;
const double photoDragGhostOpacity = 0.5;
const Key photoDragGhostKey = ValueKey<String>('photo-drag-ghost');

@immutable
final class PhotoDropTarget {
  const PhotoDropTarget({required this.boundary, required this.y});

  final int boundary;
  final double y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoDropTarget && boundary == other.boundary && y == other.y;

  @override
  int get hashCode => Object.hash(boundary, y);

  @override
  String toString() => 'PhotoDropTarget($boundary, y: $y)';
}

List<PhotoDropTarget> photoDropTargets(
  String source,
  MdTree tree,
  NoteLayout layout,
) {
  final List<int> boundaries = photoBoundaries(source, tree);
  final List<MdBlock> units = photoRelocationUnits(tree);
  final Map<MdRange, Rect> photos = <MdRange, Rect>{
    for (final PhotoRect photo in layout.photoRects)
      photo.sourceRange: photo.rect,
  };
  Rect bounds(MdBlock unit) =>
      (unit.kind == MdBlockKind.photoLine ? photos[unit.sourceRange] : null) ??
      layout.rangeBounds(unit.sourceRange);
  final Map<int, int> unitEndingAt = <int, int>{
    for (int i = 0; i < units.length; i++) units[i].sourceRange.end: i,
  };
  return List<PhotoDropTarget>.unmodifiable(<PhotoDropTarget>[
    for (int i = 0; i < boundaries.length; i++)
      PhotoDropTarget(
        boundary: boundaries[i],
        y: i == 0 && boundaries[i] == 0
            ? 0
            : _boundaryY(units, unitEndingAt[boundaries[i]]!, bounds),
      ),
  ]);
}

double _boundaryY(
  List<MdBlock> units,
  int index,
  Rect Function(MdBlock unit) bounds,
) {
  final double bottom = bounds(units[index]).bottom;
  if (index + 1 >= units.length) {
    return bottom;
  }
  final double nextTop = bounds(units[index + 1]).top;
  return nextTop < bottom ? nextTop : bottom;
}

PhotoDropTarget? nearestPhotoDropTarget(
  List<PhotoDropTarget> targets,
  double y,
) {
  PhotoDropTarget? nearest;
  double best = double.infinity;
  for (final PhotoDropTarget target in targets) {
    final double distance = (target.y - y).abs();
    if (distance < best) {
      best = distance;
      nearest = target;
    }
  }
  return nearest;
}

@immutable
final class PhotoDragSession {
  const PhotoDragSession({
    required this.photo,
    required this.source,
    required this.figure,
    required this.press,
    required this.pointer,
    this.target,
  });

  final MdBlock photo;
  final String source;
  final Rect figure;
  final Offset press;
  final Offset pointer;
  final PhotoDropTarget? target;

  Offset get ghostTopLeft => figure.topLeft + (pointer - press);
}

PhotoDragSession _following(
  PhotoDragSession session,
  Offset pointer,
  PhotoDropTarget? target,
) => PhotoDragSession(
  photo: session.photo,
  source: session.source,
  figure: session.figure,
  press: session.press,
  pointer: pointer,
  target: target,
);

@immutable
final class _Press {
  const _Press({
    required this.pointer,
    required this.isTouch,
    required this.position,
    required this.photo,
    required this.figure,
  });

  final int pointer;
  final bool isTouch;
  final Offset position;
  final MdBlock photo;
  final Rect figure;
}

typedef _ScrollBand = ({double direction, double speed});

final class PhotoDragController extends ChangeNotifier
    implements GestureArenaMember {
  PhotoDragController({
    required this._vsync,
    required this._readState,
    required this._targets,
    required this._scrollPosition,
    required this._viewport,
    required this._toContent,
  });

  final TickerProvider _vsync;
  final EditorState Function() _readState;
  final List<PhotoDropTarget> Function() _targets;
  final ScrollPosition Function() _scrollPosition;
  final Rect Function() _viewport;
  final Offset Function(Offset global) _toContent;

  _Press? _press;
  Timer? _longPressTimer;
  bool _longPressFired = false;
  bool _cancelled = false;
  GestureArenaEntry? _arenaEntry;
  PhotoDragSession? _session;
  Offset _pointerGlobal = Offset.zero;
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  PhotoDragSession? get session => _session;

  bool get isDragging => _session != null;

  void pointerDown(PointerDownEvent event, MdBlock photo, Rect figure) {
    if (_press != null) {
      return;
    }
    final bool isTouch = _isTouch(event.kind);
    _press = _Press(
      pointer: event.pointer,
      isTouch: isTouch,
      position: event.position,
      photo: photo,
      figure: figure,
    );
    _longPressFired = false;
    _cancelled = false;
    if (isTouch) {
      _arenaEntry = GestureBinding.instance.gestureArena.add(
        event.pointer,
        this,
      );
      _longPressTimer = Timer(photoDragLongPress, _onLongPress);
    }
  }

  bool pointerMove(PointerMoveEvent event) {
    final _Press? press = _press;
    if (press == null || event.pointer != press.pointer) {
      return false;
    }
    if (_session != null) {
      _pointerGlobal = event.position;
      _follow();
      _updateAutoScroll();
      return true;
    }
    if (_cancelled) {
      return false;
    }
    final double distance = (event.position - press.position).distance;
    if (press.isTouch) {
      if (!_longPressFired) {
        if (distance > kTouchSlop) {
          _reset();
        }
        return false;
      }
    } else if (distance < photoDragMouseThreshold) {
      return false;
    }
    _start(press, event.position);
    return true;
  }

  Transaction? pointerUp(PointerUpEvent event) {
    final _Press? press = _press;
    if (press == null || event.pointer != press.pointer) {
      return null;
    }
    final PhotoDragSession? session = _session;
    _reset();
    if (session == null) {
      return null;
    }
    final PhotoDropTarget? target = session.target;
    final EditorState state = _readState();
    if (target == null || state.source != session.source) {
      return null;
    }
    final PhotoEdit? edit = photoRelocation(
      state.source,
      state.tree,
      session.photo,
      target.boundary,
    );
    if (edit == null) {
      return null;
    }
    return Transaction(
      changes: edit.changes,
      selection: edit.selection,
      event: TransactionEvent.photo,
    );
  }

  void pointerCancel() => _reset();

  bool escape() {
    if (_session == null) {
      return false;
    }
    _stopAutoScroll();
    _session = null;
    _cancelled = true;
    notifyListeners();
    return true;
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer == _press?.pointer) {
      _arenaEntry = null;
    }
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer != _press?.pointer) {
      return;
    }
    _arenaEntry = null;
    if (!_longPressFired && _session == null) {
      _reset();
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _press = null;
    _session = null;
    _resolveArena(GestureDisposition.rejected);
    _stopAutoScroll();
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  void _onLongPress() {
    _longPressTimer = null;
    _longPressFired = true;
  }

  void _start(_Press press, Offset position) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _resolveArena(GestureDisposition.accepted);
    final Offset pointer = _toContent(position);
    _pointerGlobal = position;
    _session = PhotoDragSession(
      photo: press.photo,
      source: _readState().source,
      figure: press.figure,
      press: _toContent(press.position),
      pointer: pointer,
      target: nearestPhotoDropTarget(_targets(), pointer.dy),
    );
    notifyListeners();
    _updateAutoScroll();
  }

  void _follow() {
    final PhotoDragSession? session = _session;
    if (session == null) {
      return;
    }
    final Offset pointer = _toContent(_pointerGlobal);
    final PhotoDropTarget? target = nearestPhotoDropTarget(
      _targets(),
      pointer.dy,
    );
    if (pointer == session.pointer && target == session.target) {
      return;
    }
    _session = _following(session, pointer, target);
    notifyListeners();
  }

  void _reset() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _press = null;
    _longPressFired = false;
    _cancelled = false;
    _resolveArena(GestureDisposition.rejected);
    _stopAutoScroll();
    if (_session != null) {
      _session = null;
      notifyListeners();
    }
  }

  void _resolveArena(GestureDisposition disposition) {
    final GestureArenaEntry? entry = _arenaEntry;
    _arenaEntry = null;
    entry?.resolve(disposition);
  }

  _ScrollBand? _band() {
    final Rect viewport = _viewport();
    final double fromTop = _pointerGlobal.dy - viewport.top;
    final double fromBottom = viewport.bottom - _pointerGlobal.dy;
    final double direction;
    final double distance;
    if (fromTop < photoDragAutoScrollBand) {
      direction = -1;
      distance = fromTop;
    } else if (fromBottom < photoDragAutoScrollBand) {
      direction = 1;
      distance = fromBottom;
    } else {
      return null;
    }
    final double clamped = distance.clamp(0, photoDragAutoScrollBand);
    return (
      direction: direction,
      speed:
          photoDragAutoScrollMaxSpeed *
          (photoDragAutoScrollBand - clamped) /
          photoDragAutoScrollBand,
    );
  }

  bool _atExtent(ScrollPosition position, double direction) => direction < 0
      ? position.pixels <= position.minScrollExtent
      : position.pixels >= position.maxScrollExtent;

  void _updateAutoScroll() {
    final _ScrollBand? band = _band();
    if (_session == null ||
        band == null ||
        _atExtent(_scrollPosition(), band.direction)) {
      _stopAutoScroll();
      return;
    }
    final Ticker ticker = _ticker ??= _vsync.createTicker(_tick);
    if (!ticker.isActive) {
      _lastTick = Duration.zero;
      ticker.start();
    }
  }

  void _stopAutoScroll() {
    final Ticker? ticker = _ticker;
    if (ticker != null && ticker.isActive) {
      ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final _ScrollBand? band = _band();
    if (_session == null || band == null) {
      _stopAutoScroll();
      return;
    }
    final double seconds =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    final ScrollPosition position = _scrollPosition();
    final double next =
        (position.pixels + band.direction * band.speed * seconds).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    if (next != position.pixels) {
      position.jumpTo(next);
    }
    if (_atExtent(position, band.direction)) {
      _stopAutoScroll();
    }
    _follow();
  }

  static bool _isTouch(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.touch ||
      kind == PointerDeviceKind.stylus ||
      kind == PointerDeviceKind.invertedStylus;
}

final class PhotoInsertionLineDecoration extends NoteViewDecoration {
  const PhotoInsertionLineDecoration(this.y);

  final double y;

  @override
  void paint(
    Canvas canvas,
    NoteLayout layout,
    Rect? Function(Rect contentRect) place,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        y - photoInsertionLineThickness / 2,
        layout.size.width,
        photoInsertionLineThickness,
      ),
      Paint()..color = Palette.coral,
    );
  }

  @override
  bool shouldRepaint(NoteViewDecoration oldDecoration) =>
      oldDecoration is! PhotoInsertionLineDecoration || oldDecoration.y != y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoInsertionLineDecoration && y == other.y;

  @override
  int get hashCode => y.hashCode;

  @override
  String toString() => 'PhotoInsertionLineDecoration($y)';
}

class PhotoDragOverlay extends StatelessWidget {
  const PhotoDragOverlay({
    super.key,
    required this.controller,
    required this.contentToLocal,
    required this.ghost,
  });

  final PhotoDragController controller;
  final Offset Function(Offset content) contentToLocal;
  final Widget ghost;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (BuildContext context, Widget? child) {
      final PhotoDragSession? session = controller.session;
      if (session == null) {
        return const SizedBox.shrink();
      }
      final Offset topLeft = contentToLocal(session.ghostTopLeft);
      return Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: topLeft.dx,
            top: topLeft.dy,
            width: session.figure.width,
            height: session.figure.height,
            child: child!,
          ),
        ],
      );
    },
    child: IgnorePointer(
      child: Opacity(
        opacity: photoDragGhostOpacity,
        child: KeyedSubtree(key: photoDragGhostKey, child: ghost),
      ),
    ),
  );
}
