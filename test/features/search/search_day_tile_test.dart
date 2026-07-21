import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/search/search_day_tile.dart';
import 'package:field_notes/features/search/search_day_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/search_harness.dart';

void main() {
  testWidgets('renders flower, date, preview, count and fires onTap',
      (WidgetTester tester) async {
    bool tapped = false;
    const SearchDayView view = SearchDayView(
      date: '2026-07-15',
      mood: Mood.happy,
      entryCount: 2,
      preview: 'Rainy morning walk',
      searchText: 'rainy morning walk',
    );

    await tester.pumpWidget(
      searchHarness(SearchDayTile(view: view, onTap: () => tapped = true)),
    );

    expect(find.byType(FlowerBloom), findsOneWidget);
    expect(find.textContaining('July 15'), findsOneWidget);
    expect(find.text('Rainy morning walk'), findsOneWidget);
    expect(find.text('2 entries'), findsOneWidget);

    await tester.tap(find.byType(SearchDayTile));
    expect(tapped, isTrue);
  });

  testWidgets('moodless day shows a placeholder, not a flower',
      (WidgetTester tester) async {
    const SearchDayView view = SearchDayView(
      date: '2026-07-14',
      mood: null,
      entryCount: 0,
      preview: '',
      searchText: '2026-07-14',
    );

    await tester.pumpWidget(
      searchHarness(SearchDayTile(view: view, onTap: () {})),
    );

    expect(find.byType(FlowerBloom), findsNothing);
    expect(find.text('No entries yet'), findsOneWidget);
    expect(find.text('0 entries'), findsOneWidget);
  });

  testWidgets('uses the singular label for a single entry',
      (WidgetTester tester) async {
    const SearchDayView view = SearchDayView(
      date: '2026-07-13',
      mood: Mood.calm,
      entryCount: 1,
      preview: 'One thing',
      searchText: 'one thing',
    );

    await tester.pumpWidget(
      searchHarness(SearchDayTile(view: view, onTap: () {})),
    );

    expect(find.text('1 entry'), findsOneWidget);
  });
}
