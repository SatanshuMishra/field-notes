import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/main.dart';

void main() {
  testWidgets('renders Field Notes home', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FieldNotesApp()));

    expect(find.text('Field Notes'), findsWidgets);
  });
}
