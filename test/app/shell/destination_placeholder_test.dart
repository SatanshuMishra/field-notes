import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/destination_placeholder.dart';
import 'package:field_notes/app/shell/shell_destination.dart';

import '../app_harness.dart';

void main() {
  testWidgets('renders the destination label inside a keyed body',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      appHarness(
        const DestinationPlaceholder(destination: ShellDestination.search),
      ),
    );

    expect(find.text('Search'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<ShellDestination>(ShellDestination.search)),
      findsOneWidget,
    );
  });
}
