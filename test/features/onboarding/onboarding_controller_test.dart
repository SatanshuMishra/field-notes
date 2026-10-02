import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart' show FakeJournalRepository;
import '../settings/support/fake_settings_repository.dart';

const String _today = '2026-10-01';

ProviderContainer _container({
  String? country = 'US',
  FakeSettingsRepository? settings,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      todayDateProvider.overrideWithValue(_today),
      onboardingCountryCodeProvider.overrideWithValue(country),
      settingsRepositoryProvider.overrideWithValue(
        settings ?? FakeSettingsRepository(storedValues: false),
      ),
      journalRepositoryProvider.overrideWithValue(FakeJournalRepository()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

OnboardingController _controller(ProviderContainer container) =>
    container.read(onboardingControllerProvider.notifier);

OnboardingFlow _flow(ProviderContainer container) =>
    container.read(onboardingControllerProvider);

OnboardingChapter? _chapter(ProviderContainer container) =>
    switch (_flow(container)) {
      OnboardingFlowRunning(:final OnboardingChapter chapter) => chapter,
      OnboardingFlowHidden() || OnboardingFlowMap() => null,
    };

OnboardingDraft _draft(ProviderContainer container) =>
    (_flow(container) as OnboardingFlowRunning).draft;

void _doTask(OnboardingController controller, OnboardingChapter chapter) {
  switch (chapter) {
    case OnboardingChapter.opening:
      controller
        ..plant()
        ..markGrown();
    case OnboardingChapter.moment:
      controller.setNote('A first line');
    case OnboardingChapter.month:
      controller.setMonthFill(1);
    case OnboardingChapter.year:
      controller.setYearDay(365, scrubbed: false);
    case OnboardingChapter.day ||
        OnboardingChapter.theme ||
        OnboardingChapter.reminder ||
        OnboardingChapter.week ||
        OnboardingChapter.tour:
      return;
  }
}

ProviderContainer _startedAt(OnboardingChapter target) {
  final ProviderContainer container = _container();
  final OnboardingController controller = _controller(container)..start();
  for (final OnboardingChapter chapter in OnboardingChapter.values) {
    if (chapter == target) {
      break;
    }
    _doTask(controller, chapter);
    controller.next();
  }
  expect(_chapter(container), target);
  return container;
}

void main() {
  test('the chapters carry their progress names and story flag in order', () {
    expect(
      <String>[
        for (final OnboardingChapter chapter in OnboardingChapter.values)
          chapter.progressName,
      ],
      <String>[
        'Opening',
        'A day',
        'A moment',
        'A month',
        'A year',
        'Theme',
        'Reminder',
        'Week',
        'The app',
      ],
    );
    expect(
      <OnboardingChapter>[
        for (final OnboardingChapter chapter in OnboardingChapter.values)
          if (chapter.isStory) chapter,
      ],
      <OnboardingChapter>[
        OnboardingChapter.opening,
        OnboardingChapter.day,
        OnboardingChapter.moment,
        OnboardingChapter.month,
        OnboardingChapter.year,
      ],
    );
  });

  test('the reminder choices map to their preset times and clocks', () {
    expect(
      <ReminderTime?>[
        for (final ReminderChoice choice in ReminderChoice.values) choice.time,
      ],
      <ReminderTime?>[
        const ReminderTime(hour: 8, minute: 0),
        const ReminderTime(hour: 12, minute: 30),
        const ReminderTime(hour: 20, minute: 30),
        null,
      ],
    );
    expect(
      <String>[
        for (final ReminderChoice choice in ReminderChoice.values) choice.clock,
      ],
      <String>['08:00', '12:30', '20:30', 'Off'],
    );
  });

  test('start captures today and the region week and opens the Opening', () {
    final ProviderContainer us = _container();
    expect(_flow(us), const OnboardingFlowHidden());
    _controller(us).start();
    expect(
      _flow(us),
      const OnboardingFlowRunning(
        chapter: OnboardingChapter.opening,
        draft: OnboardingDraft(
          entryDate: _today,
          regionWeek: WeekStart.sunday,
          week: WeekStart.sunday,
        ),
      ),
    );
    expect(_draft(us).mood, Mood.happy);
    expect(_draft(us).noteText, '');
    expect(_draft(us).noteSave, NoteSaveState.idle);
    expect(_draft(us).reminder, ReminderChoice.evening);

    final ProviderContainer germany = _container(country: 'DE');
    _controller(germany).start();
    expect(_draft(germany).regionWeek, WeekStart.monday);
    expect(_draft(germany).week, WeekStart.monday);

    _controller(germany).chooseWeek(WeekStart.saturday);
    expect(_draft(germany).week, WeekStart.saturday);
    expect(_draft(germany).regionWeek, WeekStart.monday);
  });

  test("next is offered only once each chapter's task is done", () {
    final ProviderContainer container = _container();
    final OnboardingController controller = _controller(container)..start();

    expect(_chapter(container), OnboardingChapter.opening);
    expect(controller.canAdvance, isFalse);
    controller.plant();
    expect(controller.canAdvance, isFalse);
    controller.markGrown();
    expect(controller.canAdvance, isTrue);
    controller.next();

    expect(_chapter(container), OnboardingChapter.day);
    expect(_draft(container).mood, Mood.happy);
    expect(controller.canAdvance, isTrue);
    controller.chooseMood(Mood.calm);
    expect(_draft(container).mood, Mood.calm);
    expect(controller.canAdvance, isTrue);
    controller.next();

    expect(_chapter(container), OnboardingChapter.moment);
    expect(controller.canAdvance, isFalse);
    controller.setNote('a');
    expect(controller.canAdvance, isFalse);
    controller.setNote('  ');
    expect(controller.canAdvance, isFalse);
    controller.setNote(' a ');
    expect(controller.canAdvance, isFalse);
    controller.setNote('ab');
    expect(controller.canAdvance, isTrue);
    controller.next();

    expect(_chapter(container), OnboardingChapter.month);
    expect(controller.canAdvance, isFalse);
    controller.setMonthFill(0.19);
    expect(controller.canAdvance, isFalse);
    controller.setMonthFill(0.2);
    expect(controller.canAdvance, isTrue);
    controller.next();

    expect(_chapter(container), OnboardingChapter.year);
    expect(controller.canAdvance, isFalse);
    controller.setYearDay(364, scrubbed: false);
    expect(controller.canAdvance, isFalse);
    controller.setYearDay(365, scrubbed: false);
    expect(controller.canAdvance, isTrue);

    final ProviderContainer scrubbed = _startedAt(OnboardingChapter.year);
    final OnboardingController scrubber = _controller(scrubbed);
    expect(scrubber.canAdvance, isFalse);
    scrubber.setYearDay(40, scrubbed: true);
    expect(scrubber.canAdvance, isTrue);
    expect(_draft(scrubbed).yearScrubbed, isTrue);
    scrubber.setYearDay(0, scrubbed: false);
    expect(scrubber.canAdvance, isTrue);

    controller.next();
    for (final OnboardingChapter chapter in <OnboardingChapter>[
      OnboardingChapter.theme,
      OnboardingChapter.reminder,
      OnboardingChapter.week,
      OnboardingChapter.tour,
    ]) {
      expect(_chapter(container), chapter);
      expect(controller.canAdvance, isTrue, reason: chapter.name);
      if (chapter != OnboardingChapter.tour) {
        controller.next();
      }
    }
  });

  test('next plants on the Opening and waits for the task elsewhere', () {
    final ProviderContainer container = _container();
    final OnboardingController controller = _controller(container)..start();

    controller.next();
    expect(_chapter(container), OnboardingChapter.opening);
    expect(_draft(container).planted, isTrue);
    expect(_draft(container).grown, isFalse);
    controller.next();
    expect(_chapter(container), OnboardingChapter.opening);

    controller
      ..markGrown()
      ..next()
      ..next();
    expect(_chapter(container), OnboardingChapter.moment);
    controller.next();
    expect(_chapter(container), OnboardingChapter.moment);
  });

  test('back, goTo and skipToSetup only move where they are allowed', () {
    final ProviderContainer container = _startedAt(OnboardingChapter.month);
    final OnboardingController controller = _controller(container);

    controller.goTo(OnboardingChapter.week);
    expect(_chapter(container), OnboardingChapter.month);
    controller.goTo(OnboardingChapter.month);
    expect(_chapter(container), OnboardingChapter.month);
    controller.goTo(OnboardingChapter.day);
    expect(_chapter(container), OnboardingChapter.day);

    controller.back();
    expect(_chapter(container), OnboardingChapter.opening);
    controller.back();
    expect(_chapter(container), OnboardingChapter.opening);

    controller.skipToSetup();
    expect(_chapter(container), OnboardingChapter.theme);
    controller.skipToSetup();
    expect(_chapter(container), OnboardingChapter.theme);

    controller.next();
    controller.next();
    controller.next();
    expect(_chapter(container), OnboardingChapter.tour);
    controller.skipToSetup();
    expect(_chapter(container), OnboardingChapter.tour);
    expect(_draft(container).noteText, 'A first line');
    expect(_draft(container).planted, isTrue);
  });

  test('the map opens only when hidden and next or back closes it', () {
    final ProviderContainer container = _container();
    final OnboardingController controller = _controller(container);

    controller.closeMap();
    expect(_flow(container), const OnboardingFlowHidden());
    controller.showMap();
    expect(_flow(container), const OnboardingFlowMap());
    expect(controller.canAdvance, isTrue);
    controller.next();
    expect(_flow(container), const OnboardingFlowHidden());

    controller
      ..showMap()
      ..back();
    expect(_flow(container), const OnboardingFlowHidden());

    controller
      ..showMap()
      ..skipToSetup()
      ..goTo(OnboardingChapter.opening);
    expect(_flow(container), const OnboardingFlowMap());
    controller.closeMap();
    expect(_flow(container), const OnboardingFlowHidden());

    controller.start();
    controller.showMap();
    controller.closeMap();
    expect(_chapter(container), OnboardingChapter.opening);
  });

  test('finishing from the tour records done and hides onboarding', () async {
    final FakeSettingsRepository settings = FakeSettingsRepository(
      storedValues: false,
    );
    final ProviderContainer container = _container(settings: settings);
    final OnboardingController controller = _controller(container)..start();
    for (final OnboardingChapter chapter in OnboardingChapter.values) {
      _doTask(controller, chapter);
      if (chapter != OnboardingChapter.tour) {
        controller.next();
      }
    }
    expect(_chapter(container), OnboardingChapter.tour);

    await controller.finish();

    expect(_flow(container), const OnboardingFlowHidden());
    expect(settings.onboardingStatusWrites.last, OnboardingStatus.done);
    expect(
      container.read(onboardingGateProvider).value,
      OnboardingVisibility.hidden,
    );
  });

  test('a failed finish keeps the tour with the error', () async {
    final ProviderContainer container = _container(
      settings: FakeSettingsRepository(
        storedValues: false,
        writeError: StateError('disk full'),
      ),
    );
    final OnboardingController controller = _controller(container)..start();
    controller.skipToSetup();
    controller
      ..next()
      ..next()
      ..next();
    expect(_chapter(container), OnboardingChapter.tour);

    await controller.finish();

    expect(_chapter(container), OnboardingChapter.tour);
    expect(
      _draft(container).finishError,
      "Couldn't save your choices. Try again.",
    );
  });

  test('the draft copies by value and clears its optional fields', () {
    const OnboardingDraft base = OnboardingDraft(
      entryDate: _today,
      regionWeek: WeekStart.monday,
      week: WeekStart.monday,
    );
    final OnboardingDraft saved = base.copyWith(
      noteEntryId: () => 'entry-1',
      noteError: () => 'failed',
      finishError: () => 'not saved',
      noteSave: NoteSaveState.failed,
    );
    expect(saved == base, isFalse);
    expect(saved.noteEntryId, 'entry-1');
    expect(
      saved.copyWith(mood: Mood.sad),
      base.copyWith(
        mood: Mood.sad,
        noteEntryId: () => 'entry-1',
        noteError: () => 'failed',
        finishError: () => 'not saved',
        noteSave: NoteSaveState.failed,
      ),
    );
    final OnboardingDraft cleared = saved.copyWith(
      noteEntryId: () => null,
      noteError: () => null,
      finishError: () => null,
      noteSave: NoteSaveState.idle,
    );
    expect(cleared, base);
    expect(cleared.hashCode, base.hashCode);
  });
}
