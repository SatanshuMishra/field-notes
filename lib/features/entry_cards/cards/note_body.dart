import 'package:flutter/widgets.dart';

import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteReaderView;

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';

class NoteBody extends StatelessWidget {
  const NoteBody({
    super.key,
    required this.text,
    this.selectable = true,
    this.onToggleTask,
  });

  final String text;
  final bool selectable;
  final ValueChanged<int>? onToggleTask;

  @override
  Widget build(BuildContext context) {
    return NoteColumn(child: _body());
  }

  Widget _body() {
    if (text.trim().isEmpty) {
      return Text(
        'Empty note',
        style: TypographyTokens.noteBodyItalic.copyWith(color: Palette.muted),
      );
    }
    return NoteReaderView(
      source: text,
      selectable: selectable,
      onToggleTask: onToggleTask,
    );
  }
}
