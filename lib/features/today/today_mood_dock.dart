import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/mood/mood_banner_for_date.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'today_providers.dart';

const double todayMoodDockHeight = 60;
const double todayMoodDockSideInset = 12;
const double todayMoodDockLift = 80;
const double todayMoodDockToastLift = 80;
const double todayMoodDockFeedClearance = 176;
const double todayMoodDockButtonHeight = 42;
const double todayMoodDockButtonHitHeight = 48;

const String todayMoodDockChangeLabel = 'Change';
const String todayMoodDockChooseLabel = 'Choose';
const String todayMoodDockPrompt = 'How are you feeling?';
const String todayMoodDockPromptHint = "tap to plant today's bloom";

const BorderRadius _cardRadius = BorderRadius.all(Radius.circular(20));
const BorderRadius _buttonRadius = BorderRadius.all(Radius.circular(12));
const EdgeInsets _moodPadding = EdgeInsets.fromLTRB(10, 6, 8, 6);
const EdgeInsets _promptPadding = EdgeInsets.fromLTRB(14, 6, 8, 6);
const EdgeInsets _changePadding = EdgeInsets.symmetric(horizontal: 13);
const EdgeInsets _choosePadding = EdgeInsets.symmetric(horizontal: 14);
const double _gap = 10;
const double _flowerSize = 36;
const double _buttonBorderWidth = 1.5;

const TextStyle _titleStyle = TextStyle(
  fontFamily: TypographyTokens.serif,
  fontSize: 16,
  fontWeight: FontWeight.w500,
  height: 1.15,
);

const TextStyle _bloomStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 11,
  fontWeight: FontWeight.w400,
);

const TextStyle _hintStyle = TextStyle(
  fontFamily: TypographyTokens.accent,
  fontSize: 13,
  fontWeight: FontWeight.w600,
);

const TextStyle _buttonStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w600,
);

class TodayMoodDock extends ConsumerWidget {
  const TodayMoodDock({super.key});

  Future<void> _changeMood(
    BuildContext context,
    WidgetRef ref, {
    required String date,
    required Mood? current,
  }) async {
    final MoodChangeOutcome outcome = await changeMoodForDate(
      context,
      ref,
      date: date,
      current: current,
    );
    if (outcome == MoodChangeOutcome.failed && context.mounted) {
      showTransientToast(
        context,
        moodSaveFailedMessage,
        glyph: IconStickerGlyph.close,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String date = ref.watch(todayDateProvider);
    final AsyncValue<Day?> dayAsync = ref.watch(dayForDateProvider(date));
    if (!dayAsync.hasValue || dayAsync.hasError) {
      return const SizedBox.shrink();
    }
    final Mood? mood = dayAsync.value?.mood;
    return _ToastLiftWhileShown(
      child: _MoodDockCard(
        mood: mood,
        onOpen: () => _changeMood(context, ref, date: date, current: mood),
      ),
    );
  }
}

class _ToastLiftWhileShown extends StatefulWidget {
  const _ToastLiftWhileShown({required this.child});

  final Widget child;

  @override
  State<_ToastLiftWhileShown> createState() => _ToastLiftWhileShownState();
}

class _ToastLiftWhileShownState extends State<_ToastLiftWhileShown> {
  late final ToastLift _lift;

  @override
  void initState() {
    super.initState();
    _lift = registerToastLift(todayMoodDockToastLift);
  }

  @override
  void dispose() {
    _lift.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _MoodDockCard extends StatelessWidget {
  const _MoodDockCard({required this.mood, required this.onOpen});

  final Mood? mood;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final Mood? current = mood;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onOpen,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: todayMoodDockHeight),
        child: GlassSurface(
          tone: GlassTone.paper,
          borderRadius: _cardRadius,
          padding: current == null ? _promptPadding : _moodPadding,
          child: Row(
            children: <Widget>[
              if (current != null) ...<Widget>[
                ExcludeSemantics(
                  child: FlowerBloom.forMood(current, size: _flowerSize),
                ),
                const SizedBox(width: _gap),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      current == null
                          ? todayMoodDockPrompt
                          : 'Feeling ${current.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle.copyWith(color: colors.ink),
                    ),
                    Text(
                      current == null
                          ? todayMoodDockPromptHint
                          : "${current.flower.label} · today's bloom",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (current == null ? _hintStyle : _bloomStyle)
                          .copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _gap),
              current == null
                  ? _DockButton(
                      label: todayMoodDockChooseLabel,
                      padding: _choosePadding,
                      decoration: BoxDecoration(
                        color: Palette.coral,
                        border: Border.all(
                          color: colors.line,
                          width: _buttonBorderWidth,
                        ),
                        borderRadius: _buttonRadius,
                      ),
                      foreground: Palette.onAccent,
                      onPressed: onOpen,
                    )
                  : _DockButton(
                      label: todayMoodDockChangeLabel,
                      padding: _changePadding,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Palette.coral,
                          width: _buttonBorderWidth,
                        ),
                        borderRadius: _buttonRadius,
                      ),
                      foreground: colors.accentInk,
                      onPressed: onOpen,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.label,
    required this.padding,
    required this.decoration,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final EdgeInsets padding;
  final BoxDecoration decoration;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: SizedBox(
          height: todayMoodDockButtonHitHeight,
          child: Center(
            widthFactor: 1,
            child: FocusRing(
              onPressed: onPressed,
              includeFocusSemantics: false,
              borderRadius: _buttonRadius,
              child: SizedBox(
                height: todayMoodDockButtonHeight,
                child: DecoratedBox(
                  decoration: decoration,
                  child: Padding(
                    padding: padding,
                    child: Center(
                      widthFactor: 1,
                      child: ExcludeSemantics(
                        child: Text(
                          label,
                          style: _buttonStyle.copyWith(color: foreground),
                        ),
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
