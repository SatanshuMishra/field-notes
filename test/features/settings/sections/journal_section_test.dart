import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
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

void main() {
  testWidgets('renders the journal controls', (WidgetTester tester) async {
    await _pumpSection(tester, repository: FakeSettingsRepository());

    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('Week starts on'), findsOneWidget);
    expect(find.text('Sunday'), findsOneWidget);
  });

  testWidgets('dragging the text size slider to the end saves the largest size',
      (WidgetTester tester) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(tester, repository: repository);

    final Rect track = tester.getRect(find.byType(Slider));
    await tester.tapAt(Offset(track.right - 4, track.center.dy));
    await tester.pumpAndSettle();

    expect(repository.textSizeWrites, <TextSize>[TextSize.large]);
  });

  testWidgets('choosing a week start saves it', (WidgetTester tester) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(tester, repository: repository);

    await tester.tap(find.byType(SettingsSelect<WeekStart>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monday').last);
    await tester.pumpAndSettle();

    expect(repository.weekStartWrites, <WeekStart>[WeekStart.monday]);
  });

  testWidgets('a failed write is reported to the feedback sink',
      (WidgetTester tester) async {
    final List<String> messages = <String>[];
    await _pumpSection(
      tester,
      repository: FakeSettingsRepository(writeError: StateError('disk full')),
      messages: messages,
    );

    await tester.tap(find.byType(SettingsSelect<WeekStart>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monday').last);
    await tester.pumpAndSettle();

    expect(messages, <String>['Could not save your week start.']);
  });
}
