import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/features/settings/sections/performance_section.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

Future<void> _pumpGroups(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                JournalSection(
                  settings: AppSettings.defaults,
                  onFeedback: (String message) {},
                  spellCheckAvailable: true,
                ),
                PerformanceSection(
                  settings: AppSettings.defaults,
                  onFeedback: (String message) {},
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('journal rows sit in look, writing and performance groups', (
    WidgetTester tester,
  ) async {
    await _pumpGroups(
      tester,
      platform: TargetPlatform.macOS,
      size: const Size(1140, 726),
    );

    final List<String> order = <String>[
      'look',
      'Appearance',
      'Text size',
      'writing',
      'Week starts on',
      'Spell check',
      'Show the tour again',
      'performance',
      'Pause the Meadow in the background',
    ];
    for (final String text in order) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    for (int index = 1; index < order.length; index++) {
      expect(
        _top(tester, order[index]),
        greaterThan(_top(tester, order[index - 1])),
        reason: '${order[index]} after ${order[index - 1]}',
      );
    }
    expect(find.text('Journal'), findsNothing);
    expect(find.text('Performance'), findsNothing);

    await _pumpGroups(
      tester,
      platform: TargetPlatform.android,
      size: const Size(384, 832),
    );

    expect(find.text('Journal'), findsNothing);
    expect(find.text('look'), findsNothing);
    expect(find.text('Performance'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Show the tour again'), findsOneWidget);
  });

  testWidgets('renders the journal controls', (WidgetTester tester) async {
    await _pumpSection(tester, repository: FakeSettingsRepository());

    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('Week starts on'), findsOneWidget);
    expect(find.text('Sunday'), findsOneWidget);
  });

  testWidgets(
    'the text size row offers Small, Medium and Large and saves the choice',
    (WidgetTester tester) async {
      final FakeSettingsRepository repository = FakeSettingsRepository();
      await _pumpSection(
        tester,
        repository: repository,
        settings: AppSettings.defaults.copyWith(textSize: TextSize.medium),
      );

      final Finder segmented = find.byType(SettingsSegmented<TextSize>);
      Finder segment(String label) =>
          find.descendant(of: segmented, matching: find.text(label));
      expect(segment('Small'), findsOneWidget);
      expect(segment('Medium'), findsOneWidget);
      expect(segment('Large'), findsOneWidget);
      expect(
        tester.getSemantics(segment('Medium')),
        isSemantics(label: 'Medium', isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(segment('Large')),
        isSemantics(label: 'Large', isButton: true, isSelected: false),
      );
      expect(find.byType(Slider), findsNothing);

      await tester.tap(segment('Large'));
      await tester.pumpAndSettle();

      expect(repository.textSizeWrites, <TextSize>[TextSize.large]);
    },
  );

  testWidgets('choosing a week start saves it', (WidgetTester tester) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(tester, repository: repository);

    await tester.tap(find.byType(SettingsSelect<WeekStart>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monday').last);
    await tester.pumpAndSettle();

    expect(repository.weekStartWrites, <WeekStart>[WeekStart.monday]);
  });

  testWidgets('a failed write is reported to the feedback sink', (
    WidgetTester tester,
  ) async {
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
