import 'dart:async';
import 'dart:io';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
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
  TargetPlatform? platform,
}) async {
  useWideSurface(tester);
  Widget section = DataSection(
    onFeedback: messages.add,
    confirmDelete: (BuildContext context) async => confirmDelete,
    openLink: openLink,
  );
  if (platform != null) {
    section = Theme(
      data: fieldNotesTheme(platform: platform),
      child: section,
    );
  }
  await tester.pumpWidget(
    settingsFeatureHarness(
      section,
      overrides: <Override>[
        settingsDataControllerProvider.overrideWith(
          (Ref ref) async => controller,
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('desktop data rows sit in your journal and erase groups', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    final FakeSettingsDataController controller = FakeSettingsDataController(
      exportResult: const DataActionSucceeded('Exported to /tmp/a.zip'),
      gate: gate,
    );
    await _pumpSection(
      tester,
      controller: controller,
      messages: <String>[],
      platform: TargetPlatform.macOS,
    );

    final List<String> order = <String>[
      'your journal',
      'Export',
      reclaimSpaceLabel,
      privacyPolicyLabel,
      'erase',
      'Delete all',
    ];
    for (final String text in order) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    final List<double> tops = <double>[
      _top(tester, 'your journal'),
      _top(tester, 'Export'),
      tester.getTopLeft(find.text(reclaimSpaceLabel).first).dy,
      _top(tester, privacyPolicyLabel),
      _top(tester, 'erase'),
      _top(tester, 'Delete all'),
    ];
    for (int index = 1; index < tops.length; index++) {
      expect(tops[index], greaterThan(tops[index - 1]), reason: order[index]);
    }
    expect(find.text('Data'), findsNothing);

    final BuildContext context = tester.element(find.text('erase'));
    expect(
      tester.widget<Text>(find.text('erase')).style!.color!.toARGB32(),
      context.colors.dangerInk.toARGB32(),
    );
    expect(
      tester.widget<Text>(find.text('your journal')).style!.color!.toARGB32(),
      isNot(context.colors.dangerInk.toARGB32()),
    );
    expect(
      tester
          .widget<SettingsActionButton>(
            find.widgetWithText(SettingsActionButton, 'Delete all…'),
          )
          .tone,
      SettingsActionTone.danger,
    );
    expect(
      find.widgetWithText(SettingsActionButton, 'Export…'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(SettingsActionButton, 'Delete all…'),
        matching: find.byType(StickerButton),
      ),
      findsOneWidget,
    );
    expect(find.byType(StickerButton), findsOneWidget);

    await tester.tap(find.text('Export…'));
    await tester.pump();
    expect(
      tester
          .widget<SettingsActionButton>(
            find.widgetWithText(SettingsActionButton, 'Export…'),
          )
          .onPressed,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SettingsActionButton>(
            find.widgetWithText(SettingsActionButton, 'Export…'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('desktop delete-all button goes busy while running', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    final FakeSettingsDataController controller = FakeSettingsDataController(
      deleteResult: const DataActionSucceeded('Deleted.'),
      reclaimResult: const DataActionSucceeded('Reclaimed.'),
      gate: gate,
    );
    await _pumpSection(
      tester,
      controller: controller,
      messages: <String>[],
      platform: TargetPlatform.macOS,
    );

    await tester.tap(find.text('Delete all…'));
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<SettingsActionButton>(
            find.widgetWithText(SettingsActionButton, 'Delete all…'),
          )
          .onPressed,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('phone data rows share one untitled card', (
    WidgetTester tester,
  ) async {
    await _pumpSection(
      tester,
      controller: FakeSettingsDataController(),
      messages: <String>[],
      platform: TargetPlatform.android,
    );

    expect(find.byType(StickerCard), findsOneWidget);
    for (final String label in <String>['Data', 'your journal', 'erase']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    for (final String row in <String>[
      'Export',
      privacyPolicyLabel,
      'Delete all',
    ]) {
      expect(find.text(row), findsOneWidget, reason: row);
    }
    expect(find.text(reclaimSpaceLabel), findsWidgets);
  });

  testWidgets('renders the data actions with the right emphasis', (
    WidgetTester tester,
  ) async {
    await _pumpSection(
      tester,
      controller: FakeSettingsDataController(),
      messages: <String>[],
    );

    expect(find.text('Data'), findsNothing);
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
