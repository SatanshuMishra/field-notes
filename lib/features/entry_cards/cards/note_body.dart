import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';
import '../notes/note_document.dart';

class NoteBody extends StatelessWidget {
  const NoteBody({super.key, required this.text});

  final String text;

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
    return NoteDocument(source: text);
  }
}
