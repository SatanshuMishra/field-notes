import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the fast-forward clock shows the date', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Text(
            gardenClockLabel(
              context,
              SkyMoment(
                instant: DateTime(2026, 10, 7, 21, 7),
                offset: const Duration(days: 8),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Wed Oct 7'), findsOneWidget);
  });
}
