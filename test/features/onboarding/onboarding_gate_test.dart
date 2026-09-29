import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/onboarding_gate.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart' show FakeJournalRepository;
import '../settings/support/fake_settings_repository.dart';

class _SeededJournalRepository extends FakeJournalRepository {
  _SeededJournalRepository(this.days);

  final List<Day> days;

  @override
  Stream<List<Day>> watchAllDays() => Stream<List<Day>>.value(days);
}

class _UnreadableSettingsRepository extends FakeSettingsRepository {
  _UnreadableSettingsRepository() : super(storedValues: false);

  @override
  Future<AppSettings> load() async => throw StateError('settings unreadable');
}

const Day _day = Day(
  id: 'day-2026-07-20',
  date: '2026-07-20',
  createdAt: 0,
  updatedAt: 0,
);

ProviderContainer _container(
  FakeSettingsRepository settings, {
  List<Day> days = const <Day>[],
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      settingsRepositoryProvider.overrideWithValue(settings),
      journalRepositoryProvider.overrideWithValue(
        _SeededJournalRepository(days),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a fresh install writes pending and shows onboarding', () async {
    final FakeSettingsRepository settings = FakeSettingsRepository(
      storedValues: false,
    );
    final ProviderContainer container = _container(settings);

    final OnboardingVisibility visibility = await container.read(
      onboardingGateProvider.future,
    );

    expect(visibility, OnboardingVisibility.shown);
    expect(settings.onboardingStatusWrites, <OnboardingStatus>[
      OnboardingStatus.pending,
    ]);
  });

  test(
    'an install with a stored setting writes done and hides onboarding',
    () async {
      final FakeSettingsRepository settings = FakeSettingsRepository();
      final ProviderContainer container = _container(settings);

      final OnboardingVisibility visibility = await container.read(
        onboardingGateProvider.future,
      );

      expect(visibility, OnboardingVisibility.hidden);
      expect(settings.onboardingStatusWrites, <OnboardingStatus>[
        OnboardingStatus.done,
      ]);
    },
  );

  test('an install with a day writes done and hides onboarding', () async {
    final FakeSettingsRepository settings = FakeSettingsRepository(
      storedValues: false,
    );
    final ProviderContainer container = _container(
      settings,
      days: const <Day>[_day],
    );

    final OnboardingVisibility visibility = await container.read(
      onboardingGateProvider.future,
    );

    expect(visibility, OnboardingVisibility.hidden);
    expect(settings.onboardingStatusWrites, <OnboardingStatus>[
      OnboardingStatus.done,
    ]);
  });

  test('a pending status shows onboarding again', () async {
    final FakeSettingsRepository settings = FakeSettingsRepository(
      initial: AppSettings.defaults.copyWith(
        onboardingStatus: OnboardingStatus.pending,
      ),
    );
    final ProviderContainer container = _container(
      settings,
      days: const <Day>[_day],
    );

    final OnboardingVisibility visibility = await container.read(
      onboardingGateProvider.future,
    );

    expect(visibility, OnboardingVisibility.shown);
    expect(settings.onboardingStatusWrites, isEmpty);
  });

  test('a done status never shows onboarding', () async {
    final FakeSettingsRepository settings = FakeSettingsRepository(
      initial: AppSettings.defaults.copyWith(
        onboardingStatus: OnboardingStatus.done,
      ),
      storedValues: false,
    );
    final ProviderContainer container = _container(settings);

    final OnboardingVisibility visibility = await container.read(
      onboardingGateProvider.future,
    );

    expect(visibility, OnboardingVisibility.hidden);
    expect(settings.onboardingStatusWrites, isEmpty);
  });

  test('complete writes done and hides onboarding', () async {
    final FakeSettingsRepository settings = FakeSettingsRepository(
      storedValues: false,
    );
    final ProviderContainer container = _container(settings);
    expect(
      await container.read(onboardingGateProvider.future),
      OnboardingVisibility.shown,
    );

    await container.read(onboardingGateProvider.notifier).complete();

    expect(
      container.read(onboardingGateProvider).value,
      OnboardingVisibility.hidden,
    );
    expect(settings.onboardingStatusWrites, <OnboardingStatus>[
      OnboardingStatus.pending,
      OnboardingStatus.done,
    ]);
  });

  test(
    'a fresh install still shows onboarding when writing pending fails',
    () async {
      final FakeSettingsRepository settings = FakeSettingsRepository(
        writeError: StateError('disk full'),
        storedValues: false,
      );
      final ProviderContainer container = _container(settings);

      final OnboardingVisibility visibility = await container.read(
        onboardingGateProvider.future,
      );

      expect(visibility, OnboardingVisibility.shown);
      expect(settings.onboardingStatusWrites, isEmpty);
    },
  );

  test('a failed settings read hides onboarding and writes nothing', () async {
    final FakeSettingsRepository settings = _UnreadableSettingsRepository();
    final ProviderContainer container = _container(settings);

    final OnboardingVisibility visibility = await container.read(
      onboardingGateProvider.future,
    );

    expect(visibility, OnboardingVisibility.hidden);
    expect(settings.onboardingStatusWrites, isEmpty);
  });
}
