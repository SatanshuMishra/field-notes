import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/day_detail/day_detail_header.dart';

import 'support/day_detail_harness.dart';

final DateTime _today = DateTime(2026, 7, 23, 9);

void main() {
  testWidgets('renders the kicker, the day title and a back button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      dayDetailHarness(
        DayDetailHeader(date: '2026-07-19', today: _today, onClose: () {}),
      ),
    );

    expect(find.text('a day in the garden'), findsOneWidget);
    expect(find.text('Sunday, July 19'), findsOneWidget);
    expect(find.text('2026'), findsNothing);
    expect(find.text('Close'), findsNothing);
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(tester.getSize(find.byKey(dayDetailBackKey)), const Size(34, 34));
  });

  testWidgets('today reads as today in your garden', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      dayDetailHarness(
        DayDetailHeader(date: '2026-07-23', today: _today, onClose: () {}),
      ),
    );

    expect(find.text('today · in your garden'), findsOneWidget);
    expect(find.text('Thursday, July 23'), findsOneWidget);
  });

  testWidgets('tapping the back button invokes the callback', (
    WidgetTester tester,
  ) async {
    int closes = 0;
    await tester.pumpWidget(
      dayDetailHarness(
        DayDetailHeader(
          date: '2026-07-19',
          today: _today,
          onClose: () => closes++,
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pump();

    expect(closes, 1);
  });

  testWidgets(
    'the sheet header has no back button and wraps a long title in full',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        dayDetailHarness(
          SizedBox(
            width: 160,
            child: DayDetailSheetHeader(date: '2026-07-15', today: _today),
          ),
        ),
      );

      expect(find.text('a day in the garden'), findsOneWidget);
      expect(find.byKey(dayDetailBackKey), findsNothing);
      final Finder title = find.text('Wednesday, July 15');
      expect(tester.widget<Text>(title).style!.fontSize, 22);
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        title,
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 18),
            )
            .map((TextBox box) => box.top)
            .toSet()
            .length,
        greaterThan(1),
      );
      expect(tester.getSize(title).width, lessThanOrEqualTo(160 - 2 * 18));
    },
  );

  testWidgets(
    'the pop-up header ends with Earlier day and Later day chevrons',
    (WidgetTester tester) async {
      int earlier = 0;
      int later = 0;
      await tester.pumpWidget(
        dayDetailHarness(
          SizedBox(
            width: 371,
            child: DayDetailHeader(
              date: '2026-07-19',
              today: _today,
              onClose: () {},
              onEarlier: () => earlier++,
              onLater: () => later++,
            ),
          ),
        ),
      );

      expect(find.byTooltip('Earlier day'), findsOneWidget);
      expect(find.byTooltip('Later day'), findsOneWidget);
      expect(find.bySemanticsLabel('Earlier day'), findsOneWidget);
      expect(find.bySemanticsLabel('Later day'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(dayDetailEarlierDayKey)),
        const Size(34, 34),
      );
      expect(
        tester.getSize(find.byKey(dayDetailLaterDayKey)),
        const Size(34, 34),
      );
      final Rect back = tester.getRect(find.byKey(dayDetailBackKey));
      final Rect earlierFace = tester.getRect(
        find.byKey(dayDetailEarlierDayKey),
      );
      final Rect laterFace = tester.getRect(find.byKey(dayDetailLaterDayKey));
      expect(earlierFace.left, greaterThan(back.right));
      expect(laterFace.left, greaterThan(earlierFace.right));
      expect(laterFace.top, back.top);
      expect(earlierFace.top, back.top);

      await tester.tap(find.byTooltip('Earlier day'));
      await tester.pump();
      await tester.tap(find.byTooltip('Later day'));
      await tester.pump();

      expect(earlier, 1);
      expect(later, 1);
    },
  );

  testWidgets('the sheet header steps days with the same chevrons', (
    WidgetTester tester,
  ) async {
    int earlier = 0;
    int later = 0;
    await tester.pumpWidget(
      dayDetailHarness(
        SizedBox(
          width: 384,
          child: DayDetailSheetHeader(
            date: '2026-07-15',
            today: _today,
            onEarlier: () => earlier++,
            onLater: () => later++,
          ),
        ),
      ),
    );

    expect(find.byKey(dayDetailBackKey), findsNothing);
    expect(find.byTooltip('Earlier day'), findsOneWidget);
    expect(find.byTooltip('Later day'), findsOneWidget);

    await tester.tap(find.byTooltip('Earlier day'));
    await tester.pump();
    await tester.tap(find.byTooltip('Later day'));
    await tester.pump();

    expect(earlier, 1);
    expect(later, 1);
  });

  testWidgets('a missing callback disables its chevron', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    int earlier = 0;
    await tester.pumpWidget(
      dayDetailHarness(
        SizedBox(
          width: 371,
          child: DayDetailHeader(
            date: '2026-07-23',
            today: _today,
            onClose: () {},
            onEarlier: () => earlier++,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Later day'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Later day')),
      isSemantics(
        label: 'Later day',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Earlier day')),
      isSemantics(
        label: 'Earlier day',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byTooltip('Later day'));
    await tester.pump();

    expect(earlier, 0);
    handle.dispose();
  });
}
