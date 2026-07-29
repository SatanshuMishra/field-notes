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
    this.changeLabel = 'change',
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
      surface: Palette.cardWarm,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      child: Row(
        children: <Widget>[
          FlowerBloom.forMood(current, size: 54),
          const SizedBox(width: _moodBannerGap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Feeling ${current.label} today',
                  style: TypographyTokens.bannerSerif,
                ),
                Text(
                  '${current.flower.label} · your bloom for the day',
                  style: TypographyTokens.captionSans,
                ),
              ],
            ),
          ),
          const SizedBox(width: _moodBannerGap),
          _MoodChangePill(label: changeLabel, onTap: onChangeMood),
        ],
      ),
    );
  }
}

const double _moodBannerGap = 15;

const BoxDecoration _changePillDecoration = BoxDecoration(
  border: Border.fromBorderSide(
    BorderSide(color: Palette.coral, width: Shapes.outlineWidth),
  ),
  borderRadius: BorderRadius.all(Radius.circular(Shapes.radiusPill)),
);

const EdgeInsets _changePillPadding =
    EdgeInsets.symmetric(vertical: 6, horizontal: 13);

class _MoodChangePill extends StatelessWidget {
  const _MoodChangePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onTap != null;
    return Semantics(
      button: isEnabled,
      enabled: isEnabled,
      label: label,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: _changePillDecoration,
            child: Padding(
              padding: _changePillPadding,
              child: Text(label, style: TypographyTokens.caption11Sans),
            ),
          ),
        ),
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
