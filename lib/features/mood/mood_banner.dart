import 'package:flutter/widgets.dart';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
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
    final FieldNotesTextStyles textStyles = context.textStyles;
    return StickerCard(
      surface: context.colors.cardWarm,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      child: Row(
        children: <Widget>[
          ExcludeSemantics(child: FlowerBloom.forMood(current, size: 54)),
          const SizedBox(width: _moodBannerGap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Feeling ${current.label} today',
                  style: textStyles.bannerSerif,
                ),
                Text(
                  '${current.flower.label} · your bloom for the day',
                  style: textStyles.captionSans,
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

const BorderRadius _pillRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusPill),
);

const BoxDecoration _changePillDecoration = BoxDecoration(
  border: Border.fromBorderSide(
    BorderSide(color: Palette.coral, width: Shapes.outlineWidth),
  ),
  borderRadius: _pillRadius,
);

BoxDecoration _choosePillDecoration(FieldNotesColors colors) => BoxDecoration(
  color: Palette.coral,
  border: Border.fromBorderSide(
    BorderSide(color: colors.line, width: Shapes.outlineWidth),
  ),
  borderRadius: _pillRadius,
);

const EdgeInsets _moodPillPadding = EdgeInsets.symmetric(
  vertical: 6,
  horizontal: 13,
);

const double _promptBloomOpacity = 0.5;

const BorderRadius _promptRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusLg),
);

const double _promptBloomSize = 46;

const double _minTapTarget = 48;

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
          child: _MinTapTarget(
            child: FocusRing(
              enabled: isEnabled,
              onPressed: onTap,
              borderRadius: _pillRadius,
              child: DecoratedBox(
                decoration: _changePillDecoration,
                child: Padding(
                  padding: _moodPillPadding,
                  child: ExcludeSemantics(
                    child: Text(label, style: context.textStyles.caption11Sans),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MinTapTarget extends StatelessWidget {
  const _MinTapTarget({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _minTapTarget,
        minHeight: _minTapTarget,
      ),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}

class _MoodChoosePill extends StatelessWidget {
  const _MoodChoosePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _choosePillDecoration(context.colors),
      child: Padding(
        padding: _moodPillPadding,
        child: Text(
          label,
          style: context.textStyles.caption11Sans.copyWith(
            color: Palette.onAccent,
          ),
        ),
      ),
    );
  }
}

const double _dayMoodCardGap = 13;

const double _dayMoodFlowerSize = 46;

List<BoxShadow> _dayMoodCardShadow(FieldNotesColors colors) => <BoxShadow>[
  BoxShadow(color: colors.shadowTint(0x33), offset: const Offset(2, 2)),
];

const BorderRadius _changeMoodButtonRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusSm),
);

BoxDecoration _changeMoodButtonDecoration(FieldNotesColors colors) =>
    BoxDecoration(
      color: colors.cardLight,
      border: Border.fromBorderSide(
        BorderSide(color: colors.line, width: Shapes.outlineWidth),
      ),
      borderRadius: _changeMoodButtonRadius,
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: colors.shadowTint(0x33),
          offset: const Offset(1.5, 1.5),
        ),
      ],
    );

const EdgeInsets _changeMoodButtonPadding = EdgeInsets.symmetric(
  vertical: 8,
  horizontal: 14,
);

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
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles textStyles = context.textStyles;
    return StickerCard(
      surface: colors.cardWarm,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 13),
      shadow: _dayMoodCardShadow(colors),
      child: Row(
        children: <Widget>[
          ExcludeSemantics(
            child: FlowerBloom.forMood(mood, size: _dayMoodFlowerSize),
          ),
          const SizedBox(width: _dayMoodCardGap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Felt ${mood.label}', style: textStyles.sectionSerif),
                Text(
                  "${mood.flower.label} · the day's bloom",
                  style: textStyles.caption10Sans,
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
    final FieldNotesColors colors = context.colors;
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
          child: _MinTapTarget(
            child: FocusRing(
              enabled: isEnabled,
              onPressed: onTap,
              borderRadius: _changeMoodButtonRadius,
              child: DecoratedBox(
                decoration: _changeMoodButtonDecoration(colors),
                child: Padding(
                  padding: _changeMoodButtonPadding,
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      style: context.textStyles.caption11Sans.copyWith(
                        fontSize: 12,
                        color: colors.ink,
                      ),
                    ),
                  ),
                ),
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
    final String hint = isToday
        ? "tap to plant today's bloom"
        : "tap to plant this day's bloom";
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Semantics(
      button: onTap != null,
      label: '$text\n$hint',
      onTap: onTap,
      child: FocusRing(
        enabled: onTap != null,
        onPressed: onTap,
        borderRadius: _promptRadius,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: CustomPaint(
              painter: MoodPromptBorderPainter(
                color: colors.line,
                fill: colors.cardWarm,
                shadows: context.shadows.heroSoft,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
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
                          Text(text, style: textStyles.bannerSerif),
                          Text(hint, style: textStyles.promptAccent),
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
        ),
      ),
    );
  }
}
