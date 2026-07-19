import 'package:flutter/widgets.dart';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/mood/mood.dart';

import 'mood_prompt_border.dart';

class MoodBanner extends StatelessWidget {
  const MoodBanner({
    super.key,
    required this.mood,
    required this.onChangeMood,
    this.promptText = 'How are you feeling today?',
    this.changeLabel = 'Change mood',
  });

  final Mood? mood;
  final VoidCallback? onChangeMood;
  final String promptText;
  final String changeLabel;

  @override
  Widget build(BuildContext context) {
    final Mood? current = mood;
    if (current == null) {
      return _MoodPrompt(text: promptText, onTap: onChangeMood);
    }
    return StickerCard(
      surface: Palette.cardLight,
      child: Row(
        children: <Widget>[
          FlowerBloom.forMood(current, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Text(current.label, style: TypographyTokens.titleSerif),
          ),
          const SizedBox(width: 12),
          StickerButton(
            label: changeLabel,
            variant: StickerButtonVariant.secondary,
            onPressed: onChangeMood,
          ),
        ],
      ),
    );
  }
}

class _MoodPrompt extends StatelessWidget {
  const _MoodPrompt({required this.text, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CustomPaint(
          painter: const MoodPromptBorderPainter(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TypographyTokens.dateSerif,
            ),
          ),
        ),
      ),
    );
  }
}
