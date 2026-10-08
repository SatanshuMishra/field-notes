import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/settings/widgets/delete_all_dialog.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';

final TargetPlatformVariant _bothPlatforms = TargetPlatformVariant(
  <TargetPlatform>{TargetPlatform.macOS, TargetPlatform.android},
);

Future<void> _openDialog(WidgetTester tester, List<bool> outcomes) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              outcomes.add(await confirmDeleteAll(context));
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.byType(DeleteAllConfirmDialog), findsOneWidget);
  expect(outcomes, isEmpty);
}

Future<void> _openSyncDialog(
  WidgetTester tester,
  List<bool> outcomes, {
  Size surface = const Size(900, 1400),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: syncOnOverrides(status: SyncedStatus(DateTime.now().toUtc())),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                outcomes.add(await confirmDeleteAll(context));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

bool _deleteEverywhereEnabled(WidgetTester tester) {
  final Finder key = find.byKey(deleteEverywhereKey);
  final Widget button = tester.widget(key);
  if (button is StickerButton) {
    return button.onPressed != null;
  }
  return tester
          .widget<SyncFlowButton>(
            find.ancestor(of: key, matching: find.byType(SyncFlowButton)),
          )
          .action
          .onPressed !=
      null;
}

Finder _confirmField() => find
    .descendant(
      of: find
          .ancestor(
            of: find.text(deleteEverywhereConfirmLabel),
            matching: find.byType(SyncFlowField),
          )
          .first,
      matching: find.byType(EditableText),
    )
    .first;

void main() {
  testWidgets('cancelling resolves to false', (WidgetTester tester) async {
    final List<bool> outcomes = <bool>[];
    await _openDialog(tester, outcomes);

    expect(
      find.text(
        'This erases every entry, photo, and mood on this device. '
        'It cannot be undone.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Keep my journal'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAllConfirmDialog), findsNothing);
    expect(outcomes, <bool>[false]);
  });

  testWidgets('dismissing the barrier resolves to false', (
    WidgetTester tester,
  ) async {
    final List<bool> outcomes = <bool>[];
    await _openDialog(tester, outcomes);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAllConfirmDialog), findsNothing);
    expect(outcomes, <bool>[false]);
  });

  testWidgets('confirming resolves to true', (WidgetTester tester) async {
    final List<bool> outcomes = <bool>[];
    await _openDialog(tester, outcomes);

    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAllConfirmDialog), findsNothing);
    expect(outcomes, <bool>[true]);
  });

  testWidgets('with sync on the dialog offers both delete actions', (
    WidgetTester tester,
  ) async {
    final List<bool> outcomes = <bool>[];
    await _openSyncDialog(tester, outcomes);

    expect(find.byType(DeleteAllConfirmDialog), findsNothing);
    expect(find.byType(SyncDeleteAllDialog), findsOneWidget);
    expect(find.text('Delete your journal'), findsOneWidget);
    expect(find.text(removeFromThisDeviceMessage), findsOneWidget);
    expect(find.text(deleteJournalEverywhereMessage), findsOneWidget);
    expect(find.text(deleteEverywhereConfirmLabel), findsOneWidget);
    expect(find.byKey(removeFromThisDeviceKey), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byKey(deleteEverywhereKey), findsOneWidget);
    expect(_deleteEverywhereEnabled(tester), isFalse);

    await tester.tap(find.byKey(deleteEverywhereKey));
    await tester.pumpAndSettle();
    expect(find.byType(SyncDeleteAllDialog), findsOneWidget);

    await tester.enterText(_confirmField(), 'delet');
    await tester.pump();
    expect(_deleteEverywhereEnabled(tester), isFalse);

    await tester.enterText(_confirmField(), 'delete');
    await tester.pump();
    expect(_deleteEverywhereEnabled(tester), isTrue);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(SyncDeleteAllDialog), findsNothing);
    expect(outcomes, <bool>[false]);
  }, variant: _bothPlatforms);

  testWidgets('on the phone the delete journal sheet keeps its field and '
      'buttons above the keyboard', (WidgetTester tester) async {
    const Size phone = Size(384, 832);
    const double keyboard = 300;
    final List<bool> outcomes = <bool>[];
    await _openSyncDialog(tester, outcomes, surface: phone);
    expect(find.byType(SyncDeleteAllDialog), findsOneWidget);

    await tester.tap(_confirmField());
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();

    final double above = phone.height - keyboard;
    final Rect footer = tester.getRect(find.byKey(phoneSheetFooterKey));
    expect(footer.bottom, above);
    for (final Finder button in <Finder>[
      find.byKey(removeFromThisDeviceKey),
      find.text('Cancel'),
      find.byKey(deleteEverywhereKey),
    ]) {
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(above));
    }
    final Rect field = tester.getRect(_confirmField());
    expect(field.bottom, lessThanOrEqualTo(footer.top));
    expect(
      field.top,
      greaterThanOrEqualTo(tester.getRect(find.byType(PhoneSheet)).top),
    );

    await tester.enterText(_confirmField(), 'delete');
    await tester.pump();
    expect(_deleteEverywhereEnabled(tester), isTrue);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
