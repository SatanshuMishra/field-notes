import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_settings_repository.dart';
import '../support/settings_harness.dart';

Future<void> _pumpSection(
  WidgetTester tester, {
  required FakeSettingsRepository repository,
  AppSettings settings = AppSettings.defaults,
}) async {
  useWideSurface(tester);
  await tester.pumpWidget(
    settingsFeatureHarness(
      JournalSection(settings: settings, onFeedback: (String message) {}),
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(repository),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(JournalSection)));

bool _noWritesRecorded(FakeSettingsRepository repository) =>
    repository.textSizeWrites.isEmpty &&
    repository.weekStartWrites.isEmpty &&
    repository.spellCheckEnabledWrites.isEmpty &&
    repository.reminderEnabledWrites.isEmpty &&
    repository.reminderTimeWrites.isEmpty &&
    repository.soundEnabledWrites.isEmpty &&
    repository.notificationPermissionAskedWrites.isEmpty &&
    repository.reflectionPromptsEnabledWrites.isEmpty &&
    repository.onboardingStatusWrites.isEmpty;

void main() {
  testWidgets('Journal shows Show the tour again with a Show tour button', (
    WidgetTester tester,
  ) async {
    await _pumpSection(tester, repository: FakeSettingsRepository());

    expect(find.text('Show the tour again'), findsOneWidget);
    expect(find.text('Six quick tips about the app.'), findsOneWidget);
    expect(find.text('Show tour'), findsOneWidget);
  });

  testWidgets('Show tour starts the tour replay without writing settings', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(tester, repository: repository);

    final ProviderContainer container = _container(tester);
    container
        .read(shellNavigationProvider.notifier)
        .select(ShellDestination.settings);

    await tester.tap(find.text('Show tour'));
    await tester.pumpAndSettle();

    expect(
      container.read(onboardingControllerProvider),
      const OnboardingFlowTour(tip: 0, mode: TourMode.replay),
    );
    expect(container.read(shellNavigationProvider), ShellDestination.today);
    expect(_noWritesRecorded(repository), isTrue);
  });
}
