import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:field_notes/data/settings/settings_keys.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/note_engine/capabilities.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/features/settings/settings_controller.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../state/state_test_support.dart';
import 'support/fake_settings_repository.dart';
import 'support/settings_harness.dart';

void _useSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required SettingsRepository repository,
  required bool spellCheckAvailable,
  AppSettings settings = AppSettings.defaults,
  List<String>? messages,
}) async {
  await tester.pumpWidget(
    settingsFeatureHarness(
      JournalSection(
        settings: settings,
        onFeedback: (String message) => messages?.add(message),
        spellCheckAvailable: spellCheckAvailable,
      ),
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(repository),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _heldPress(WidgetTester tester, Finder finder) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(finder),
  );
  await tester.pump(const Duration(milliseconds: 110));
  await gesture.up();
  await tester.pumpAndSettle();
}

SettingsToggle _toggle(WidgetTester tester) {
  return tester.widget<SettingsToggle>(find.byKey(spellCheckToggleKey));
}

Future<Setting?> _spellCheckRow(AppDatabase db) {
  return (db.select(db.settings)
        ..where(($SettingsTable t) => t.key.equals(SettingsKeys.spellCheck)))
      .getSingleOrNull();
}

void main() {
  testWidgets('spell check is off by default', (WidgetTester tester) async {
    _useSurface(tester);

    expect(AppSettings.defaults.spellCheckEnabled, isFalse);

    final AppSettings? loaded = await tester.runAsync(() async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      final AppSettings settings = await DriftSettingsRepository(db).load();
      await db.close();
      return settings;
    });
    expect(loaded, isNotNull);
    expect(loaded!.spellCheckEnabled, isFalse);

    await _pumpSection(
      tester,
      repository: FakeSettingsRepository(),
      spellCheckAvailable: true,
    );

    expect(find.text('Spell check'), findsOneWidget);
    expect(_toggle(tester).value, isFalse);
  });

  testWidgets('the journal section switch persists spell check', (
    WidgetTester tester,
  ) async {
    _useSurface(tester);
    final FakeSettingsRepository repository = FakeSettingsRepository();

    await _pumpSection(
      tester,
      repository: repository,
      spellCheckAvailable: true,
    );
    await _heldPress(tester, find.byKey(spellCheckToggleKey));

    expect(repository.spellCheckEnabledWrites, <bool>[true]);

    await _pumpSection(
      tester,
      repository: repository,
      spellCheckAvailable: true,
      settings: AppSettings.defaults.copyWith(spellCheckEnabled: true),
    );
    expect(_toggle(tester).value, isTrue);

    await _heldPress(tester, find.byKey(spellCheckToggleKey));

    expect(repository.spellCheckEnabledWrites, <bool>[true, false]);

    final List<Object?>? stored = await tester.runAsync(() async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      final DriftSettingsRepository drift = DriftSettingsRepository(db);
      await drift.setSpellCheckEnabled(true);
      final AppSettings afterOn = await drift.load();
      final Setting? rowOn = await _spellCheckRow(db);
      await drift.setSpellCheckEnabled(false);
      final AppSettings afterOff = await drift.load();
      final Setting? rowOff = await _spellCheckRow(db);
      await db.close();
      return <Object?>[
        afterOn.spellCheckEnabled,
        rowOn?.value,
        afterOff.spellCheckEnabled,
        rowOff?.value,
      ];
    });

    expect(stored, <Object?>[true, 'true', false, 'false']);
  });

  testWidgets('the switch is absent when spell check is unavailable', (
    WidgetTester tester,
  ) async {
    _useSurface(tester);

    await _pumpSection(
      tester,
      repository: FakeSettingsRepository(),
      spellCheckAvailable: false,
    );

    expect(find.byKey(spellCheckToggleKey), findsNothing);
    expect(find.text('Spell check'), findsNothing);
    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('Week starts on'), findsOneWidget);

    await _pumpSection(
      tester,
      repository: FakeSettingsRepository(),
      spellCheckAvailable: true,
    );

    expect(find.byKey(spellCheckToggleKey), findsOneWidget);
    expect(find.text('Spell check'), findsOneWidget);
  });

  group('AppSettings.spellCheckEnabled', () {
    test('copyWith changes only spell check', () {
      const AppSettings base = AppSettings.defaults;
      final AppSettings changed = base.copyWith(spellCheckEnabled: true);

      expect(changed.spellCheckEnabled, isTrue);
      expect(changed.reminderEnabled, base.reminderEnabled);
      expect(changed.reminderTime, base.reminderTime);
      expect(changed.soundEnabled, base.soundEnabled);
      expect(changed.textSize, base.textSize);
      expect(changed.weekStart, base.weekStart);
      expect(changed.copyWith(spellCheckEnabled: false), base);
    });

    test('equality, hashCode and toString include spell check', () {
      const AppSettings base = AppSettings.defaults;
      final AppSettings changed = base.copyWith(spellCheckEnabled: true);

      expect(changed == base, isFalse);
      expect(changed.hashCode == base.hashCode, isFalse);
      expect(changed, base.copyWith(spellCheckEnabled: true));
      expect(changed.hashCode, base.copyWith(spellCheckEnabled: true).hashCode);
      expect(changed.toString(), contains('spellCheckEnabled: true'));
      expect(base.toString(), contains('spellCheckEnabled: false'));
    });
  });

  group('DriftSettingsRepository spell check', () {
    test('an unreadable stored value reads as off', () async {
      final AppDatabase db = newTestDatabase();
      addTearDown(db.close);
      await db
          .into(db.settings)
          .insert(
            SettingsCompanion.insert(
              key: SettingsKeys.spellCheck,
              value: 'maybe',
            ),
          );

      final AppSettings settings = await DriftSettingsRepository(db).load();

      expect(settings.spellCheckEnabled, isFalse);
    });

    test('a repeated write upserts one row', () async {
      final AppDatabase db = newTestDatabase();
      addTearDown(db.close);
      final DriftSettingsRepository repository = DriftSettingsRepository(db);

      await repository.setSpellCheckEnabled(true);
      await repository.setSpellCheckEnabled(false);
      await repository.setSpellCheckEnabled(true);

      final List<Setting> rows =
          await (db.select(db.settings)..where(
                ($SettingsTable t) => t.key.equals(SettingsKeys.spellCheck),
              ))
              .get();
      expect(rows.length, 1);
      expect(rows.single.value, 'true');
    });
  });

  test(
    'spellCheckEnabledProvider starts off then follows the setting',
    () async {
      final AppDatabase db = newTestDatabase();
      addTearDown(db.close);
      final ProviderContainer container = newTestContainer(db);
      final SettingsRepository settings = container.read(
        settingsRepositoryProvider,
      );

      final ProviderSubscription<bool> sub = container.listen(
        spellCheckEnabledProvider,
        (bool? _, bool _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await pumpEventQueue();
      expect(container.read(spellCheckEnabledProvider), isFalse);

      await settings.setSpellCheckEnabled(true);
      await pumpEventQueue();
      expect(container.read(spellCheckEnabledProvider), isTrue);
    },
  );

  group('SettingsController.setSpellCheckEnabled', () {
    test('a successful write records the value', () async {
      final FakeSettingsRepository repository = FakeSettingsRepository();

      final SettingsWriteResult result = await SettingsController(
        repository: repository,
      ).setSpellCheckEnabled(true);

      expect(result, isA<SettingsWriteSucceeded>());
      expect(repository.spellCheckEnabledWrites, <bool>[true]);
    });

    test('a failed write returns the spell check message', () async {
      final SettingsWriteResult result = await SettingsController(
        repository: FakeSettingsRepository(writeError: StateError('disk full')),
      ).setSpellCheckEnabled(true);

      expect(
        result,
        isA<SettingsWriteFailed>().having(
          (SettingsWriteFailed failed) => failed.message,
          'message',
          'Could not save your spell check setting.',
        ),
      );
    });

    testWidgets('the section reports a failed write', (
      WidgetTester tester,
    ) async {
      _useSurface(tester);
      final List<String> messages = <String>[];

      await _pumpSection(
        tester,
        repository: FakeSettingsRepository(writeError: StateError('disk full')),
        spellCheckAvailable: true,
        messages: messages,
      );
      await _heldPress(tester, find.byKey(spellCheckToggleKey));

      expect(messages, <String>['Could not save your spell check setting.']);
    });
  });

  testWidgets('the default section shows the switch exactly when available', (
    WidgetTester tester,
  ) async {
    _useSurface(tester);

    await tester.pumpWidget(
      settingsFeatureHarness(
        JournalSection(
          settings: AppSettings.defaults,
          onFeedback: (String _) {},
        ),
        overrides: <Override>[
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(spellCheckToggleKey),
      spellCheckAvailable ? findsOneWidget : findsNothing,
    );
  });
}
