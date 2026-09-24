import 'package:flutter/widgets.dart';

import 'package:field_notes/features/note_engine/editor/note_editor_view.dart';

bool isTextInputFocused() {
  final BuildContext? context = FocusManager.instance.primaryFocus?.context;
  if (context == null) {
    return false;
  }
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null ||
      context.findAncestorStateOfType<EditableTextState>() != null ||
      context.findAncestorWidgetOfExactType<NoteEditorView>() != null;
}
