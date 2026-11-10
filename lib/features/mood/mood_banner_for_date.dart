import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/sound_service.dart';
import 'package:field_notes/features/sound/sound_providers.dart';
import 'package:field_notes/features/today/today_date.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import 'mood_banner.dart';
import 'mood_picker.dart';

const String moodSaveFailedMessage =
    "Couldn't save your mood. Please try again.";

const String _keepBloomLabel = 'Keep this bloom';
const String _changeBloomLabel = 'Change bloom';

enum MoodChangeOutcome { unchanged, planted, failed }

Future<MoodChangeOutcome> changeMoodForDate(
  BuildContext context,
  WidgetRef ref, {
  required String date,
  required Mood? current,
}) async {
  final Mood? chosen = await showMoodPicker(context, selected: current);
  if (chosen == null || !context.mounted) {
    return MoodChangeOutcome.unchanged;
  }
  if (current != null) {
    final bool confirmed = await _confirmMoodChange(
      context,
      isToday: date == ref.read(todayDateProvider),
      date: date,
      chosen: chosen,
    );
    if (!confirmed || !context.mounted) {
      return MoodChangeOutcome.unchanged;
    }
  }
  try {
    await ref.read(soundServiceProvider).play(SoundCue.pencil);
    await ref
        .read(journalRepositoryProvider)
        .setMoodForDate(date: date, mood: chosen);
  } catch (_) {
    return MoodChangeOutcome.failed;
  }
  if (context.mounted) {
    showTransientToast(context, 'Mood planted · ${chosen.flower.label}');
  }
  return MoodChangeOutcome.planted;
}

String _dayName(String date, {required bool isToday}) {
  if (isToday) {
    return 'Today';
  }
  final DateTime? parsed = parseDateKey(date);
  return parsed == null ? date : headerDateLabel(parsed);
}

Future<bool> _confirmMoodChange(
  BuildContext context, {
  required bool isToday,
  required String date,
  required Mood chosen,
}) {
  return showConfirmDialog(
    context,
    title: isToday ? "Change today's bloom?" : "Change this day's bloom?",
    message:
        '${_dayName(date, isToday: isToday)} becomes '
        '${chosen.flower.label}, ${chosen.label}. '
        'Your current bloom will be replaced.',
    confirmLabel: _changeBloomLabel,
    cancelLabel: _keepBloomLabel,
  );
}

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

  bool get _isToday => widget.date == ref.read(todayDateProvider);

  Future<void> _changeMood(Mood? current) async {
    final MoodChangeOutcome outcome = await changeMoodForDate(
      context,
      ref,
      date: widget.date,
      current: current,
    );
    if (!mounted) {
      return;
    }
    switch (outcome) {
      case MoodChangeOutcome.unchanged:
        return;
      case MoodChangeOutcome.planted:
        setState(() => _writeError = null);
      case MoodChangeOutcome.failed:
        setState(() => _writeError = moodSaveFailedMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Day?> dayAsync = ref.watch(
      dayForDateProvider(widget.date),
    );
    final Mood? mood = dayAsync.value?.mood;
    final bool interactive = dayAsync.hasValue;
    final VoidCallback? onChangeMood = interactive
        ? () => _changeMood(mood)
        : null;
    final TextStyle errorStyle = context.textStyles.captionSans.copyWith(
      color: context.colors.dangerInk,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MoodBanner(
          mood: mood,
          promptText: widget.promptText,
          onChangeMood: onChangeMood,
          isToday: _isToday,
        ),
        if (dayAsync.hasError) ...<Widget>[
          const SizedBox(height: 8),
          Text("Couldn't load today's mood.", style: errorStyle),
        ],
        if (_writeError != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(_writeError!, style: errorStyle),
        ],
      ],
    );
  }
}
