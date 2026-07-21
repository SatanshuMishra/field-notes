import 'package:field_notes/features/settings/widgets/delete_all_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openDialog(
  WidgetTester tester,
  List<bool> outcomes,
) async {
  await tester.pumpWidget(
    MaterialApp(
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

void main() {
  testWidgets('cancelling resolves to false', (WidgetTester tester) async {
    final List<bool> outcomes = <bool>[];
    await _openDialog(tester, outcomes);

    expect(
      find.text('This erases every entry, photo, and mood on this device. '
          'It cannot be undone.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Keep my journal'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAllConfirmDialog), findsNothing);
    expect(outcomes, <bool>[false]);
  });

  testWidgets('dismissing the barrier resolves to false',
      (WidgetTester tester) async {
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
}
