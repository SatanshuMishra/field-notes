import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/search/search_day_tile.dart';
import 'package:field_notes/features/search/search_entries_provider.dart';
import 'package:field_notes/features/search/search_field.dart';
import 'package:field_notes/features/search/search_screen.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/search_harness.dart';

const double _ringReach = 5;

const double _screenPadding = 16;

void main() {
  testWidgets(
    'a focused result card shows its whole ring and keeps its place',
    (WidgetTester tester) async {
      final FocusHighlightStrategy previous =
          FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = previous);
      await tester.pumpWidget(
        searchHarness(
          const SearchScreen(),
          overrides: <Override>[
            allDaysProvider.overrideWith(
              (_) => Stream<List<Day>>.value(<Day>[
                dayOf('2026-07-15', id: 'd1', mood: Mood.happy),
                dayOf('2026-07-14', id: 'd2', mood: Mood.calm),
              ]),
            ),
            searchAllEntriesProvider.overrideWith(
              (_) => Stream<List<Entry>>.value(const <Entry>[]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final Rect screen = tester.getRect(find.byType(SearchScreen));
      final Rect card = tester.getRect(find.byType(SearchDayTile).first);
      expect(card.left - screen.left, _screenPadding);
      expect(screen.right - card.right, _screenPadding);
      final Rect field = tester.getRect(find.byType(SearchField));
      expect(field.left - screen.left, _screenPadding);
      expect(screen.right - field.right, _screenPadding);
      expect(card.top - field.bottom, _screenPadding);

      for (int press = 0; press < 12; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        if (FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<SearchDayTile>() !=
            null) {
          break;
        }
      }
      final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
      expect(
        focused?.findAncestorWidgetOfExactType<SearchDayTile>(),
        isNotNull,
        reason: 'Tab never reached a result card',
      );

      final Rect list = tester.getRect(find.byType(ListView));
      final Rect ring = tester
          .getRect(find.byType(SearchDayTile).first)
          .inflate(_ringReach);
      expect(tester.getRect(find.byType(SearchDayTile).first), card);
      expect(list.left, lessThanOrEqualTo(ring.left));
      expect(list.right, greaterThanOrEqualTo(ring.right));
      expect(list.top, lessThanOrEqualTo(ring.top));
      expect(list.bottom, greaterThanOrEqualTo(ring.bottom));
    },
  );
}
