import 'dart:ui' show TextAffinity;

import 'package:field_notes/features/note_engine/document/change_set.dart';

final class NoteSelection {
  const NoteSelection({
    required this.anchor,
    required this.head,
    this.affinity = TextAffinity.downstream,
  }) : assert(anchor >= 0, 'anchor must not be negative'),
       assert(head >= 0, 'head must not be negative');

  const NoteSelection.collapsed(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) : this(anchor: offset, head: offset, affinity: affinity);

  final int anchor;
  final int head;
  final TextAffinity affinity;

  bool get isCollapsed => anchor == head;

  int get start => anchor < head ? anchor : head;

  int get end => anchor < head ? head : anchor;

  NoteSelection mapped(ChangeSet changes, {required MapSide side}) =>
      NoteSelection(
        anchor: changes.mapPosition(anchor, side: side),
        head: changes.mapPosition(head, side: side),
        affinity: affinity,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteSelection &&
          anchor == other.anchor &&
          head == other.head &&
          affinity == other.affinity;

  @override
  int get hashCode => Object.hash(anchor, head, affinity);

  @override
  String toString() => 'NoteSelection($anchor, $head, ${affinity.name})';
}
