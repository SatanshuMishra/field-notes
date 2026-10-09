import 'dart:async';
import 'dart:io';

import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/settings/sections/data_section.dart';
import 'package:field_notes/features/settings/settings_data_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/settings_harness.dart';

Future<bool> _neverOpened(Uri link) async =>
    throw StateError('No link should open: $link');

Future<void> _pumpSection(
  WidgetTester tester, {
  required FakeSettingsDataController controller,
  required List<String> messages,
  bool confirmDelete = true,
  LinkOpener openLink = _neverOpened,
}) async {
  useWideSurface(tester);
  await tester.pumpWidget(
    settingsFeatureHarness(
      DataSection(
        onFeedback: messages.add,
        confirmDelete: (BuildContext context) async => confirmDelete,
        openLink: openLink,
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
  testWidgets('renders the data actions with the right emphasis', (
    WidgetTester tester,
  ) async {
    await _pumpSection(
      tester,
      controller: FakeSettingsDataController(),
      messages: <String>[],
    );

    expect(find.text('Data'), findsOneWidget);
    expect(
      tester
          .widget<StickerButton>(find.widgetWithText(StickerButton, 'Export…'))
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

  testWidgets('exporting reports where the file went', (
    WidgetTester tester,
  ) async {
    final List<String> messages = <String>[];
    final FakeSettingsDataController controller = FakeSettingsDataController(
      exportResult: const DataActionSucceeded('Exported to /tmp/a.zip'),
    );
    await _pumpSection(tester, controller: controller, messages: messages);

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

  testWidgets('a failed export reports the failure', (
    WidgetTester tester,
  ) async {
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

  testWidgets('delete-all runs only after confirmation', (
    WidgetTester tester,
  ) async {
    final List<String> messages = <String>[];
    final FakeSettingsDataController controller = FakeSettingsDataController(
      deleteResult: const DataActionSucceeded('Deleted 1 day and 2 entries.'),
    );
    await _pumpSection(tester, controller: controller, messages: messages);

    await tester.tap(find.text('Delete all…'));
    await tester.pumpAndSettle();

    expect(controller.deleteCalls, 1);
    expect(messages, <String>['Deleted 1 day and 2 entries.']);
  });

  testWidgets('declining the confirmation deletes nothing', (
    WidgetTester tester,
  ) async {
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

  testWidgets('a second tap while an export is in flight starts nothing new', (
    WidgetTester tester,
  ) async {
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

  testWidgets('an export finishing after the page is gone reports nothing', (
    WidgetTester tester,
  ) async {
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

  testWidgets('offers a manual Reclaim space action', (
    WidgetTester tester,
  ) async {
    await _pumpSection(
      tester,
      controller: FakeSettingsDataController(),
      messages: <String>[],
    );

    expect(find.text(reclaimSpaceLabel), findsWidgets);
    expect(
      tester
          .widget<StickerButton>(
            find.widgetWithText(StickerButton, reclaimSpaceLabel),
          )
          .variant,
      StickerButtonVariant.secondary,
    );
  });

  testWidgets('tapping Reclaim space sweeps once and reports the result', (
    WidgetTester tester,
  ) async {
    final List<String> messages = <String>[];
    final FakeSettingsDataController controller = FakeSettingsDataController(
      reclaimResult: const DataActionSucceeded('Reclaimed 2 unused files.'),
    );
    await _pumpSection(tester, controller: controller, messages: messages);

    await tester.tap(find.widgetWithText(StickerButton, reclaimSpaceLabel));
    await tester.pumpAndSettle();

    expect(controller.reclaimCalls, 1);
    expect(messages, <String>['Reclaimed 2 unused files.']);
  });

  testWidgets('a failed sweep reports the failure', (
    WidgetTester tester,
  ) async {
    final List<String> messages = <String>[];
    await _pumpSection(
      tester,
      controller: FakeSettingsDataController(
        reclaimResult: const DataActionFailed(reclaimSpaceFailedMessage),
      ),
      messages: messages,
    );

    await tester.tap(find.widgetWithText(StickerButton, reclaimSpaceLabel));
    await tester.pumpAndSettle();

    expect(messages, <String>[reclaimSpaceFailedMessage]);
  });

  testWidgets('a second tap while a sweep is in flight starts nothing new', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    final List<String> messages = <String>[];
    final FakeSettingsDataController controller = FakeSettingsDataController(
      reclaimResult: const DataActionSucceeded('Reclaimed 2 unused files.'),
      gate: gate,
    );
    await _pumpSection(tester, controller: controller, messages: messages);

    await tester.tap(find.widgetWithText(StickerButton, reclaimSpaceLabel));
    await tester.pump();
    expect(
      tester
          .widget<StickerButton>(
            find.widgetWithText(StickerButton, reclaimSpaceLabel),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.widgetWithText(StickerButton, reclaimSpaceLabel),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(controller.reclaimCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();

    expect(controller.reclaimCalls, 1);
    expect(messages, <String>['Reclaimed 2 unused files.']);
  });

  testWidgets('a sweep never runs without a tap', (WidgetTester tester) async {
    final FakeSettingsDataController controller = FakeSettingsDataController();
    await _pumpSection(tester, controller: controller, messages: <String>[]);

    expect(controller.reclaimCalls, 0);
  });

  testWidgets('the privacy policy opens in the browser', (
    WidgetTester tester,
  ) async {
    final List<String> messages = <String>[];
    final List<Uri> opened = <Uri>[];
    await _pumpSection(
      tester,
      controller: FakeSettingsDataController(),
      messages: messages,
      openLink: (Uri link) async {
        opened.add(link);
        return true;
      },
    );

    expect(find.text(privacyPolicyLabel), findsOneWidget);
    final Finder open = find.widgetWithText(
      StickerButton,
      privacyPolicyOpenLabel,
    );
    expect(
      tester.widget<StickerButton>(open).variant,
      StickerButtonVariant.secondary,
    );

    await tester.tap(open);
    await tester.pumpAndSettle();

    expect(opened, <Uri>[privacyPolicyLink]);
    expect(messages, isEmpty);
    expect(privacyPolicyLink.scheme, 'https');
    expect(privacyPolicyLink.path, endsWith('/main/docs/privacy.md'));
    expect(File('docs/privacy.md').existsSync(), isTrue);
  });

  testWidgets('a privacy policy that will not open says where to find it', (
    WidgetTester tester,
  ) async {
    for (final LinkOpener failing in <LinkOpener>[
      (Uri link) async => false,
      (Uri link) async => throw PlatformException(code: 'ACTIVITY_NOT_FOUND'),
    ]) {
      final List<String> messages = <String>[];
      await _pumpSection(
        tester,
        controller: FakeSettingsDataController(),
        messages: messages,
        openLink: failing,
      );

      await tester.tap(
        find.widgetWithText(StickerButton, privacyPolicyOpenLabel),
      );
      await tester.pumpAndSettle();

      expect(messages, <String>[privacyPolicyFailedMessage]);
      expect(privacyPolicyFailedMessage, contains(privacyPolicyLink.host));
    }
  });
}
