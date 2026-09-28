import 'package:field_notes/features/note_engine/input/cut_buffer.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

EditableTextState? focusedEditableText() {
  final FocusNode? focus = FocusManager.instance.primaryFocus;
  final BuildContext? context = focus?.context;
  if (context == null || !context.mounted) {
    return null;
  }
  final EditableTextState? field = context
      .findAncestorStateOfType<EditableTextState>();
  return field != null && identical(field.widget.focusNode, focus)
      ? field
      : null;
}

enum _FieldEdit { cutToLineEnd, yank, insertLineBreak }

final class _FieldEditIntent extends Intent {
  const _FieldEditIntent(this.edit);

  final _FieldEdit edit;
}

final class _FieldMoveIntent extends Intent {
  const _FieldMoveIntent(this.intent);

  final Intent intent;
}

const Map<ShortcutActivator, Intent> _shortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.keyK, control: true): _FieldEditIntent(
    _FieldEdit.cutToLineEnd,
  ),
  SingleActivator(LogicalKeyboardKey.keyY, control: true): _FieldEditIntent(
    _FieldEdit.yank,
  ),
  SingleActivator(LogicalKeyboardKey.keyO, control: true): _FieldEditIntent(
    _FieldEdit.insertLineBreak,
  ),
  SingleActivator(LogicalKeyboardKey.keyV, control: true): _FieldMoveIntent(
    ExtendSelectionVerticallyToAdjacentPageIntent(
      forward: true,
      collapseSelection: true,
    ),
  ),
  SingleActivator(
    LogicalKeyboardKey.keyA,
    control: true,
    shift: true,
  ): _FieldMoveIntent(
    ExtendSelectionToLineBreakIntent(forward: false, collapseSelection: false),
  ),
  SingleActivator(
    LogicalKeyboardKey.keyE,
    control: true,
    shift: true,
  ): _FieldMoveIntent(
    ExtendSelectionToLineBreakIntent(forward: true, collapseSelection: false),
  ),
  SingleActivator(
    LogicalKeyboardKey.keyF,
    control: true,
    shift: true,
  ): _FieldMoveIntent(
    ExtendSelectionByCharacterIntent(forward: true, collapseSelection: false),
  ),
  SingleActivator(
    LogicalKeyboardKey.keyB,
    control: true,
    shift: true,
  ): _FieldMoveIntent(
    ExtendSelectionByCharacterIntent(forward: false, collapseSelection: false),
  ),
  SingleActivator(
    LogicalKeyboardKey.keyF,
    control: true,
    alt: true,
  ): _FieldMoveIntent(
    ExtendSelectionToNextWordBoundaryIntent(
      forward: true,
      collapseSelection: true,
    ),
  ),
  SingleActivator(
    LogicalKeyboardKey.keyB,
    control: true,
    alt: true,
  ): _FieldMoveIntent(
    ExtendSelectionToNextWordBoundaryIntent(
      forward: false,
      collapseSelection: true,
    ),
  ),
};

EditableTextState? _idleField() {
  final EditableTextState? field = focusedEditableText();
  if (field == null) {
    return null;
  }
  final TextRange composing = field.textEditingValue.composing;
  return composing.isValid && !composing.isCollapsed ? null : field;
}

final class _FieldEditAction extends Action<_FieldEditIntent> {
  @override
  bool isEnabled(_FieldEditIntent intent) {
    final EditableTextState? field = _idleField();
    return field != null &&
        !field.widget.readOnly &&
        field.textEditingValue.selection.isValid;
  }

  @override
  Object? invoke(_FieldEditIntent intent) {
    final EditableTextState? field = _idleField();
    if (field == null) {
      return null;
    }
    final TextEditingValue value = field.textEditingValue;
    final TextSelection selection = value.selection;
    final TextRange selected = TextRange(
      start: selection.start,
      end: selection.end,
    );
    final TextEditingValue? next = switch (intent.edit) {
      _FieldEdit.cutToLineEnd => _cutToLineEnd(value, selected),
      _FieldEdit.yank => _insert(value, selected, CutBuffer.instance.text),
      _FieldEdit.insertLineBreak =>
        field.widget.maxLines == 1
            ? null
            : value
                  .replaced(selected, '\n')
                  .copyWith(
                    selection: TextSelection.collapsed(offset: selected.start),
                  ),
    };
    if (next != null) {
      field.userUpdateTextEditingValue(next, SelectionChangedCause.keyboard);
    }
    return null;
  }

  static TextEditingValue? _cutToLineEnd(
    TextEditingValue value,
    TextRange selected,
  ) {
    final TextRange range = selected.isCollapsed
        ? cutRangeToLineEnd(value.text, selected.start)
        : selected;
    if (range.isCollapsed) {
      return null;
    }
    CutBuffer.instance.store(range.textInside(value.text));
    return value
        .replaced(range, '')
        .copyWith(selection: TextSelection.collapsed(offset: range.start));
  }

  static TextEditingValue? _insert(
    TextEditingValue value,
    TextRange selected,
    String text,
  ) => text.isEmpty
      ? null
      : value
            .replaced(selected, text)
            .copyWith(
              selection: TextSelection.collapsed(
                offset: selected.start + text.length,
              ),
            );
}

final class _FieldMoveAction extends Action<_FieldMoveIntent> {
  @override
  bool isEnabled(_FieldMoveIntent intent) => _idleField() != null;

  @override
  Object? invoke(_FieldMoveIntent intent) {
    final BuildContext? context = FocusManager.instance.primaryFocus?.context;
    if (context != null && _idleField() != null) {
      Actions.maybeInvoke<Intent>(context, intent.intent);
    }
    return null;
  }
}

class MacosTextShortcuts extends StatefulWidget {
  const MacosTextShortcuts({super.key, required this.child});

  final Widget child;

  @override
  State<MacosTextShortcuts> createState() => _MacosTextShortcutsState();
}

class _MacosTextShortcutsState extends State<MacosTextShortcuts> {
  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    _FieldEditIntent: _FieldEditAction(),
    _FieldMoveIntent: _FieldMoveAction(),
  };

  @override
  Widget build(BuildContext context) => Shortcuts(
    debugLabel: '<macOS Text Keys>',
    shortcuts: _shortcuts,
    child: Actions(actions: _actions, child: widget.child),
  );
}
