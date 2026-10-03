import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/icons/flame_icon.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpPill(
  WidgetTester tester, {
  required int streak,
  required Widget pill,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        streakSummaryProvider.overrideWithValue(
          StreakSummary(current: streak, longest: streak),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.android),
        home: Scaffold(
          body: Center(child: SizedBox(width: 176, child: pill)),
        ),
      ),
    ),
  );
}

BoxDecoration _pillDecoration(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(StreakPill),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((DecoratedBox box) => box.decoration)
    .whereType<BoxDecoration>()
    .first;

String _tooltip(WidgetTester tester) => tester
    .widget<Tooltip>(
      find.descendant(
        of: find.byType(StreakPill),
        matching: find.byType(Tooltip),
      ),
    )
    .message!;

void main() {
  testWidgets('the streak pill reads N days and announces N days in a row', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await _pumpPill(tester, streak: 12, pill: const StreakPill());
    expect(find.text('12 days'), findsOneWidget);
    expect(find.byType(FlameIcon), findsOneWidget);
    expect(find.bySemanticsLabel('12 days in a row'), findsOneWidget);
    expect(_tooltip(tester), '12 days in a row');
    expect(tester.getSize(find.byType(StreakPill)).height, 30);
    final FieldNotesColors colors = FieldNotesColors.light;
    expect(
      _pillDecoration(tester).color!.toARGB32(),
      colors.cardLight.toARGB32(),
    );

    await _pumpPill(tester, streak: 1, pill: const StreakPill());
    expect(find.text('1 day'), findsOneWidget);
    expect(find.text('1 days'), findsNothing);
    expect(find.bySemanticsLabel('1 day in a row'), findsOneWidget);
    expect(_tooltip(tester), '1 day in a row');

    await _pumpPill(
      tester,
      streak: 12,
      pill: const StreakPill(form: StreakPillForm.sidebar),
    );
    expect(find.text('12 days'), findsOneWidget);
    final Rect sidebarFlame = tester.getRect(find.byType(FlameIcon));
    final Rect sidebarText = tester.getRect(find.text('12 days'));
    expect(sidebarText.left, greaterThan(sidebarFlame.right));
    expect((sidebarText.center.dy - sidebarFlame.center.dy).abs(), lessThan(4));
    expect(find.bySemanticsLabel('12 days in a row'), findsOneWidget);

    await _pumpPill(
      tester,
      streak: 12,
      pill: const StreakPill(form: StreakPillForm.rail),
    );
    expect(find.text('12'), findsOneWidget);
    expect(find.text('12 days'), findsNothing);
    final Rect railFlame = tester.getRect(find.byType(FlameIcon));
    final Rect railText = tester.getRect(find.text('12'));
    expect(railText.top, greaterThanOrEqualTo(railFlame.bottom));
    expect((railText.center.dx - railFlame.center.dx).abs(), lessThan(0.5));
    expect(find.bySemanticsLabel('12 days in a row'), findsOneWidget);
    expect(_tooltip(tester), '12 days in a row');

    await _pumpPill(
      tester,
      streak: 12,
      pill: const StreakPill(count: 4, numberOnly: true),
    );
    expect(find.text('4'), findsOneWidget);
    expect(find.text('12 days'), findsNothing);
    expect(find.bySemanticsLabel('4 days in a row'), findsOneWidget);
    expect(
      _pillDecoration(tester).color!.toARGB32(),
      isNot(Palette.coral.toARGB32()),
    );

    await _pumpPill(
      tester,
      streak: 12,
      pill: const StreakPill(count: 4, numberOnly: true, highlighted: true),
    );
    expect(find.text('4'), findsOneWidget);
    final BoxDecoration highlighted = _pillDecoration(tester);
    expect(highlighted.color!.toARGB32(), Palette.coral.toARGB32());
    expect(
      tester.widget<Text>(find.text('4')).style!.color!.toARGB32(),
      Palette.onAccent.toARGB32(),
    );
    expect(
      tester.widget<FlameIcon>(find.byType(FlameIcon)).color.toARGB32(),
      Palette.onAccent.toARGB32(),
    );
    expect(
      highlighted.boxShadow!.any(
        (BoxShadow shadow) =>
            shadow.spreadRadius == 4 &&
            shadow.color.toARGB32() ==
                Palette.coral.withValues(alpha: 0.25).toARGB32(),
      ),
      isTrue,
    );

    handle.dispose();
  });
}
