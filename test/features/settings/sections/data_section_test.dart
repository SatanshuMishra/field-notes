import 'dart:async';

import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/settings/sections/data_section.dart';
import 'package:field_notes/features/settings/settings_data_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/settings_harness.dart';

Future<void> _pumpSection(
  WidgetTester tester, {
  required FakeSettingsDataController controller,
  required List<String> messages,
  bool confirmDelete = true,
}) async {
  useWideSurface(tester);
  await tester.pumpWidget(
    settingsFeatureHarness(
      DataSection(
        onFeedback: messages.add,
        confirmDelete: (BuildContext context) async => confirmDelete,
      ),
      overrides: <Override>[
        settingsDataControllerProvider.overrideWith(
          (Ref ref) async => controller,
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the data actions with the right emphasis',
      (WidgetTester tester) async {
    await _pumpSection(
      tester,
      controller: FakeSettingsDataController(),
      messages: <String>[],
    );

    expect(find.text('Data'), findsOneWidget);
    expect(
      tester
          .widget<StickerButton>(
            find.widgetWithText(StickerButton, 'Export…'),
          )
          .variant,
      StickerButtonVariant.secondary,
    );
    expect(
      tester
          .widget<StickerButton>(
            find.widgetWithText(StickerButton, 'Delete all…'),
          )
          .variant,
      StickerButtonVariant.danger,
    );
  });

  testWidgets('exporting reports where the file went',
      (WidgetTester tester) async {
    final List<String> messages = <String>[];
    final FakeSettingsDataController controller = FakeSettingsDataController(
      exportResult: const DataActionSucceeded('Exported to /tmp/a.zip'),
    );
    await _pumpSection(
      tester,
      controller: controller,
      messages: messages,
    );

    await tester.tap(find.text('Export…'));
    await tester.pumpAndSettle();

    expect(controller.exportCalls, 1);
    expect(messages, <String>['Exported to /tmp/a.zip']);
  });

  testWidgets('a dismissed export says nothing', (WidgetTester tester) async {
    final List<String> messages = <String>[];
    await _pumpSection(
      tester,
      controller: FakeSettingsDataController(),
      messages: messages,
    );

    await tester.tap(find.text('Export…'));
    await tester.pumpAndSettle();

    expect(messages, isEmpty);
  });

  testWidgets('a failed export reports the failure',
      (WidgetTester tester) async {
    final List<String> messages = <String>[];
    await _pumpSection(
      tester,
      controller: FakeSettingsDataController(
        exportResult: const DataActionFailed('Export failed.'),
      ),
      messages: messages,
    );

    await tester.tap(find.text('Export…'));
    await tester.pumpAndSettle();

    expect(messages, <String>['Export failed.']);
  });

  testWidgets('delete-all runs only after confirmation',
      (WidgetTester tester) async {
    final List<String> messages = <String>[];
    final FakeSettingsDataController controller = FakeSettingsDataController(
      deleteResult: const DataActionSucceeded('Deleted 1 days and 2 entries.'),
    );
    await _pumpSection(
      tester,
      controller: controller,
      messages: messages,
    );

    await tester.tap(find.text('Delete all…'));
    await tester.pumpAndSettle();

    expect(controller.deleteCalls, 1);
    expect(messages, <String>['Deleted 1 days and 2 entries.']);
  });

  testWidgets('declining the confirmation deletes nothing',
      (WidgetTester tester) async {
    final List<String> messages = <String>[];
    final FakeSettingsDataController controller = FakeSettingsDataController();
    await _pumpSection(
      tester,
      controller: controller,
      messages: messages,
      confirmDelete: false,
    );

    await tester.tap(find.text('Delete all…'));
    await tester.pumpAndSettle();

    expect(controller.deleteCalls, 0);
    expect(messages, isEmpty);
  });

  testWidgets('a second tap while an export is in flight starts nothing new',
      (WidgetTester tester) async {
    final Completer<void> gate = Completer<void>();
    final List<String> messages = <String>[];
    final FakeSettingsDataController controller = FakeSettingsDataController(
      exportResult: const DataActionSucceeded('Exported to /tmp/a.zip'),
      gate: gate,
    );
    await _pumpSection(tester, controller: controller, messages: messages);

    await tester.tap(find.text('Export…'));
    await tester.pump();
    await tester.tap(find.text('Export…'), warnIfMissed: false);
    await tester.pump();

    expect(controller.exportCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();

    expect(controller.exportCalls, 1);
    expect(messages, <String>['Exported to /tmp/a.zip']);
  });

  testWidgets('an export finishing after the page is gone reports nothing',
      (WidgetTester tester) async {
    final Completer<void> gate = Completer<void>();
    final List<String> messages = <String>[];
    final FakeSettingsDataController controller = FakeSettingsDataController(
      exportResult: const DataActionSucceeded('Exported to /tmp/a.zip'),
      gate: gate,
    );
    await _pumpSection(tester, controller: controller, messages: messages);

    await tester.tap(find.text('Export…'));
    await tester.pump();

    await tester.pumpWidget(
      settingsFeatureHarness(
        const SizedBox.shrink(),
        overrides: <Override>[
          settingsDataControllerProvider.overrideWith(
            (Ref ref) async => controller,
          ),
        ],
      ),
    );
    gate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(messages, isEmpty);
  });
}
