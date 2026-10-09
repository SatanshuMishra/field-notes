import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/spell_check_availability.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/sync_overrides.dart';
import 'support/fake_settings_repository.dart';
import 'support/recording_reminder_scheduler.dart';
import 'support/settings_harness.dart';

const String _explanation =
    "Your keyboard's spell checker isn't available to Field Notes.";

class _FakeSpellCheckService implements SpellCheckService {
  const _FakeSpellCheckService(this.answer);

  final List<SuggestionSpan>? answer;

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    return answer;
  }
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required FakeSettingsRepository repository,
  required SpellCheckService service,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  useWideSurface(tester);
  final AppSettings settings = AppSettings.defaults.copyWith(
    spellCheckEnabled: true,
  );
  await tester.pumpWidget(
    settingsFeatureHarness(
      const SettingsScreen(),
      scrollable: false,
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(repository),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(settings),
        ),
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<List<Entry>>.value(const <Entry>[]),
        ),
        reminderClockProvider.overrideWithValue(() => DateTime(2026, 7, 20, 9)),
        reminderSchedulerProvider.overrideWithValue(
          RecordingReminderScheduler(),
        ),
        spellCheckAvailabilityPlatformProvider.overrideWithValue(platform),
        spellCheckAvailabilityServiceProvider.overrideWithValue(service),
        ...syncOffOverrides(),
      ],
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(settingsTabKey(SettingsTab.journal)));
  await tester.pumpAndSettle();
}

SettingsToggle _toggle(WidgetTester tester) {
  return tester.widget<SettingsToggle>(find.byKey(spellCheckToggleKey));
}

Future<SpellCheckAvailability> _resolve(
  TargetPlatform platform,
  SpellCheckService service,
) async {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      spellCheckAvailabilityPlatformProvider.overrideWithValue(platform),
      spellCheckAvailabilityServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  return container.read(spellCheckAvailabilityProvider.future);
}

void main() {
  testWidgets(
    'an unavailable spell checker disables the switch and explains why',
    (WidgetTester tester) async {
      final FakeSettingsRepository repository = FakeSettingsRepository();
      await _pumpScreen(
        tester,
        repository: repository,
        service: const _FakeSpellCheckService(null),
      );

      expect(find.text(_explanation), findsOneWidget);
      expect(_toggle(tester).enabled, isFalse);
      expect(_toggle(tester).value, isFalse);

      await tester.ensureVisible(find.byKey(spellCheckToggleKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(spellCheckToggleKey));
      await tester.pumpAndSettle();

      expect(repository.spellCheckEnabledWrites, isEmpty);
      expect(_toggle(tester).value, isFalse);
    },
  );

  testWidgets('a working spell checker keeps the switch enabled', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: FakeSettingsRepository(),
      service: const _FakeSpellCheckService(<SuggestionSpan>[
        SuggestionSpan(TextRange(start: 0, end: 3), <String>['the']),
      ]),
    );

    expect(find.text(_explanation), findsNothing);
    expect(_toggle(tester).enabled, isTrue);
    expect(_toggle(tester).value, isTrue);
  });

  test('Windows probes the native checker before calling spell check '
      'available', () async {
    expect(
      await _resolve(
        TargetPlatform.windows,
        const _FakeSpellCheckService(<SuggestionSpan>[]),
      ),
      SpellCheckAvailability.unavailable,
    );
    expect(
      await _resolve(
        TargetPlatform.windows,
        const _FakeSpellCheckService(<SuggestionSpan>[
          SuggestionSpan(TextRange(start: 0, end: 3), <String>['the']),
        ]),
      ),
      SpellCheckAvailability.available,
    );
    expect(
      await _resolve(
        TargetPlatform.macOS,
        const _FakeSpellCheckService(<SuggestionSpan>[]),
      ),
      SpellCheckAvailability.available,
    );
  });
}
