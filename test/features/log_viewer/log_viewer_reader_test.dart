import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/notes/notes.dart';

import '../entry_cards/support/entry_cards_harness.dart';
import '../notes/support/notes_harness.dart'
    show availablePhoto, photoIdA, photoIdB, photoLine, prefixOf;

void main() {
  group('view mode note photos', () {
    const double phoneMeasure = 320;

    FakeMediaResolver photoResolver() {
      return FakeMediaResolver()
        ..set(prefixOf(photoIdA), availablePhoto(photoIdA))
        ..set(prefixOf(photoIdB), availablePhoto(photoIdB, width: 900, height: 1600));
    }

    Future<void> pumpNote(
      WidgetTester tester,
      String text, {
      MediaResolver? resolver,
    }) async {
      await tester.pumpWidget(
        cardHarness(
          SingleChildScrollView(
            child: NoteMediaScope(
              resolver: resolver ?? photoResolver(),
              child: NoteBody(text: text),
            ),
          ),
          width: phoneMeasure,
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
        'a photo line renders as one centred block image at each size '
        'fraction, four distinct widths at a 320pt measure',
        (WidgetTester tester) async {
      final List<double> widths = <double>[];
      for (final PhotoSize size in PhotoSize.values) {
        await pumpNote(tester, 'before\n${photoLine(photoIdA, size: size)}\nafter');

        final double measure = tester.getSize(find.byType(NoteDocument)).width;
        final Finder frame = find.byKey(notePhotoFrameKey);
        expect(measure, phoneMeasure);
        expect(frame, findsOneWidget);
        expect(
          tester.getSize(frame).width,
          closeTo(size.measureFraction * measure, 0.01),
          reason: size.name,
        );
        expect(
          tester.getCenter(frame).dx,
          closeTo(tester.getCenter(find.byType(NoteDocument)).dx, 0.01),
        );
        widths.add(tester.getSize(frame).width);
      }

      expect(widths.toSet(), hasLength(4));
    });

    testWidgets('the block keeps the photo aspect and clamps a tall portrait',
        (WidgetTester tester) async {
      await pumpNote(
        tester,
        '${photoLine(photoIdA, size: PhotoSize.full)}\n'
        '${photoLine(photoIdB, size: PhotoSize.full)}',
      );

      final List<Size> frames = tester
          .widgetList<SizedBox>(find.byKey(notePhotoFrameKey))
          .map((SizedBox box) => Size(box.width!, box.height!))
          .toList();
      expect(frames[0].height, closeTo(phoneMeasure / 1.5, 0.01));
      expect(frames[1].height, closeTo(1.6 * phoneMeasure, 0.01));
    });

    testWidgets('renders the photo inline and nowhere else',
        (WidgetTester tester) async {
      await pumpNote(tester, 'before\n${photoLine(photoIdA)}\nafter');

      expect(find.byType(StackedPhoto), findsOneWidget);
      expect(find.byType(MediaImage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StackedPhoto),
          matching: find.byType(MediaImage),
        ),
        findsOneWidget,
      );
      expect(find.text('before'), findsOneWidget);
      expect(find.text('after'), findsOneWidget);
    });

    testWidgets('the alt slot is the caption and the screen-reader label',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpNote(tester, photoLine(photoIdA, caption: 'the porch at dusk'));

      expect(find.text('the porch at dusk'), findsOneWidget);
      expect(
        find.bySemanticsLabel('the porch at dusk'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('an unresolvable reference renders the unavailable chip',
        (WidgetTester tester) async {
      await pumpNote(
        tester,
        'before\n![](photo/0123456789ab "right medium")\nafter',
      );

      expect(find.byKey(notePhotoUnavailableKey), findsOneWidget);
      expect(find.text(notePhotoUnavailableLabel), findsOneWidget);
      expect(find.byKey(notePhotoFrameKey), findsNothing);
      expect(find.text('after'), findsOneWidget);
    });

    testWidgets('an unavailable photo still announces its caption',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpNote(
        tester,
        '![the porch at dusk](photo/0123456789ab "right medium")',
      );

      expect(find.byKey(notePhotoUnavailableKey), findsOneWidget);
      expect(find.bySemanticsLabel('the porch at dusk'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a pending resolve holds the planned box instead of jumping',
        (WidgetTester tester) async {
      await pumpNote(
        tester,
        photoLine(photoIdA, size: PhotoSize.large),
        resolver: const _NeverResolver(),
      );

      expect(
        tester.getSize(find.byKey(notePhotoFrameKey)),
        Size(0.92 * phoneMeasure, 0.92 * phoneMeasure / photoFallbackAspect),
      );
    });
  });
}

class _NeverResolver implements MediaResolver {
  const _NeverResolver();

  @override
  ResolvedMedia? resolved(String? mediaId) => null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) =>
      Completer<ResolvedMedia>().future;
}
