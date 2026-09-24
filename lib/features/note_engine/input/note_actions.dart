import 'dart:ui' show PointerDeviceKind;

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/input/command_registry.dart';
import 'package:field_notes/features/note_engine/input/delta_mapping.dart';
import 'package:field_notes/features/note_engine/input/note_shortcuts.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/vertical_motion.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/widgets.dart';

const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;

final RegExp _wordCharacter = RegExp(r'[\p{L}\p{N}\p{M}_]', unicode: true);

abstract interface class NoteActionHost {
  EditorState get state;

  VisibleText get visible;

  NoteLayout get layout;

  CommandRegistry get commands;

  double get viewportHeight;

  bool get canDismiss;

  void apply(Transaction transaction);

  void select(NoteSelection selection, SelectionChangedCause cause);

  void scrollBy(double pixels);

  void scrollToEdge({required bool end});

  void copy({required bool cut});

  Future<void> paste();

  void undo();

  void redo();

  void dismiss();

  bool focusPhotoToolbar();
}

void invokeMacOSSelector(BuildContext context, String selectorName) {
  final Intent? intent = intentForMacOSSelector(selectorName);
  if (intent == null) {
    assert(() {
      debugPrint('NoteActions: ignored unmapped selector $selectorName');
      return true;
    }());
    return;
  }
  Actions.maybeInvoke<Intent>(context, intent);
}

typedef _Boundary = TextPosition Function(TextPosition extent, bool forward);

class NoteActions {
  NoteActions({required this.host});

  final NoteActionHost host;
  VerticalGoal? _goal;
  NoteSelection? _produced;

  late final Map<Type, Action<Intent>> actions = <Type, Action<Intent>>{
    DoNothingAndStopPropagationTextIntent: DoNothingAction(consumesKey: false),
    DeleteCharacterIntent: _textAction<DeleteCharacterIntent>(_deleteCharacter),
    DeleteToNextWordBoundaryIntent: _textAction<DeleteToNextWordBoundaryIntent>(
      (DeleteToNextWordBoundaryIntent intent) =>
          _deleteTo(intent.forward, _wordBeyond),
    ),
    DeleteToLineBreakIntent: _textAction<DeleteToLineBreakIntent>(
      (DeleteToLineBreakIntent intent) => _deleteTo(intent.forward, _lineTo),
    ),
    ExtendSelectionByCharacterIntent:
        _textAction<ExtendSelectionByCharacterIntent>(_moveByCharacter),
    ExtendSelectionToNextWordBoundaryIntent:
        _textAction<ExtendSelectionToNextWordBoundaryIntent>(
          (ExtendSelectionToNextWordBoundaryIntent intent) =>
              _updateSelection(intent, _wordBeyond),
        ),
    ExtendSelectionToNextWordBoundaryOrCaretLocationIntent:
        _textAction<ExtendSelectionToNextWordBoundaryOrCaretLocationIntent>(
          (ExtendSelectionToNextWordBoundaryOrCaretLocationIntent intent) =>
              _updateSelection(intent, _wordBeyond),
        ),
    ExtendSelectionToNextParagraphBoundaryIntent:
        _textAction<ExtendSelectionToNextParagraphBoundaryIntent>(
          (ExtendSelectionToNextParagraphBoundaryIntent intent) =>
              _updateSelection(intent, _paragraphBeyond),
        ),
    ExtendSelectionToNextParagraphBoundaryOrCaretLocationIntent:
        _textAction<
          ExtendSelectionToNextParagraphBoundaryOrCaretLocationIntent
        >(
          (
            ExtendSelectionToNextParagraphBoundaryOrCaretLocationIntent intent,
          ) => _updateSelection(intent, _paragraphBeyond),
        ),
    ExtendSelectionToLineBreakIntent:
        _textAction<ExtendSelectionToLineBreakIntent>(
          (ExtendSelectionToLineBreakIntent intent) =>
              _updateSelection(intent, _lineTo),
        ),
    ExtendSelectionToDocumentBoundaryIntent:
        _textAction<ExtendSelectionToDocumentBoundaryIntent>(
          (ExtendSelectionToDocumentBoundaryIntent intent) =>
              _updateSelection(intent, _documentTo),
        ),
    ExpandSelectionToLineBreakIntent:
        _textAction<ExpandSelectionToLineBreakIntent>(
          (ExpandSelectionToLineBreakIntent intent) =>
              _updateSelection(intent, _lineTo, isExpand: true),
        ),
    ExpandSelectionToDocumentBoundaryIntent:
        _textAction<ExpandSelectionToDocumentBoundaryIntent>(
          (ExpandSelectionToDocumentBoundaryIntent intent) => _updateSelection(
            intent,
            _documentTo,
            isExpand: true,
            extentAtIndex: true,
          ),
        ),
    ExtendSelectionVerticallyToAdjacentLineIntent:
        _textAction<ExtendSelectionVerticallyToAdjacentLineIntent>(
          _moveVertically,
        ),
    ExtendSelectionVerticallyToAdjacentPageIntent:
        _textAction<ExtendSelectionVerticallyToAdjacentPageIntent>(_movePage),
    ScrollIntent: _textAction<ScrollIntent>(_scroll),
    ScrollToDocumentBoundaryIntent: _textAction<ScrollToDocumentBoundaryIntent>(
      (ScrollToDocumentBoundaryIntent intent) =>
          host.scrollToEdge(end: intent.forward),
    ),
    TransposeCharactersIntent: _textAction<TransposeCharactersIntent>(
      (TransposeCharactersIntent _) => _transpose(),
    ),
    SelectAllTextIntent: _textAction<SelectAllTextIntent>(
      (SelectAllTextIntent intent) => host.select(
        NoteSelection(anchor: 0, head: host.state.source.length),
        intent.cause,
      ),
    ),
    CopySelectionTextIntent: _textAction<CopySelectionTextIntent>(
      (CopySelectionTextIntent intent) =>
          host.copy(cut: intent.collapseSelection),
    ),
    PasteTextIntent: _textAction<PasteTextIntent>(
      (PasteTextIntent _) => host.paste(),
    ),
    UndoTextIntent: _textAction<UndoTextIntent>(
      (UndoTextIntent _) => host.undo(),
    ),
    RedoTextIntent: _textAction<RedoTextIntent>(
      (RedoTextIntent _) => host.redo(),
    ),
    UpdateSelectionIntent: _textAction<UpdateSelectionIntent>(
      _updateFromVisible,
    ),
    ReplaceTextIntent: _textAction<ReplaceTextIntent>(_replaceText),
    DismissIntent: _NoteAction<DismissIntent>(
      onInvoke: (DismissIntent _) {
        if (host.canDismiss) {
          host.dismiss();
        }
        return null;
      },
    ),
    EditableTextTapOutsideIntent: _NoteAction<EditableTextTapOutsideIntent>(
      onInvoke: _tapOutside,
    ),
    EditableTextTapUpOutsideIntent: _NoteAction<EditableTextTapUpOutsideIntent>(
      onInvoke: (EditableTextTapUpOutsideIntent _) => null,
    ),
    DirectionalFocusIntent: DirectionalFocusAction.forTextField(),
    NextFocusIntent: _NoteAction<NextFocusIntent>(
      onInvoke: (NextFocusIntent _) => _focusStep(forward: true),
    ),
    PreviousFocusIntent: _NoteAction<PreviousFocusIntent>(
      onInvoke: (PreviousFocusIntent _) => _focusStep(forward: false),
    ),
    NoteCommandIntent: _NoteAction<NoteCommandIntent>(
      enabled: (NoteCommandIntent intent) =>
          host.state.composing == null &&
          host.commands.commandFor(intent.commandId) != null,
      onInvoke: (NoteCommandIntent intent) {
        final Transaction? transaction = host.commands
            .commandFor(intent.commandId)
            ?.call(host.state);
        if (transaction != null) {
          host.apply(transaction);
        }
        return null;
      },
    ),
    NoteEscapeIntent: _NoteAction<NoteEscapeIntent>(
      enabled: (NoteEscapeIntent _) =>
          host.state.composing != null || host.canDismiss,
      consumes: (NoteEscapeIntent _) => host.state.composing == null,
      onInvoke: (NoteEscapeIntent _) {
        if (host.state.composing == null) {
          host.dismiss();
        }
        return null;
      },
    ),
  };

  void resetVerticalRun() {
    _goal = null;
    _produced = null;
  }

  Action<T> _textAction<T extends Intent>(void Function(T intent) invoke) =>
      _NoteAction<T>(
        enabled: (T _) => _hasValidSelection,
        onInvoke: (T intent) {
          invoke(intent);
          return null;
        },
      );

  bool get _hasValidSelection {
    final EditorState state = host.state;
    return state.selection.end <= state.source.length;
  }

  int _toVisible(int sourceOffset) =>
      host.visible.map.sourceToVisible(sourceOffset);

  int _toSource(int visibleOffset, TextAffinity affinity) =>
      sourcePositionForVisible(
        state: host.state,
        visible: host.visible,
        visibleOffset: visibleOffset,
        affinity: affinity,
      );

  int _graphemeStep(int visibleOffset, {required bool forward}) {
    final VisibleText visible = host.visible;
    final String text = visible.text;
    final int stepped = forward
        ? _graphemeAfter(text, visibleOffset)
        : _graphemeBefore(text, visibleOffset);
    final AtomicObject? atomic = visible.atomicAtVisible(stepped);
    if (atomic == null || atomic.visibleOffset == stepped) {
      return stepped;
    }
    return forward
        ? atomic.visibleOffset + atomic.visibleLength
        : atomic.visibleOffset;
  }

  void _deleteCharacter(DeleteCharacterIntent intent) {
    final EditorState state = host.state;
    final Transaction? command = host.commands
        .commandFor(
          intent.forward
              ? NoteCommandId.deleteForward
              : NoteCommandId.deleteBackward,
        )
        ?.call(state);
    if (command != null) {
      host.apply(command);
      return;
    }
    final NoteSelection selection = state.selection;
    if (!selection.isCollapsed) {
      _deleteSource(MdRange(selection.start, selection.end));
      return;
    }
    final int caret = _toVisible(selection.head);
    final int target = _graphemeStep(caret, forward: intent.forward);
    if (target == caret) {
      return;
    }
    final int low = target < caret ? target : caret;
    final int high = target < caret ? caret : target;
    final VisibleText visible = host.visible;
    final AtomicObject? atomic = visible.atomicAtVisible(low);
    if (atomic != null &&
        atomic.kind == AtomicKind.tableSeparator &&
        atomic.visibleOffset == low &&
        atomic.visibleOffset + atomic.visibleLength == high) {
      return;
    }
    _deleteSource(
      sourceRangeForVisible(
        state: state,
        visible: visible,
        visibleRange: TextRange(start: low, end: high),
      ),
    );
  }

  void _deleteTo(bool forward, _Boundary boundary) {
    final NoteSelection selection = host.state.selection;
    if (!selection.isCollapsed) {
      _deleteSource(MdRange(selection.start, selection.end));
      return;
    }
    final int caret = selection.head;
    final int target = boundary(
      TextPosition(offset: caret, affinity: selection.affinity),
      forward,
    ).offset;
    if (target == caret) {
      return;
    }
    _deleteSource(
      target < caret ? MdRange(target, caret) : MdRange(caret, target),
    );
  }

  void _deleteSource(MdRange range) {
    if (range.isEmpty) {
      return;
    }
    final EditorState state = host.state;
    host.apply(
      Transaction(
        changes: ChangeSet.single(
          state.source.length,
          range.start,
          range.end,
          '',
        ),
        selection: NoteSelection.collapsed(range.start),
        event: TransactionEvent.inputDelete,
      ),
    );
  }

  void _moveByCharacter(ExtendSelectionByCharacterIntent intent) {
    final EditorState state = host.state;
    final NoteSelection selection = state.selection;
    final bool forward = intent.forward;
    final MdRange? photo = selectedPhotoLine(state);
    if (photo != null && intent.collapseSelection) {
      final int crossed = forward
          ? _nextLineStart(state.source, photo.end)
          : _previousLineEnd(state.source, photo.start);
      if (crossed != (forward ? photo.end : photo.start)) {
        _select(NoteSelection.collapsed(crossed));
        return;
      }
    }
    if (intent.collapseSelection && !selection.isCollapsed) {
      _select(
        NoteSelection.collapsed(forward ? selection.end : selection.start),
      );
      return;
    }
    final int target = _graphemeStep(
      _toVisible(selection.head),
      forward: forward,
    );
    final AtomicObject? landed = _photoAtVisible(target);
    if (intent.collapseSelection && landed != null) {
      _select(
        NoteSelection(
          anchor: landed.sourceRange.start,
          head: landed.sourceRange.end,
        ),
      );
      return;
    }
    final int head = _toSource(
      target,
      forward ? TextAffinity.upstream : TextAffinity.downstream,
    );
    _select(
      intent.collapseSelection
          ? NoteSelection.collapsed(head)
          : NoteSelection(anchor: selection.anchor, head: head),
    );
  }

  AtomicObject? _photoAtVisible(int visibleOffset) {
    for (final AtomicObject atomic in host.visible.atomics) {
      if (atomic.kind == AtomicKind.photo &&
          atomic.visibleOffset <= visibleOffset &&
          visibleOffset <= atomic.visibleOffset + atomic.visibleLength) {
        return atomic;
      }
    }
    return null;
  }

  void _select(NoteSelection selection) {
    host.select(selection, SelectionChangedCause.keyboard);
  }

  void _updateSelection(
    DirectionalCaretMovementIntent intent,
    _Boundary boundary, {
    bool isExpand = false,
    bool extentAtIndex = false,
  }) {
    final EditorState state = host.state;
    final NoteSelection current = state.selection;
    final TextSelection selection = TextSelection(
      baseOffset: current.anchor,
      extentOffset: current.head,
      affinity: current.affinity,
    );
    final bool forward = intent.forward;
    final bool collapse = intent.collapseSelection;
    TextPosition extent = selection.extent;
    if (intent.continuesAtWrap) {
      if (forward && _isAtWrapUpstream(extent)) {
        extent = TextPosition(offset: extent.offset);
      } else if (!forward && _isAtWrapDownstream(extent)) {
        extent = TextPosition(
          offset: extent.offset,
          affinity: TextAffinity.upstream,
        );
      }
    }
    final bool targetsBase =
        isExpand &&
        (forward
            ? selection.baseOffset > selection.extentOffset
            : selection.baseOffset < selection.extentOffset);
    final TextPosition newExtent = boundary(
      targetsBase ? selection.base : extent,
      forward,
    );
    final TextSelection next =
        collapse || (!isExpand && newExtent.offset == selection.baseOffset)
        ? TextSelection.fromPosition(newExtent)
        : isExpand
        ? selection.expandTo(newExtent, extentAtIndex || selection.isCollapsed)
        : selection.extendTo(newExtent);
    final bool collapsesToBase =
        intent.collapseAtReversal &&
        (selection.baseOffset - selection.extentOffset) *
                (selection.baseOffset - next.extentOffset) <
            0;
    final TextSelection chosen = collapsesToBase
        ? TextSelection.fromPosition(selection.base)
        : next;
    _select(
      NoteSelection(
        anchor: chosen.baseOffset,
        head: chosen.extentOffset,
        affinity: chosen.affinity,
      ),
    );
  }

  bool _isAtWrapUpstream(TextPosition position) {
    final String source = host.state.source;
    if (position.affinity != TextAffinity.upstream ||
        position.offset >= source.length ||
        source.codeUnitAt(position.offset) == _lineFeed) {
      return false;
    }
    return host.layout
            .lineBoundary(position.offset, TextAffinity.upstream)
            .end ==
        position.offset;
  }

  bool _isAtWrapDownstream(TextPosition position) {
    final String source = host.state.source;
    if (position.affinity != TextAffinity.downstream ||
        position.offset == 0 ||
        source.codeUnitAt(position.offset - 1) == _lineFeed) {
      return false;
    }
    return host.layout
            .lineBoundary(position.offset, TextAffinity.downstream)
            .start ==
        position.offset;
  }

  TextPosition _wordBeyond(TextPosition extent, bool forward) {
    final EditorState state = host.state;
    final VisibleText visible = host.visible;
    final String text = visible.text;
    int at = _toVisible(extent.offset);
    if (forward) {
      while (at < text.length && !_startsWord(text, at)) {
        at = _graphemeAfter(text, at);
      }
      if (at >= text.length) {
        return TextPosition(offset: state.source.length);
      }
      final int start = _toSource(at, TextAffinity.downstream);
      final MdRange word = host.layout.wordBoundary(start);
      return TextPosition(
        offset: word.end > start
            ? word.end
            : _toSource(_graphemeAfter(text, at), TextAffinity.upstream),
      );
    }
    while (at > 0 && !_startsWord(text, _graphemeBefore(text, at))) {
      at = _graphemeBefore(text, at);
    }
    if (at <= 0) {
      return const TextPosition(offset: 0);
    }
    final int inside = _toSource(
      _graphemeBefore(text, at),
      TextAffinity.downstream,
    );
    final MdRange word = host.layout.wordBoundary(inside);
    final int end = _toSource(at, TextAffinity.upstream);
    return TextPosition(offset: word.start < end ? word.start : inside);
  }

  TextPosition _paragraphBeyond(TextPosition extent, bool forward) {
    final String source = host.state.source;
    final int offset = extent.offset;
    final MdRange paragraph = host.layout.paragraphBoundary(offset);
    if (forward) {
      if (paragraph.end > offset) {
        return TextPosition(offset: paragraph.end);
      }
      final int next = _nextLineStart(source, offset);
      return TextPosition(
        offset: next == offset
            ? source.length
            : host.layout.paragraphBoundary(next).end,
      );
    }
    if (paragraph.start < offset) {
      return TextPosition(offset: paragraph.start);
    }
    final int previous = _previousLineEnd(source, offset);
    return TextPosition(
      offset: previous == offset
          ? 0
          : host.layout.paragraphBoundary(previous).start,
    );
  }

  TextPosition _lineTo(TextPosition extent, bool forward) {
    final MdRange line = host.layout.lineBoundary(
      extent.offset,
      extent.affinity,
    );
    return forward
        ? TextPosition(offset: line.end, affinity: TextAffinity.upstream)
        : TextPosition(offset: line.start);
  }

  TextPosition _documentTo(TextPosition extent, bool forward) {
    final MdRange document = host.layout.documentBoundary;
    return forward
        ? TextPosition(offset: document.end, affinity: TextAffinity.upstream)
        : TextPosition(offset: document.start);
  }

  void _moveVertically(ExtendSelectionVerticallyToAdjacentLineIntent intent) {
    final NoteSelection selection = host.state.selection;
    final NoteLayout layout = host.layout;
    final VerticalGoal? kept = _produced == selection ? _goal : null;
    final VerticalStep step = moveVertically(
      inputs: layout.inputs,
      caret: kept?.position ?? selection.head,
      affinity: selection.affinity,
      direction: intent.forward ? VerticalMove.down : VerticalMove.up,
      goal: kept,
      caretX: (int position, TextAffinity affinity) =>
          layout.caretRect(position, affinity).left,
      target:
          (
            int position,
            TextAffinity affinity,
            double goalX,
            VerticalMove direction,
          ) => layout.verticalTarget(position, affinity, goalX, direction),
    );
    _finishRun(step.goal, step.position, selection, intent.collapseSelection);
  }

  void _movePage(ExtendSelectionVerticallyToAdjacentPageIntent intent) {
    final EditorState state = host.state;
    final NoteSelection selection = state.selection;
    final NoteLayout layout = host.layout;
    final VerticalGoal? kept = _produced == selection ? _goal : null;
    final int caret = kept?.position ?? selection.head;
    final Rect caretRect = layout.caretRect(caret, selection.affinity);
    final double x = kept != null && kept.holdsFor(layout.inputs, caret)
        ? kept.x
        : caretRect.left;
    final double y =
        caretRect.center.dy +
        (intent.forward ? host.viewportHeight : -host.viewportHeight);
    final int length = state.source.length;
    final TextPosition position =
        y < layout.caretRect(0, TextAffinity.downstream).top
        ? const TextPosition(offset: 0)
        : y > layout.caretRect(length, TextAffinity.downstream).bottom
        ? TextPosition(offset: length)
        : layout.positionAt(Offset(x, y));
    _finishRun(
      VerticalGoal.start(layout.inputs, x: x, position: position.offset),
      position,
      selection,
      intent.collapseSelection,
    );
  }

  void _finishRun(
    VerticalGoal goal,
    TextPosition position,
    NoteSelection selection,
    bool collapse,
  ) {
    final NoteSelection next = collapse
        ? NoteSelection.collapsed(position.offset, affinity: position.affinity)
        : NoteSelection(
            anchor: selection.anchor,
            head: position.offset,
            affinity: position.affinity,
          );
    _goal = goal;
    _produced = next;
    _select(next);
  }

  void _scroll(ScrollIntent intent) {
    if (intent.type != ScrollIncrementType.page) {
      return;
    }
    switch (intent.direction) {
      case AxisDirection.up:
        host.scrollBy(-host.viewportHeight);
      case AxisDirection.down:
        host.scrollBy(host.viewportHeight);
      case AxisDirection.left:
      case AxisDirection.right:
        break;
    }
  }

  void _transpose() {
    final EditorState state = host.state;
    final NoteSelection selection = state.selection;
    final VisibleText visible = host.visible;
    final String text = visible.text;
    final int caret = _toVisible(selection.head);
    if (!selection.isCollapsed || caret == 0 || text.characters.length <= 1) {
      return;
    }
    final CharacterRange transposing = CharacterRange.at(text, caret);
    if (caret == text.length) {
      transposing.moveBack(2);
    } else {
      transposing
        ..moveBack()
        ..expandNext();
    }
    if (transposing.currentCharacters.length != 2) {
      return;
    }
    final int start = transposing.stringBeforeLength;
    final int end = start + transposing.current.length;
    final MdRange range = sourceRangeForVisible(
      state: state,
      visible: visible,
      visibleRange: TextRange(start: start, end: end),
    );
    if (range.sliceOf(state.source) != transposing.current) {
      return;
    }
    final String swapped =
        transposing.currentCharacters.last +
        transposing.currentCharacters.first;
    host.apply(
      Transaction(
        changes: ChangeSet.single(
          state.source.length,
          range.start,
          range.end,
          swapped,
        ),
        selection: NoteSelection.collapsed(range.start + swapped.length),
        event: TransactionEvent.inputType,
      ),
    );
  }

  void _updateFromVisible(UpdateSelectionIntent intent) {
    final TextSelection visibleSelection = intent.newSelection;
    if (!visibleSelection.isValid) {
      return;
    }
    if (visibleSelection.isCollapsed) {
      host.select(
        NoteSelection.collapsed(
          _toSource(visibleSelection.baseOffset, visibleSelection.affinity),
          affinity: visibleSelection.affinity,
        ),
        intent.cause,
      );
      return;
    }
    final MdRange range = sourceRangeForVisible(
      state: host.state,
      visible: host.visible,
      visibleRange: TextRange(
        start: visibleSelection.start,
        end: visibleSelection.end,
      ),
    );
    final bool reversed =
        visibleSelection.baseOffset > visibleSelection.extentOffset;
    host.select(
      NoteSelection(
        anchor: reversed ? range.end : range.start,
        head: reversed ? range.start : range.end,
        affinity: visibleSelection.affinity,
      ),
      intent.cause,
    );
  }

  void _replaceText(ReplaceTextIntent intent) {
    final EditorState state = host.state;
    final MdRange range = sourceRangeForVisible(
      state: state,
      visible: host.visible,
      visibleRange: intent.replacementRange,
    );
    host.apply(
      Transaction(
        changes: ChangeSet.single(
          state.source.length,
          range.start,
          range.end,
          intent.replacementText,
        ),
        selection: NoteSelection.collapsed(
          range.start + intent.replacementText.length,
        ),
        event: TransactionEvent.inputType,
      ),
    );
  }

  Object? _tapOutside(EditableTextTapOutsideIntent intent) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        switch (intent.pointerDownEvent.kind) {
          case PointerDeviceKind.touch:
          case PointerDeviceKind.trackpad:
            break;
          case PointerDeviceKind.mouse:
          case PointerDeviceKind.stylus:
          case PointerDeviceKind.invertedStylus:
          case PointerDeviceKind.unknown:
            intent.focusNode.unfocus();
        }
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        intent.focusNode.unfocus();
    }
    return null;
  }

  Object? _focusStep({required bool forward}) {
    final EditorState state = host.state;
    final Transaction? command = host.commands
        .commandFor(forward ? NoteCommandId.indent : NoteCommandId.outdent)
        ?.call(state);
    if (command != null) {
      host.apply(command);
      return true;
    }
    if (forward &&
        selectedPhotoLine(state) != null &&
        host.focusPhotoToolbar()) {
      return true;
    }
    final FocusNode? focused = primaryFocus;
    return forward
        ? focused?.nextFocus() ?? false
        : focused?.previousFocus() ?? false;
  }
}

final class _NoteAction<T extends Intent> extends Action<T> {
  _NoteAction({required this.onInvoke, this.enabled, this.consumes});

  final Object? Function(T intent) onInvoke;
  final bool Function(T intent)? enabled;
  final bool Function(T intent)? consumes;

  @override
  bool isEnabled(T intent) => enabled?.call(intent) ?? true;

  @override
  bool consumesKey(T intent) => consumes?.call(intent) ?? true;

  @override
  Object? invoke(T intent) => onInvoke(intent);
}

bool _startsWord(String text, int offset) {
  if (offset >= text.length) {
    return false;
  }
  final CharacterRange range = CharacterRange.at(text, offset)..expandNext();
  return _wordCharacter.hasMatch(range.current);
}

int _graphemeAfter(String text, int offset) {
  if (offset >= text.length) {
    return text.length;
  }
  final CharacterRange range = CharacterRange.at(text, offset)..expandNext();
  return range.stringBeforeLength + range.current.length;
}

int _graphemeBefore(String text, int offset) {
  if (offset <= 0) {
    return 0;
  }
  final CharacterRange range = CharacterRange.at(text, offset)..expandBack();
  return range.stringBeforeLength;
}

int _nextLineStart(String source, int offset) {
  if (offset >= source.length) {
    return offset;
  }
  final int unit = source.codeUnitAt(offset);
  if (unit == _carriageReturn &&
      offset + 1 < source.length &&
      source.codeUnitAt(offset + 1) == _lineFeed) {
    return offset + 2;
  }
  return unit == _lineFeed ? offset + 1 : offset;
}

int _previousLineEnd(String source, int offset) {
  if (offset <= 0 || source.codeUnitAt(offset - 1) != _lineFeed) {
    return offset;
  }
  final int lineEnd = offset - 1;
  return lineEnd > 0 && source.codeUnitAt(lineEnd - 1) == _carriageReturn
      ? lineEnd - 1
      : lineEnd;
}

class NoteKeyboardScope extends StatefulWidget {
  const NoteKeyboardScope({super.key, required this.host, required this.child});

  final NoteActionHost host;
  final Widget child;

  @override
  State<NoteKeyboardScope> createState() => _NoteKeyboardScopeState();
}

class _NoteKeyboardScopeState extends State<NoteKeyboardScope> {
  late NoteActions _actions = NoteActions(host: widget.host);

  @override
  void didUpdateWidget(NoteKeyboardScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.host != widget.host) {
      _actions = NoteActions(host: widget.host);
    }
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: noteShortcuts(defaultTargetPlatform),
    child: Actions(actions: _actions.actions, child: widget.child),
  );
}
