import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/sound_service.dart';
import 'package:field_notes/features/sound/sound_providers.dart';
import 'package:field_notes/features/today/today_date.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import 'mood_banner.dart';
import 'mood_picker.dart';

const double _kConfirmMaxWidth = 420;

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

  String get _dayLabel {
    if (_isToday) {
      return 'today';
    }
    final DateTime? parsed = parseDateKey(widget.date);
    return parsed == null ? widget.date : headerDateLabel(parsed);
  }

  Future<bool> _confirmMoodChange(Mood chosen) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => _MoodChangeConfirmDialog(
        title: _isToday
            ? "Change today's bloom?"
            : "Change this day's bloom?",
        message: 'Set $_dayLabel to ${chosen.flower.label} · ${chosen.label}? '
            'Your current bloom will be replaced.',
      ),
    );
    return confirmed ?? false;
  }

  void _showPlantedToast(Mood chosen) {
    setState(() => _writeError = null);
    showTransientToast(context, 'Mood planted · ${chosen.flower.label}');
  }

  Future<void> _changeMood(Mood? current) async {
    final Mood? chosen = await showMoodPicker(context, selected: current);
    if (chosen == null || !mounted) {
      return;
    }
    if (current != null) {
      final bool confirmed = await _confirmMoodChange(chosen);
      if (!confirmed || !mounted) {
        return;
      }
    }
    try {
      await ref.read(soundServiceProvider).play(SoundCue.pencil);
      await ref
          .read(journalRepositoryProvider)
          .setMoodForDate(date: widget.date, mood: chosen);
      if (!mounted) {
        return;
      }
      _showPlantedToast(chosen);
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
    final VoidCallback? onChangeMood =
        interactive ? () => _changeMood(mood) : null;
    final TextStyle errorStyle = context.textStyles.captionSans.copyWith(
      color: context.colors.dangerInk,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!_isToday && mood != null)
          DayMoodCard(mood: mood, onChangeMood: onChangeMood)
        else
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

class _MoodChangeConfirmDialog extends StatelessWidget {
  const _MoodChangeConfirmDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kConfirmMaxWidth),
          child: StickerCard(
            surface: context.colors.cardBright,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: textStyles.titleSerif),
                const SizedBox(height: 8),
                Text(message, style: textStyles.bodySans),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    StickerButton(
                      label: 'Cancel',
                      variant: StickerButtonVariant.secondary,
                      padTapTarget: true,
                      autofocus: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    StickerButton(
                      label: 'Change mood',
                      variant: StickerButtonVariant.primary,
                      padTapTarget: true,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
