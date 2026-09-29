import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/state/repository_providers.dart';
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
  testWidgets('Week starts on offers Sunday, Monday and Saturday', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(tester, repository: repository);

    await tester.tap(find.byType(SettingsSelect<WeekStart>));
    await tester.pumpAndSettle();

    expect(find.text('Sunday'), findsWidgets);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Saturday'), findsOneWidget);

    await tester.tap(find.text('Saturday').last);
    await tester.pumpAndSettle();

    expect(repository.weekStartWrites, <WeekStart>[WeekStart.saturday]);
  });
}
