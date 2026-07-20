import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/photo_strip.dart';
import 'package:field_notes/features/entry_cards/media/media_image.dart';

import '../support/entry_cards_harness.dart';

void main() {
  group('InlinePhotoStrip', () {
    testWidgets('renders one MediaImage per photo, ordered by sortOrder',
        (WidgetTester tester) async {
      final List<EntryPhoto> photos = <EntryPhoto>[
        photoOf(id: 'b', mediaId: 'm-b', sortOrder: 1),
        photoOf(id: 'a', mediaId: 'm-a', sortOrder: 0),
      ];

      await tester.pumpWidget(
        cardHarness(
          InlinePhotoStrip(photos: photos, resolver: FakeMediaResolver()),
        ),
      );
      await tester.pump();

      final Iterable<MediaImage> images =
          tester.widgetList<MediaImage>(find.byType(MediaImage));
      expect(images.length, 2);
      expect(images.map((MediaImage i) => i.mediaId).toList(),
          <String>['m-a', 'm-b']);
    });

    testWidgets('does not mutate the caller list', (WidgetTester tester) async {
      final List<EntryPhoto> photos = <EntryPhoto>[
        photoOf(id: 'b', mediaId: 'm-b', sortOrder: 1),
        photoOf(id: 'a', mediaId: 'm-a', sortOrder: 0),
      ];

      await tester.pumpWidget(
        cardHarness(
          InlinePhotoStrip(photos: photos, resolver: FakeMediaResolver()),
        ),
      );
      await tester.pump();

      expect(photos.first.id, 'b');
    });
  });
}
