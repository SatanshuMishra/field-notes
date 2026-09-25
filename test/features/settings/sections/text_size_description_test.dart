import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_settings_repository.dart';
import '../support/settings_harness.dart';

void main() {
  testWidgets('the text size row says it applies across the app', (
    WidgetTester tester,
  ) async {
    useWideSurface(tester);
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

    expect(find.text('Applies across the app.'), findsOneWidget);
  });
}
