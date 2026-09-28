import 'package:field_notes/features/search/search_field.dart';
import 'package:field_notes/features/search/search_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/search_harness.dart';

Widget _probe() {
  return const Column(
    children: <Widget>[
      SearchField(),
      _QueryProbe(),
    ],
  );
}

class _QueryProbe extends ConsumerWidget {
  const _QueryProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text('q=${ref.watch(searchQueryProvider)}');
  }
}

void main() {
  testWidgets('typing updates the search query provider',
      (WidgetTester tester) async {
    await tester.pumpWidget(searchHarness(_probe()));

    await tester.enterText(find.byType(TextField), 'rain');
    await tester.pump();

    expect(find.text('q=rain'), findsOneWidget);
  });

  testWidgets('clear button resets the query',
      (WidgetTester tester) async {
    await tester.pumpWidget(searchHarness(_probe()));

    await tester.enterText(find.byType(TextField), 'rain');
    await tester.pump();
    expect(find.text('q=rain'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('q='), findsOneWidget);
  });

  testWidgets('the search field keeps its name after typing', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(searchHarness(_probe()));

    await tester.enterText(find.byType(TextField), 'rain');
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byType(EditableText)).label,
      'Search your days',
    );
    semantics.dispose();
  });

  testWidgets('the clear button is labelled Clear search', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(searchHarness(_probe()));

    await tester.enterText(find.byType(TextField), 'rain');
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Clear search'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Clear search')).tooltip,
      isEmpty,
    );
    semantics.dispose();
  });
}
