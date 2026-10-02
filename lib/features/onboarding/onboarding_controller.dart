import 'dart:async';

import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/domain/settings/week_start.dart';
import 'package:field_notes/features/onboarding/onboarding_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_gate.dart';
import 'package:field_notes/features/onboarding/reminder_choice.dart';
import 'package:field_notes/features/onboarding/setup/week_start_suggestion.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_controller.g.dart';

const String _finishError = "Couldn't save your choices. Try again.";

const int _minimumNoteCharacters = 2;
const double _minimumMonthFill = 0.2;
const int _daysInYear = 365;

enum NoteSaveState { idle, saving, saved, failed }

@immutable
class OnboardingDraft {
  const OnboardingDraft({
    required this.entryDate,
    required this.regionWeek,
    required this.week,
    this.planted = false,
    this.grown = false,
    this.mood = Mood.happy,
    this.noteText = '',
    this.noteEntryId,
    this.noteSave = NoteSaveState.idle,
    this.noteError,
    this.monthFill = 0,
    this.yearDay = 0,
    this.yearScrubbed = false,
    this.reminder = ReminderChoice.evening,
    this.finishError,
  });

  final String entryDate;
  final bool planted;
  final bool grown;
  final Mood mood;
  final String noteText;
  final String? noteEntryId;
  final NoteSaveState noteSave;
  final String? noteError;
  final double monthFill;
  final int yearDay;
  final bool yearScrubbed;
  final ReminderChoice reminder;
  final WeekStart regionWeek;
  final WeekStart week;
  final String? finishError;

  OnboardingDraft copyWith({
    String? entryDate,
    bool? planted,
    bool? grown,
    Mood? mood,
    String? noteText,
    ValueGetter<String?>? noteEntryId,
    NoteSaveState? noteSave,
    ValueGetter<String?>? noteError,
    double? monthFill,
    int? yearDay,
    bool? yearScrubbed,
    ReminderChoice? reminder,
    WeekStart? regionWeek,
    WeekStart? week,
    ValueGetter<String?>? finishError,
  }) => OnboardingDraft(
    entryDate: entryDate ?? this.entryDate,
    planted: planted ?? this.planted,
    grown: grown ?? this.grown,
    mood: mood ?? this.mood,
    noteText: noteText ?? this.noteText,
    noteEntryId: noteEntryId == null ? this.noteEntryId : noteEntryId(),
    noteSave: noteSave ?? this.noteSave,
    noteError: noteError == null ? this.noteError : noteError(),
    monthFill: monthFill ?? this.monthFill,
    yearDay: yearDay ?? this.yearDay,
    yearScrubbed: yearScrubbed ?? this.yearScrubbed,
    reminder: reminder ?? this.reminder,
    regionWeek: regionWeek ?? this.regionWeek,
    week: week ?? this.week,
    finishError: finishError == null ? this.finishError : finishError(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingDraft &&
          other.entryDate == entryDate &&
          other.planted == planted &&
          other.grown == grown &&
          other.mood == mood &&
          other.noteText == noteText &&
          other.noteEntryId == noteEntryId &&
          other.noteSave == noteSave &&
          other.noteError == noteError &&
          other.monthFill == monthFill &&
          other.yearDay == yearDay &&
          other.yearScrubbed == yearScrubbed &&
          other.reminder == reminder &&
          other.regionWeek == regionWeek &&
          other.week == week &&
          other.finishError == finishError;

  @override
  int get hashCode => Object.hash(
    entryDate,
    planted,
    grown,
    mood,
    noteText,
    noteEntryId,
    noteSave,
    noteError,
    monthFill,
    yearDay,
    yearScrubbed,
    reminder,
    regionWeek,
    week,
    finishError,
  );

  @override
  String toString() =>
      'OnboardingDraft(entryDate: $entryDate, planted: $planted, '
      'grown: $grown, mood: $mood, noteText: $noteText, '
      'noteEntryId: $noteEntryId, noteSave: $noteSave, '
      'noteError: $noteError, monthFill: $monthFill, yearDay: $yearDay, '
      'yearScrubbed: $yearScrubbed, reminder: $reminder, '
      'regionWeek: $regionWeek, week: $week, finishError: $finishError)';
}

final Provider<String?> onboardingCountryCodeProvider = Provider<String?>(
  (Ref ref) => PlatformDispatcher.instance.locale.countryCode,
);

sealed class OnboardingFlow {
  const OnboardingFlow();
}

final class OnboardingFlowHidden extends OnboardingFlow {
  const OnboardingFlowHidden();

  @override
  bool operator ==(Object other) => other is OnboardingFlowHidden;

  @override
  int get hashCode => (OnboardingFlowHidden).hashCode;
}

final class OnboardingFlowRunning extends OnboardingFlow {
  const OnboardingFlowRunning({required this.chapter, required this.draft});

  final OnboardingChapter chapter;
  final OnboardingDraft draft;

  OnboardingFlowRunning copyWith({
    OnboardingChapter? chapter,
    OnboardingDraft? draft,
  }) => OnboardingFlowRunning(
    chapter: chapter ?? this.chapter,
    draft: draft ?? this.draft,
  );

  @override
  bool operator ==(Object other) =>
      other is OnboardingFlowRunning &&
      other.chapter == chapter &&
      other.draft == draft;

  @override
  int get hashCode => Object.hash(chapter, draft);

  @override
  String toString() => 'OnboardingFlowRunning($chapter, $draft)';
}

final class OnboardingFlowMap extends OnboardingFlow {
  const OnboardingFlowMap();

  @override
  bool operator ==(Object other) => other is OnboardingFlowMap;

  @override
  int get hashCode => (OnboardingFlowMap).hashCode;
}

bool _taskDone(OnboardingChapter chapter, OnboardingDraft draft) =>
    switch (chapter) {
      OnboardingChapter.opening => draft.planted && draft.grown,
      OnboardingChapter.day => true,
      OnboardingChapter.moment =>
        draft.noteText.trim().length >= _minimumNoteCharacters,
      OnboardingChapter.month => draft.monthFill >= _minimumMonthFill,
      OnboardingChapter.year =>
        draft.yearDay >= _daysInYear || draft.yearScrubbed,
      OnboardingChapter.theme ||
      OnboardingChapter.reminder ||
      OnboardingChapter.week ||
      OnboardingChapter.tour => true,
    };

@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  @override
  OnboardingFlow build() => const OnboardingFlowHidden();

  void start() {
    final WeekStart region = suggestWeekStart(
      ref.read(onboardingCountryCodeProvider),
    );
    state = OnboardingFlowRunning(
      chapter: OnboardingChapter.opening,
      draft: OnboardingDraft(
        entryDate: ref.read(todayDateProvider),
        regionWeek: region,
        week: region,
      ),
    );
  }

  void plant() =>
      _edit((OnboardingDraft draft) => draft.copyWith(planted: true));

  void markGrown() =>
      _edit((OnboardingDraft draft) => draft.copyWith(grown: true));

  void chooseMood(Mood mood) =>
      _edit((OnboardingDraft draft) => draft.copyWith(mood: mood));

  void setNote(String text) =>
      _edit((OnboardingDraft draft) => draft.copyWith(noteText: text));

  void setMonthFill(double fill) => _edit(
    (OnboardingDraft draft) =>
        draft.copyWith(monthFill: fill.clamp(0, 1).toDouble()),
  );

  void setYearDay(int day, {required bool scrubbed}) => _edit(
    (OnboardingDraft draft) => draft.copyWith(
      yearDay: day.clamp(0, _daysInYear),
      yearScrubbed: draft.yearScrubbed || scrubbed,
    ),
  );

  void chooseReminder(ReminderChoice choice) =>
      _edit((OnboardingDraft draft) => draft.copyWith(reminder: choice));

  void chooseWeek(WeekStart week) =>
      _edit((OnboardingDraft draft) => draft.copyWith(week: week));

  bool get canAdvance => switch (state) {
    OnboardingFlowRunning(:final OnboardingChapter chapter, :final draft) =>
      _taskDone(chapter, draft),
    OnboardingFlowMap() => true,
    OnboardingFlowHidden() => false,
  };

  void next() {
    switch (state) {
      case OnboardingFlowMap():
        closeMap();
      case OnboardingFlowRunning(
        chapter: OnboardingChapter.opening,
        draft: OnboardingDraft(planted: false),
      ):
        plant();
      case OnboardingFlowRunning(:final OnboardingChapter chapter)
          when canAdvance:
        if (chapter == OnboardingChapter.tour) {
          unawaited(finish());
        } else {
          _open(OnboardingChapter.values[chapter.index + 1]);
        }
      case OnboardingFlowRunning() || OnboardingFlowHidden():
        return;
    }
  }

  void back() {
    switch (state) {
      case OnboardingFlowMap():
        closeMap();
      case OnboardingFlowRunning(:final OnboardingChapter chapter)
          when chapter != OnboardingChapter.opening:
        _open(OnboardingChapter.values[chapter.index - 1]);
      case OnboardingFlowRunning() || OnboardingFlowHidden():
        return;
    }
  }

  void goTo(OnboardingChapter target) {
    if (state case OnboardingFlowRunning(:final OnboardingChapter chapter)
        when target.index < chapter.index) {
      _open(target);
    }
  }

  void skipToSetup() {
    if (state case OnboardingFlowRunning(:final OnboardingChapter chapter)
        when chapter.isStory) {
      _open(OnboardingChapter.theme);
    }
  }

  Future<void> finish() async {
    if (state is! OnboardingFlowRunning) {
      return;
    }
    _edit((OnboardingDraft draft) => draft.copyWith(finishError: () => null));
    try {
      await ref.read(onboardingGateProvider.notifier).complete();
    } catch (error) {
      debugPrint('Could not record that onboarding finished: $error');
      _edit(
        (OnboardingDraft draft) =>
            draft.copyWith(finishError: () => _finishError),
      );
      return;
    }
    if (state is OnboardingFlowRunning) {
      state = const OnboardingFlowHidden();
    }
  }

  void showMap() {
    if (state is OnboardingFlowHidden) {
      state = const OnboardingFlowMap();
    }
  }

  void closeMap() {
    if (state is OnboardingFlowMap) {
      state = const OnboardingFlowHidden();
    }
  }

  void _open(OnboardingChapter chapter) {
    if (state case final OnboardingFlowRunning running) {
      state = running.copyWith(chapter: chapter);
    }
  }

  void _edit(OnboardingDraft Function(OnboardingDraft draft) change) {
    if (state case final OnboardingFlowRunning running) {
      state = running.copyWith(draft: change(running.draft));
    }
  }
}
