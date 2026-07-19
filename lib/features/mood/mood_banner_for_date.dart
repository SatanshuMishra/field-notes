import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/state/state.dart';

import 'mood_banner.dart';
import 'mood_picker.dart';

class MoodBannerForDate extends ConsumerStatefulWidget {
  const MoodBannerForDate({
    super.key,
    required this.date,
    this.promptText = 'How are you feeling today?',
  });

  final String date;
  final String promptText;

  @override
  ConsumerState<MoodBannerForDate> createState() => _MoodBannerForDateState();
}

class _MoodBannerForDateState extends ConsumerState<MoodBannerForDate> {
  String? _writeError;

  Future<void> _changeMood(Mood? current) async {
    final Mood? chosen = await showMoodPicker(context, selected: current);
    if (chosen == null || !mounted) {
      return;
    }
    try {
      await ref
          .read(journalRepositoryProvider)
          .setMoodForDate(date: widget.date, mood: chosen);
      if (!mounted) {
        return;
      }
      setState(() => _writeError = null);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(
        () => _writeError = "Couldn't save your mood. Please try again.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Day?> dayAsync =
        ref.watch(dayForDateProvider(widget.date));
    final Mood? mood = dayAsync.value?.mood;
    final bool interactive = dayAsync.hasValue;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MoodBanner(
          mood: mood,
          promptText: widget.promptText,
          onChangeMood: interactive ? () => _changeMood(mood) : null,
        ),
        if (dayAsync.hasError) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            "Couldn't load today's mood.",
            style: TypographyTokens.captionSans.copyWith(color: Palette.danger),
          ),
        ],
        if (_writeError != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _writeError!,
            style: TypographyTokens.captionSans.copyWith(color: Palette.danger),
          ),
        ],
      ],
    );
  }
}
