import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/search/search_day_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/search_harness.dart';

void main() {
  group('buildSearchDayViews', () {
    test('emits one view per day, preserving the given day order', () {
      final List<SearchDayView> views = buildSearchDayViews(
        <Day>[dayOf('2026-07-15', id: 'd1'), dayOf('2026-07-14', id: 'd2')],
        const <Entry>[],
      );

      expect(views.map((SearchDayView v) => v.date).toList(),
          <String>['2026-07-15', '2026-07-14']);
    });

    test('counts only that day\'s entries', () {
      final List<SearchDayView> views = buildSearchDayViews(
        <Day>[dayOf('2026-07-15', id: 'd1'), dayOf('2026-07-14', id: 'd2')],
        <Entry>[
          entryOf(dayId: 'd1', id: 'e1', textContent: 'a'),
          entryOf(dayId: 'd1', id: 'e2', textContent: 'b'),
          entryOf(dayId: 'd2', id: 'e3', textContent: 'c'),
        ],
      );

      expect(views[0].entryCount, 2);
      expect(views[1].entryCount, 1);
    });

    test('preview is the first line of the earliest text entry', () {
      final List<SearchDayView> views = buildSearchDayViews(
        <Day>[dayOf('2026-07-15', id: 'd1')],
        <Entry>[
          entryOf(
            dayId: 'd1',
            id: 'late',
            textContent: 'written later',
            createdAt: 200,
          ),
          entryOf(
            dayId: 'd1',
            id: 'early',
            textContent: '  Rainy morning walk\nsecond line  ',
            createdAt: 100,
          ),
        ],
      );

      expect(views.single.preview, 'Rainy morning walk');
    });

    test('preview falls back to a type label when no entry has text', () {
      final List<SearchDayView> views = buildSearchDayViews(
        <Day>[dayOf('2026-07-15', id: 'd1')],
        <Entry>[entryOf(dayId: 'd1', id: 'v', type: EntryType.voice)],
      );

      expect(views.single.preview, 'Voice recording');
    });

    test('preview is empty for a day with no entries', () {
      final List<SearchDayView> views = buildSearchDayViews(
        <Day>[dayOf('2026-07-15', id: 'd1')],
        const <Entry>[],
      );

      expect(views.single.preview, '');
    });

    test('searchText lowercases date, mood label and every entry text', () {
      final List<SearchDayView> views = buildSearchDayViews(
        <Day>[dayOf('2026-07-15', id: 'd1', mood: Mood.happy)],
        <Entry>[
          entryOf(dayId: 'd1', id: 'e1', textContent: 'First NOTE'),
          entryOf(dayId: 'd1', id: 'e2', textContent: 'Second Thing'),
        ],
      );

      final String haystack = views.single.searchText;
      expect(haystack.contains('2026-07-15'), isTrue);
      expect(haystack.contains('happy'), isTrue);
      expect(haystack.contains('first note'), isTrue);
      expect(haystack.contains('second thing'), isTrue);
    });

    test('preview of a heading-first note is the projected prose', () {
      final List<SearchDayView> views = buildSearchDayViews(
        <Day>[dayOf('2026-07-15', id: 'd1')],
        <Entry>[
          entryOf(
            dayId: 'd1',
            id: 'e1',
            textContent: '# **Rainy** morning\n\nsecond paragraph',
          ),
        ],
      );

      expect(views.single.preview, 'Rainy morning');
    });

    test('preview of a photo-first note skips to the first projected text',
        () {
      final List<SearchDayView> views = buildSearchDayViews(
        <Day>[dayOf('2026-07-15', id: 'd1')],
        <Entry>[
          entryOf(
            dayId: 'd1',
            id: 'e1',
            textContent:
                '![](photo/0123456789ab "right medium")\n\n- *first* item',
          ),
        ],
      );

      expect(views.single.preview, 'first item');
    });

    test('preview of a photo with a caption is the caption', () {
      final List<SearchDayView> views = buildSearchDayViews(
        <Day>[dayOf('2026-07-15', id: 'd1')],
        <Entry>[
          entryOf(
            dayId: 'd1',
            id: 'e1',
            textContent: '![the harbour](photo/0123456789ab)\n\nlater',
          ),
        ],
      );

      expect(views.single.preview, 'the harbour');
    });

    test('a note that projects to nothing falls through to the next entry',
        () {
      final List<SearchDayView> views = buildSearchDayViews(
        <Day>[dayOf('2026-07-15', id: 'd1')],
        <Entry>[
          entryOf(dayId: 'd1', id: 'e1', textContent: '---', createdAt: 100),
          entryOf(dayId: 'd1', id: 'e2', textContent: 'walk', createdAt: 200),
        ],
      );

      expect(views.single.preview, 'walk');
    });

    test('searchText matches Markdown prose but not its syntax', () {
      final List<SearchDayView> views = buildSearchDayViews(
        <Day>[dayOf('2026-07-15', id: 'd1')],
        <Entry>[
          entryOf(
            dayId: 'd1',
            id: 'e1',
            textContent: '## Harbour\n\n**Salt** air and `gulls`\n\n'
                '![boats](photo/0123456789ab "left small")\n\n[tide](https://t)',
          ),
        ],
      );

      final String haystack = views.single.searchText;
      expect(haystack.contains('harbour'), isTrue);
      expect(haystack.contains('salt air and gulls'), isTrue);
      expect(haystack.contains('boats'), isTrue);
      expect(haystack.contains('tide'), isTrue);
      expect(haystack.contains('#'), isFalse);
      expect(haystack.contains('**'), isFalse);
      expect(haystack.contains('`'), isFalse);
      expect(haystack.contains('photo/'), isFalse);
      expect(haystack.contains('0123456789ab'), isFalse);
      expect(haystack.contains('https://t'), isFalse);
      expect(haystack.contains('['), isFalse);
    });

    test('does not mutate the input entries list', () {
      final List<Entry> entries = <Entry>[
        entryOf(dayId: 'd1', id: 'b', textContent: 'b', createdAt: 200),
        entryOf(dayId: 'd1', id: 'a', textContent: 'a', createdAt: 100),
      ];

      buildSearchDayViews(<Day>[dayOf('2026-07-15', id: 'd1')], entries);

      expect(entries.map((Entry e) => e.id).toList(), <String>['b', 'a']);
    });
  });
}
