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
    this.isToday = true,
  });

  final Mood? mood;
  final VoidCallback? onChangeMood;
  final String promptText;
  final String changeLabel;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final Mood? current = mood;
    if (current == null) {
      return _MoodPrompt(
        text: promptText,
        isToday: isToday,
        onTap: onChangeMood,
      );
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

const BoxDecoration _choosePillDecoration = BoxDecoration(
  color: Palette.coral,
  border: Border.fromBorderSide(
    BorderSide(color: Palette.ink, width: Shapes.outlineWidth),
  ),
  borderRadius: BorderRadius.all(Radius.circular(Shapes.radiusPill)),
);

const EdgeInsets _moodPillPadding =
    EdgeInsets.symmetric(vertical: 6, horizontal: 13);

final TextStyle _choosePillLabelStyle =
    TypographyTokens.caption11Sans.copyWith(color: Palette.onAccent);

const double _promptBloomOpacity = 0.5;

const double _promptBloomSize = 46;

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
              padding: _moodPillPadding,
              child: ExcludeSemantics(
                child: Text(label, style: TypographyTokens.caption11Sans),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodChoosePill extends StatelessWidget {
  const _MoodChoosePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _choosePillDecoration,
      child: Padding(
        padding: _moodPillPadding,
        child: Text(label, style: _choosePillLabelStyle),
      ),
    );
  }
}

const double _dayMoodCardGap = 13;

const double _dayMoodFlowerSize = 46;

const List<BoxShadow> _dayMoodCardShadow = <BoxShadow>[
  BoxShadow(color: Palette.ink20, offset: Offset(2, 2)),
];

const BoxDecoration _changeMoodButtonDecoration = BoxDecoration(
  color: Palette.cardLight,
  border: Border.fromBorderSide(
    BorderSide(color: Palette.ink, width: Shapes.outlineWidth),
  ),
  borderRadius: BorderRadius.all(Radius.circular(Shapes.radiusSm)),
  boxShadow: <BoxShadow>[
    BoxShadow(color: Palette.ink20, offset: Offset(1.5, 1.5)),
  ],
);

const EdgeInsets _changeMoodButtonPadding =
    EdgeInsets.symmetric(vertical: 8, horizontal: 14);

final TextStyle _changeMoodButtonLabelStyle =
    TypographyTokens.caption11Sans.copyWith(fontSize: 12, color: Palette.ink);

class DayMoodCard extends StatelessWidget {
  const DayMoodCard({
    super.key,
    required this.mood,
    required this.onChangeMood,
    this.changeLabel = 'Change mood',
  });

  final Mood mood;
  final VoidCallback? onChangeMood;
  final String changeLabel;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      surface: Palette.cardWarm,
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
      shadow: _dayMoodCardShadow,
      child: Row(
        children: <Widget>[
          FlowerBloom.forMood(mood, size: _dayMoodFlowerSize),
          const SizedBox(width: _dayMoodCardGap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Felt ${mood.label}', style: TypographyTokens.sectionSerif),
                Text(
                  "${mood.flower.label} · the day's bloom",
                  style: TypographyTokens.caption10Sans,
                ),
              ],
            ),
          ),
          const SizedBox(width: _dayMoodCardGap),
          _ChangeMoodButton(label: changeLabel, onTap: onChangeMood),
        ],
      ),
    );
  }
}

class _ChangeMoodButton extends StatelessWidget {
  const _ChangeMoodButton({required this.label, required this.onTap});

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
            decoration: _changeMoodButtonDecoration,
            child: Padding(
              padding: _changeMoodButtonPadding,
              child: ExcludeSemantics(
                child: Text(label, style: _changeMoodButtonLabelStyle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodPrompt extends StatelessWidget {
  const _MoodPrompt({
    required this.text,
    required this.onTap,
    this.isToday = true,
  });

  final String text;
  final VoidCallback? onTap;
  final bool isToday;

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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: <Widget>[
                const Opacity(
                  opacity: _promptBloomOpacity,
                  child: FlowerBloom(
                    kind: FlowerKind.peony,
                    size: _promptBloomSize,
                  ),
                ),
                const SizedBox(width: _moodBannerGap),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(text, style: TypographyTokens.bannerSerif),
                      Text(
                        isToday
                            ? "tap to plant today's bloom"
                            : "tap to plant this day's bloom",
                        style: TypographyTokens.promptAccent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: _moodBannerGap),
                const _MoodChoosePill(label: 'choose'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
