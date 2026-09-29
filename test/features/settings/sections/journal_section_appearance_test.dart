import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_settings_repository.dart';
import '../support/settings_harness.dart';

Future<void> _pumpSection(
  WidgetTester tester, {
  required FakeSettingsRepository repository,
  AppSettings settings = AppSettings.defaults,
  List<String>? messages,
}) async {
  useWideSurface(tester);
  await tester.pumpWidget(
    settingsFeatureHarness(
      JournalSection(
        settings: settings,
        onFeedback: (String message) => messages?.add(message),
      ),
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(repository),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Finder _segment(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(GestureDetector));

void main() {
  testWidgets(
    'Appearance is the first Journal row with Light, Dark and System',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pumpSection(
        tester,
        repository: FakeSettingsRepository(),
        settings: AppSettings.defaults.copyWith(appearance: Appearance.dark),
      );

      final SettingsFieldRow first = tester
          .widgetList<SettingsFieldRow>(find.byType(SettingsFieldRow))
          .first;
      expect(first.label, 'Appearance');
      expect(first.description, 'Light, dark, or match your device.');
      expect(first.control, isA<SettingsSegmented<Appearance>>());
      expect(
        (first.control as SettingsSegmented<Appearance>).value,
        Appearance.dark,
      );
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(
        tester.getSemantics(_segment('Dark')),
        isSemantics(label: 'Dark', isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(_segment('Light')),
        isSemantics(label: 'Light', isButton: true, isSelected: false),
      );
      expect(
        tester.getSemantics(_segment('System')),
        isSemantics(label: 'System', isButton: true, isSelected: false),
      );
      semantics.dispose();
    },
  );

  testWidgets('choosing Dark writes the dark appearance', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(tester, repository: repository);

    await tester.tap(_segment('Dark'));
    await tester.pumpAndSettle();

    expect(repository.appearanceWrites, <Appearance>[Appearance.dark]);
  });

  testWidgets('a failed appearance write shows the failure message', (
    WidgetTester tester,
  ) async {
    final List<String> messages = <String>[];
    await _pumpSection(
      tester,
      repository: FakeSettingsRepository(writeError: StateError('disk full')),
      messages: messages,
    );

    await tester.tap(_segment('Dark'));
    await tester.pumpAndSettle();

    expect(messages, <String>['Could not save your appearance.']);
  });
}
