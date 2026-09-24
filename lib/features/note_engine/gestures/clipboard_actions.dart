import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

String? noteCopyText(EditorState state) {
  final TextRange? photo = noteSelectedPhotoRange(
    state.tree,
    state.source,
    state.selection,
  );
  if (photo != null) {
    return state.source.substring(photo.start, photo.end);
  }
  final NoteSelection selection = state.selection;
  if (selection.isCollapsed) {
    return null;
  }
  return state.source.substring(selection.start, selection.end);
}

Transaction? noteCutTransaction(EditorState state) {
  final NoteSelection selection = state.selection;
  if (selection.isCollapsed ||
      noteSelectedPhotoRange(state.tree, state.source, selection) != null) {
    return null;
  }
  return Transaction(
    changes: ChangeSet.single(
      state.source.length,
      selection.start,
      selection.end,
      '',
    ),
    selection: NoteSelection.collapsed(selection.start),
    event: TransactionEvent.inputDelete,
  );
}

Transaction? notePasteTransaction(EditorState state, String text) {
  if (text.isEmpty) {
    return null;
  }
  final String source = state.source;
  final String lineBreak = _lineBreakOf(source);
  final TextRange? photo = noteSelectedPhotoRange(
    state.tree,
    source,
    state.selection,
  );
  if (photo != null) {
    final String inserted = lineBreak + text;
    return _pasteTransaction(source.length, <TextReplacement>[
      TextReplacement(photo.end, photo.end, inserted),
    ], photo.end + inserted.length);
  }
  final int start = state.selection.start;
  final int end = state.selection.end;
  final Transaction plain = _pasteTransaction(source.length, <TextReplacement>[
    TextReplacement(start, end, text),
  ], start + text.length);
  final List<_Line> candidates = _photoLines(text);
  if (candidates.isEmpty) {
    return plain;
  }
  final String remaining = _withoutLines(text, candidates);
  final MdTree bare = state.parse(source.replaceRange(start, end, remaining));
  if (_photoLinesLand(state, start, end, text, bare, candidates)) {
    return plain;
  }
  final MdBlock? holder = _holderAt(bare, start);
  if (holder != null && _isUnclosedFence(holder)) {
    return plain;
  }
  final String moved = _movedLines(
    text,
    candidates,
    lineBreak,
    atNoteStart: holder == null,
  );
  final int boundary = holder?.sourceRange.end ?? 0;
  final int pasted = start + remaining.length;
  if (holder != null && boundary >= pasted) {
    final int at = end + boundary - pasted;
    return _pasteTransaction(source.length, <TextReplacement>[
      TextReplacement(start, end, remaining),
      TextReplacement(at, at, moved),
    ], pasted);
  }
  if (boundary >= start) {
    final int split = boundary - start;
    return _pasteTransaction(source.length, <TextReplacement>[
      TextReplacement(
        start,
        end,
        remaining.substring(0, split) + moved + remaining.substring(split),
      ),
    ], pasted + moved.length);
  }
  return _pasteTransaction(source.length, <TextReplacement>[
    TextReplacement(boundary, boundary, moved),
    TextReplacement(start, end, remaining),
  ], pasted + moved.length);
}

MdBlock? _holderAt(MdTree tree, int offset) => tree.blocks
    .where((MdBlock block) => block.sourceRange.start <= offset)
    .lastOrNull;

String _movedLines(
  String text,
  List<_Line> lines,
  String lineBreak, {
  required bool atNoteStart,
}) {
  final StringBuffer buffer = StringBuffer();
  for (final _Line line in lines) {
    if (atNoteStart) {
      buffer
        ..write(_trimmed(text, line))
        ..write(lineBreak);
    } else {
      buffer
        ..write(lineBreak)
        ..write(_trimmed(text, line));
    }
  }
  return buffer.toString();
}

class NoteClipboardActions {
  NoteClipboardActions({
    required this._state,
    required this._dispatch,
    required this._select,
    required this._hideToolbar,
    required this._bringIntoView,
    required this._isActive,
    this._cutPhoto,
  });

  final EditorState Function() _state;
  final void Function(Transaction transaction) _dispatch;
  final void Function(NoteSelection selection, SelectionChangedCause cause)
  _select;
  final void Function([bool hideHandles]) _hideToolbar;
  final void Function(int sourceOffset) _bringIntoView;
  final bool Function() _isActive;
  final Transaction? Function(EditorState state)? _cutPhoto;

  Future<void> copySelection(SelectionChangedCause cause) async {
    final EditorState state = _state();
    final String? text = noteCopyText(state);
    if (text == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (cause != SelectionChangedCause.toolbar) {
      return;
    }
    final NoteSelection selection = state.selection;
    _bringIntoView(selection.head);
    _hideToolbar(false);
    if (defaultTargetPlatform == TargetPlatform.android) {
      _select(
        NoteSelection.collapsed(selection.end),
        SelectionChangedCause.toolbar,
      );
    }
  }

  Future<void> cutSelection(SelectionChangedCause cause) async {
    final EditorState state = _state();
    final String? text = noteCopyText(state);
    if (text == null) {
      return;
    }
    final bool photoSelected =
        noteSelectedPhotoRange(state.tree, state.source, state.selection) !=
        null;
    await Clipboard.setData(ClipboardData(text: text));
    final EditorState current = _state();
    final Transaction? transaction = photoSelected
        ? _cutPhoto?.call(current)
        : noteCutTransaction(current);
    if (transaction == null) {
      return;
    }
    _dispatch(transaction);
    _afterToolbarEdit(transaction, cause);
  }

  Future<void> pasteText(SelectionChangedCause cause) async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!_isActive()) {
      return;
    }
    final String? text = data?.text;
    if (text == null || text.isEmpty) {
      return;
    }
    final Transaction? transaction = notePasteTransaction(_state(), text);
    if (transaction == null) {
      return;
    }
    _dispatch(transaction);
    _afterToolbarEdit(transaction, cause);
  }

  void selectAll(SelectionChangedCause cause) {
    final int length = _state().source.length;
    _select(NoteSelection(anchor: 0, head: length), cause);
    if (cause != SelectionChangedCause.toolbar) {
      return;
    }
    _hideToolbar();
    if (defaultTargetPlatform == TargetPlatform.android) {
      _bringIntoView(length);
    }
  }

  void _afterToolbarEdit(Transaction transaction, SelectionChangedCause cause) {
    if (cause != SelectionChangedCause.toolbar) {
      return;
    }
    _hideToolbar();
    _bringIntoView(transaction.selection.head);
  }
}

final class _Line {
  const _Line(this.start, this.end, this.breakEnd);

  final int start;
  final int end;
  final int breakEnd;
}

const int _carriageReturn = 0x0D;
const int _space = 0x20;
const int _tab = 0x09;

Transaction _pasteTransaction(
  int length,
  List<TextReplacement> replacements,
  int caret,
) => Transaction(
  changes: ChangeSet(length: length, replacements: replacements),
  selection: NoteSelection.collapsed(caret),
  event: TransactionEvent.inputPaste,
);

String _lineBreakOf(String source) {
  final int first = source.indexOf('\n');
  return first > 0 && source.codeUnitAt(first - 1) == _carriageReturn
      ? '\r\n'
      : '\n';
}

bool _isUnclosedFence(MdBlock block) {
  final MdBlockData? data = block.data;
  return block.kind == MdBlockKind.fencedCode &&
      data is MdFenceData &&
      !data.isClosed;
}

List<_Line> _photoLines(String text) {
  final List<_Line> lines = <_Line>[];
  int start = 0;
  while (true) {
    final int feed = text.indexOf('\n', start);
    final int breakEnd = feed < 0 ? text.length : feed + 1;
    final int end = feed < 0
        ? text.length
        : feed > start && text.codeUnitAt(feed - 1) == _carriageReturn
        ? feed - 1
        : feed;
    if (MdPhotoLine.match(text, start, end) != null) {
      lines.add(_Line(start, end, breakEnd));
    }
    if (feed < 0) {
      return lines;
    }
    start = breakEnd;
  }
}

String _withoutLines(String text, List<_Line> lines) {
  final StringBuffer buffer = StringBuffer();
  int kept = 0;
  for (final _Line line in lines) {
    final bool isLast = line.breakEnd == line.end;
    final int from = isLast
        ? _precedingBreakStart(text, line.start)
        : line.start;
    if (from > kept) {
      buffer.write(text.substring(kept, from));
    }
    if (line.breakEnd > kept) {
      kept = line.breakEnd;
    }
  }
  buffer.write(text.substring(kept));
  return buffer.toString();
}

int _precedingBreakStart(String text, int lineStart) {
  if (lineStart == 0) {
    return 0;
  }
  final int feed = lineStart - 1;
  return feed > 0 && text.codeUnitAt(feed - 1) == _carriageReturn
      ? feed - 1
      : feed;
}

bool _photoLinesLand(
  EditorState state,
  int start,
  int end,
  String text,
  MdTree bare,
  List<_Line> candidates,
) {
  final String source = state.source;
  final MdTree plain = state.parse(source.replaceRange(start, end, text));
  for (final _Line line in candidates) {
    final int at = start + line.start;
    final MdBlock? block = plain.blockAt(at);
    if (block == null ||
        block.kind != MdBlockKind.photoLine ||
        block.sourceRange.start != at) {
      return false;
    }
  }
  return _textBlockCount(plain) == _textBlockCount(bare);
}

int _textBlockCount(MdTree tree) => tree.blocks
    .where((MdBlock block) => block.kind != MdBlockKind.photoLine)
    .length;

String _trimmed(String text, _Line line) {
  int from = line.start;
  int to = line.end;
  while (from < to && _isSpaceOrTab(text.codeUnitAt(from))) {
    from += 1;
  }
  while (to > from && _isSpaceOrTab(text.codeUnitAt(to - 1))) {
    to -= 1;
  }
  return text.substring(from, to);
}

bool _isSpaceOrTab(int unit) => unit == _space || unit == _tab;
