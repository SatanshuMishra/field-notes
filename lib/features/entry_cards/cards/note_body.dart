import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';

class NoteBody extends StatelessWidget {
  const NoteBody({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return NoteColumn(child: _text());
  }

  Widget _text() {
    if (text.trim().isEmpty) {
      return Text(
        'Empty note',
        style: TypographyTokens.noteBodyItalic.copyWith(color: Palette.muted),
      );
    }
    return Text(
      text,
      style: TypographyTokens.noteBody,
      softWrap: true,
      overflow: TextOverflow.clip,
    );
  }
}
