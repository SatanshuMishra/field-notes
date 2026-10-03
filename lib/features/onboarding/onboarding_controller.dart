import 'dart:async';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/first_entry.dart';
import 'package:field_notes/features/onboarding/onboarding_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_gate.dart';
import 'package:field_notes/features/onboarding/reminder_choice.dart';
import 'package:field_notes/features/onboarding/setup/week_start_suggestion.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/reminders/reminder_scheduler.dart';
import 'package:field_notes/features/settings/settings_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_controller.g.dart';

const String _finishError = "Couldn't save your choices. Try again.";
const String _lineError = "Couldn't save this line. Keep typing to try again.";

const Duration _linePause = Duration(milliseconds: 600);

const int _minimumNoteCharacters = 2;

typedef _Line = ({int run, String date, String text});
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
    this.picked = false,
    this.noteText = '',
    this.noteEntryId,
    this.noteSave = NoteSaveState.idle,
    this.noteError,
    this.monthFill = 0,
    this.monthReached = false,
    this.yearDay = 0,
    this.yearScrubbed = false,
    this.showingOtherWays = false,
    this.reminder = ReminderChoice.evening,
    this.notificationsOff = false,
    this.petalFlower,
    this.finishError,
  });

  final String entryDate;
  final bool planted;
  final bool grown;
  final Mood mood;
  final bool picked;
  final String noteText;
  final String? noteEntryId;
  final NoteSaveState noteSave;
  final String? noteError;
  final double monthFill;
  final bool monthReached;
  final int yearDay;
  final bool yearScrubbed;
  final bool showingOtherWays;
  final ReminderChoice reminder;
  final bool notificationsOff;
  final FlowerKind? petalFlower;
  final WeekStart regionWeek;
  final WeekStart week;
  final String? finishError;

  OnboardingDraft copyWith({
    String? entryDate,
    bool? planted,
    bool? grown,
    Mood? mood,
    bool? picked,
    String? noteText,
    ValueGetter<String?>? noteEntryId,
    NoteSaveState? noteSave,
    ValueGetter<String?>? noteError,
    double? monthFill,
    bool? monthReached,
    int? yearDay,
    bool? yearScrubbed,
    bool? showingOtherWays,
    ReminderChoice? reminder,
    bool? notificationsOff,
    ValueGetter<FlowerKind?>? petalFlower,
    WeekStart? regionWeek,
    WeekStart? week,
    ValueGetter<String?>? finishError,
  }) => OnboardingDraft(
    entryDate: entryDate ?? this.entryDate,
    planted: planted ?? this.planted,
    grown: grown ?? this.grown,
    mood: mood ?? this.mood,
    picked: picked ?? this.picked,
    noteText: noteText ?? this.noteText,
    noteEntryId: noteEntryId == null ? this.noteEntryId : noteEntryId(),
    noteSave: noteSave ?? this.noteSave,
    noteError: noteError == null ? this.noteError : noteError(),
    monthFill: monthFill ?? this.monthFill,
    monthReached: monthReached ?? this.monthReached,
    yearDay: yearDay ?? this.yearDay,
    yearScrubbed: yearScrubbed ?? this.yearScrubbed,
    showingOtherWays: showingOtherWays ?? this.showingOtherWays,
    reminder: reminder ?? this.reminder,
    notificationsOff: notificationsOff ?? this.notificationsOff,
    petalFlower: petalFlower == null ? this.petalFlower : petalFlower(),
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
          other.picked == picked &&
          other.noteText == noteText &&
          other.noteEntryId == noteEntryId &&
          other.noteSave == noteSave &&
          other.noteError == noteError &&
          other.monthFill == monthFill &&
          other.monthReached == monthReached &&
          other.yearDay == yearDay &&
          other.yearScrubbed == yearScrubbed &&
          other.showingOtherWays == showingOtherWays &&
          other.reminder == reminder &&
          other.notificationsOff == notificationsOff &&
          other.petalFlower == petalFlower &&
          other.regionWeek == regionWeek &&
          other.week == week &&
          other.finishError == finishError;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    entryDate,
    planted,
    grown,
    mood,
    picked,
    noteText,
    noteEntryId,
    noteSave,
    noteError,
    monthFill,
    monthReached,
    yearDay,
    yearScrubbed,
    showingOtherWays,
    reminder,
    notificationsOff,
    petalFlower,
    regionWeek,
    week,
    finishError,
  ]);

  @override
  String toString() =>
      'OnboardingDraft(entryDate: $entryDate, planted: $planted, '
      'grown: $grown, mood: $mood, picked: $picked, noteText: $noteText, '
      'noteEntryId: $noteEntryId, noteSave: $noteSave, '
      'noteError: $noteError, monthFill: $monthFill, '
      'monthReached: $monthReached, yearDay: $yearDay, '
      'yearScrubbed: $yearScrubbed, showingOtherWays: $showingOtherWays, '
      'reminder: $reminder, '
      'notificationsOff: $notificationsOff, petalFlower: $petalFlower, '
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
      OnboardingChapter.month =>
        draft.monthFill >= _minimumMonthFill || draft.monthReached,
      OnboardingChapter.year =>
        draft.yearDay >= _daysInYear || draft.yearScrubbed,
      OnboardingChapter.theme ||
      OnboardingChapter.reminder ||
      OnboardingChapter.week ||
      OnboardingChapter.tour => true,
    };

@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  int _run = 0;
  Timer? _pause;
  _Line? _lineQueued;
  Future<void>? _lineSaving;
  String? _lineEntryId;
  Future<void> _moodSaving = Future<void>.value();
  bool _asking = false;
  bool _finishing = false;

  @override
  OnboardingFlow build() {
    ref.onDispose(() {
      _run++;
      _lineQueued = null;
      _pause?.cancel();
      _pause = null;
    });
    return const OnboardingFlowHidden();
  }

  void start() {
    final int run = ++_run;
    _pause?.cancel();
    _pause = null;
    _lineQueued = null;
    _lineEntryId = null;
    final WeekStart region = suggestWeekStart(
      ref.read(onboardingCountryCodeProvider),
    );
    final String date = ref.read(todayDateProvider);
    state = OnboardingFlowRunning(
      chapter: OnboardingChapter.opening,
      draft: OnboardingDraft(entryDate: date, regionWeek: region, week: region),
    );
    unawaited(_prefill(run, date));
  }

  void plant() =>
      _edit((OnboardingDraft draft) => draft.copyWith(planted: true));

  void markGrown() => _edit(
    (OnboardingDraft draft) =>
        draft.copyWith(grown: true, petalFlower: () => FlowerKind.peony),
  );

  void markPlantGrown(Mood mood) => _edit(
    (OnboardingDraft draft) => draft.copyWith(petalFlower: () => mood.flower),
  );

  void chooseMood(Mood mood) => _edit(
    (OnboardingDraft draft) => draft.copyWith(mood: mood, picked: true),
  );

  void setNote(String text) {
    if (state is! OnboardingFlowRunning) {
      return;
    }
    _edit((OnboardingDraft draft) => draft.copyWith(noteText: text));
    _pause?.cancel();
    _pause = Timer(_linePause, _onPause);
  }

  void setMonthFill(double fill) => _edit((OnboardingDraft draft) {
    final double clamped = fill.clamp(0, 1).toDouble();
    return draft.copyWith(
      monthFill: clamped,
      monthReached: draft.monthReached || clamped >= _minimumMonthFill,
    );
  });

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

  Future<void> next() async {
    switch (state) {
      case OnboardingFlowMap():
        closeMap();
      case OnboardingFlowRunning(
        chapter: OnboardingChapter.opening,
        draft: OnboardingDraft(planted: false),
      ):
        plant();
      case OnboardingFlowRunning(
        chapter: OnboardingChapter.reminder,
        :final OnboardingDraft draft,
      ):
        await _leaveReminder(_run, draft);
      case OnboardingFlowRunning(
            :final OnboardingChapter chapter,
            :final OnboardingDraft draft,
          )
          when canAdvance:
        if (chapter == OnboardingChapter.day) {
          _leaveDay(draft);
        }
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

  void openOtherWays() {
    if (state
        case OnboardingFlowRunning(
          chapter: OnboardingChapter.moment,
          :final OnboardingDraft draft,
        )
        when _taskDone(OnboardingChapter.moment, draft)) {
      _edit((OnboardingDraft draft) => draft.copyWith(showingOtherWays: true));
    }
  }

  void closeOtherWays() =>
      _edit((OnboardingDraft draft) => draft.copyWith(showingOtherWays: false));

  void skipToSetup() {
    if (state
        case OnboardingFlowRunning(
          :final OnboardingChapter chapter,
          :final OnboardingDraft draft,
        )
        when chapter.isStory) {
      if (chapter == OnboardingChapter.day) {
        _leaveDay(draft);
      }
      _open(OnboardingChapter.theme);
    }
  }

  Future<void> finish() async {
    if (_finishing || state is! OnboardingFlowRunning) {
      return;
    }
    _finishing = true;
    try {
      await _finish(_run);
    } finally {
      _finishing = false;
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

  Future<void> _finish(int run) async {
    _edit((OnboardingDraft draft) => draft.copyWith(finishError: () => null));
    _saveLineNow();
    final OnboardingDraft? draft = _draftOf(run);
    if (draft == null) {
      return;
    }
    final bool remind =
        draft.reminder != ReminderChoice.off && await _notificationsGranted();
    if (!await _saveChoices(draft, remind: remind)) {
      _failFinish(run);
      return;
    }
    try {
      await ref.read(onboardingGateProvider.notifier).complete();
    } catch (error) {
      debugPrint('Could not record that onboarding finished: $error');
      _failFinish(run);
      return;
    }
    if (_draftOf(run) != null) {
      state = const OnboardingFlowHidden();
    }
  }

  void _failFinish(int run) => _editRun(
    run,
    (OnboardingDraft draft) => draft.copyWith(finishError: () => _finishError),
  );

  Future<void> _leaveReminder(int run, OnboardingDraft draft) async {
    if (_asking) {
      return;
    }
    _asking = true;
    try {
      if (draft.reminder != ReminderChoice.off &&
          !draft.notificationsOff &&
          !await _askForNotifications()) {
        _editRun(
          run,
          (OnboardingDraft current) => current.copyWith(notificationsOff: true),
        );
        return;
      }
      await _recordPromptAsked();
    } finally {
      _asking = false;
    }
    if (run != _run) {
      return;
    }
    if (state case OnboardingFlowRunning(chapter: OnboardingChapter.reminder)) {
      _open(OnboardingChapter.week);
    }
  }

  Future<bool> _askForNotifications() async {
    try {
      await ref
          .read(reminderPermissionStatusProvider.notifier)
          .requestUnlessGranted();
    } catch (error) {
      debugPrint('Could not ask for notification permission: $error');
    }
    return _notificationsGranted();
  }

  Future<bool> _notificationsGranted() async {
    try {
      return await ref.read(reminderPermissionStatusProvider.future) ==
          ReminderPermission.granted;
    } catch (error) {
      debugPrint('Could not read the notification permission: $error');
      return false;
    }
  }

  Future<void> _recordPromptAsked() async {
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setNotificationPermissionAsked(true);
    } catch (error) {
      debugPrint('Could not record the notification prompt: $error');
    }
  }

  Future<bool> _saveChoices(
    OnboardingDraft draft, {
    required bool remind,
  }) async {
    final SettingsController settings;
    try {
      settings = ref.read(settingsControllerProvider);
    } catch (error) {
      debugPrint('Could not open the settings to save: $error');
      return false;
    }
    final List<Future<SettingsWriteResult> Function()> writes =
        <Future<SettingsWriteResult> Function()>[
          () => settings.setReminderEnabled(remind),
          () => settings.setReminderTime(
            draft.reminder.time ?? ReminderTime.defaultTime,
          ),
          () => settings.setWeekStart(draft.week),
        ];
    for (final Future<SettingsWriteResult> Function() write in writes) {
      if (await write() is SettingsWriteFailed) {
        return false;
      }
    }
    return true;
  }

  Future<void> _prefill(int run, String date) async {
    final FirstEntrySaved saved;
    try {
      saved = await ref.read(firstEntryProvider).read(date);
    } catch (error) {
      debugPrint('Could not read today for onboarding: $error');
      return;
    }
    final OnboardingDraft? draft = _draftOf(run);
    if (draft == null) {
      return;
    }
    final Mood? mood = draft.picked ? null : saved.mood;
    final Entry? note = _lineEntryId == null && draft.noteText.isEmpty
        ? saved.note
        : null;
    if (mood == null && note == null) {
      return;
    }
    if (note != null) {
      _lineEntryId = note.id;
    }
    _edit((OnboardingDraft current) {
      final OnboardingDraft withMood = mood == null
          ? current
          : current.copyWith(mood: mood);
      return note == null
          ? withMood
          : withMood.copyWith(
              noteText: note.textContent ?? '',
              noteEntryId: () => note.id,
              noteSave: NoteSaveState.saved,
              noteError: () => null,
            );
    });
  }

  void _leaveDay(OnboardingDraft draft) {
    _saveMood(draft);
    _edit(
      (OnboardingDraft current) =>
          current.copyWith(petalFlower: () => current.mood.flower),
    );
  }

  void _saveMood(OnboardingDraft draft) {
    _moodSaving = _moodSaving.then(
      (void _) => _writeMood(draft.entryDate, draft.mood),
    );
  }

  Future<void> _writeMood(String date, Mood mood) async {
    try {
      await ref.read(firstEntryProvider).saveMood(date: date, mood: mood);
    } catch (error) {
      debugPrint('Could not save the onboarding mood: $error');
    }
  }

  void _saveLineNow() {
    final Timer? pause = _pause;
    if (pause != null) {
      pause.cancel();
      _onPause();
    }
  }

  void _onPause() {
    _pause = null;
    final OnboardingDraft? draft = _draftOf(_run);
    if (draft == null) {
      return;
    }
    _lineQueued = (run: _run, date: draft.entryDate, text: draft.noteText);
    _lineSaving ??= _saveLines();
  }

  Future<void> _saveLines() async {
    try {
      for (_Line? line = _lineQueued; line != null; line = _lineQueued) {
        _lineQueued = null;
        await _saveLine(line);
      }
    } finally {
      _lineSaving = null;
    }
  }

  Future<void> _saveLine(_Line line) async {
    if (line.run != _run) {
      return;
    }
    final String? entryId = _lineEntryId;
    if (line.text.trim().isEmpty) {
      await _eraseLine(line.run, entryId);
      return;
    }
    _editRun(
      line.run,
      (OnboardingDraft draft) => draft.copyWith(noteSave: NoteSaveState.saving),
    );
    final String saved;
    try {
      saved = await ref
          .read(firstEntryProvider)
          .saveLine(date: line.date, entryId: entryId, text: line.text);
    } catch (error) {
      debugPrint('Could not save the onboarding line: $error');
      _failLine(line.run);
      return;
    }
    if (line.run != _run) {
      return;
    }
    _lineEntryId = saved;
    _edit(
      (OnboardingDraft draft) => draft.copyWith(
        noteEntryId: () => saved,
        noteSave: NoteSaveState.saved,
        noteError: () => null,
      ),
    );
  }

  Future<void> _eraseLine(int run, String? entryId) async {
    if (entryId != null) {
      try {
        await ref.read(firstEntryProvider).eraseLine(entryId);
      } catch (error) {
        debugPrint('Could not remove the onboarding line: $error');
        _failLine(run);
        return;
      }
    }
    if (run != _run) {
      return;
    }
    _lineEntryId = null;
    _edit(
      (OnboardingDraft draft) => draft.copyWith(
        noteEntryId: () => null,
        noteSave: NoteSaveState.idle,
        noteError: () => null,
      ),
    );
  }

  void _failLine(int run) => _editRun(
    run,
    (OnboardingDraft draft) => draft.copyWith(
      noteSave: NoteSaveState.failed,
      noteError: () => _lineError,
    ),
  );

  OnboardingDraft? _draftOf(int run) {
    if (run != _run) {
      return null;
    }
    return switch (state) {
      OnboardingFlowRunning(:final OnboardingDraft draft) => draft,
      OnboardingFlowHidden() || OnboardingFlowMap() => null,
    };
  }

  void _open(OnboardingChapter chapter) {
    if (state case final OnboardingFlowRunning running) {
      state = running.copyWith(
        chapter: chapter,
        draft: running.draft.copyWith(showingOtherWays: false),
      );
    }
  }

  void _edit(OnboardingDraft Function(OnboardingDraft draft) change) {
    if (state case final OnboardingFlowRunning running) {
      state = running.copyWith(draft: change(running.draft));
    }
  }

  void _editRun(
    int run,
    OnboardingDraft Function(OnboardingDraft draft) change,
  ) {
    if (run == _run) {
      _edit(change);
    }
  }
}
