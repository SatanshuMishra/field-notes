import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';

class NoteBody extends StatelessWidget {
  const NoteBody({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return Text(
        'Empty note',
        style: TypographyTokens.bodySerifItalic.copyWith(color: Palette.muted),
      );
    }
    return Text(text, style: TypographyTokens.bodySerif);
  }
}
