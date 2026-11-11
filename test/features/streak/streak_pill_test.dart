import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/icons/flame_icon.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../day_detail/support/day_detail_harness.dart';

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

const List<StreakDay> _weekendThenMonday = <StreakDay>[
  StreakDay(date: '2026-11-07', hasBloom: true, logCount: 1),
  StreakDay(date: '2026-11-08', hasBloom: true, logCount: 2),
  StreakDay(date: '2026-11-09', hasBloom: false, logCount: 1),
];

final DateTime _oneAm = DateTime(2026, 11, 10, 1);
final DateTime _justAfterFour = DateTime(2026, 11, 10, 4, 1);
const String _mondayHeading = 'Monday, November 9';
const String _lateLine = 'late night · until 4 AM';

Future<void> _pumpLive(
  WidgetTester tester, {
  required DateTime now,
  StreakPillForm form = StreakPillForm.sidebar,
  double? width = 152,
}) async {
  final Widget pill = StreakPill(form: form);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        streakClockProvider.overrideWithValue(() => now),
        streakDaysProvider.overrideWith(
          (Ref ref) => Stream<List<StreakDay>>.value(_weekendThenMonday),
        ),
        journalRepositoryProvider.overrideWithValue(FakeJournalRepository()),
        dayDetailMediaResolverProvider.overrideWith(
          (Ref ref) => FakeMediaResolver(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: defaultTargetPlatform),
        home: Scaffold(
          body: Center(
            child: width == null ? pill : SizedBox(width: width, child: pill),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _onMac(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

int _argb(Color color) => color.toARGB32();

Color _flameColour(WidgetTester tester) =>
    tester.widget<FlameIcon>(find.byType(FlameIcon)).color;

Color _textColour(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.color!;

BoxDecoration _faceDecoration(WidgetTester tester) =>
    tester.widget<DecoratedBox>(find.byKey(streakPillFaceKey)).decoration
        as BoxDecoration;

Color _dashColour(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(StreakPill),
        matching: find.byType(CustomPaint),
      ),
    )
    .map((CustomPaint paint) => paint.foregroundPainter)
    .whereType<DashedBorderPainter>()
    .single
    .color;

BoxDecoration _moonDecoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(
                of: find.byKey(streakMoonBadgeKey),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

const Duration _tipFadeIn = Duration(milliseconds: 200);

final Finder _openMondayLink = find.widgetWithText(Pressable, 'Open Monday');

Future<void> _showTip(WidgetTester tester) async {
  tester
      .state<TooltipState>(
        find.descendant(
          of: find.byType(StreakPill),
          matching: find.byType(Tooltip),
        ),
      )
      .ensureTooltipVisible();
  await tester.pump();
  await tester.pump(_tipFadeIn);
}

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

  testWidgets(
    'at 1 AM with Monday unfinished the pill turns sage and holds the run',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      const FieldNotesColors colors = FieldNotesColors.light;

      await _pumpLive(tester, now: _oneAm);

      expect(find.text('2 days'), findsOneWidget);
      expect(find.text(_lateLine), findsOneWidget);
      expect(find.byKey(streakMoonBadgeKey), findsOneWidget);
      expect(_argb(_flameColour(tester)), _argb(colors.lateNight));
      expect(_argb(_flameColour(tester)), isNot(_argb(colors.accentInk)));
      expect(_argb(_textColour(tester, '2 days')), _argb(colors.lateNight));
      expect(_argb(_textColour(tester, _lateLine)), _argb(colors.lateNight));
      final RenderParagraph lateLine = tester.renderObject(
        find.text(_lateLine),
      );
      expect(
        lateLine.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(lateLine.size.width),
      );
      expect(_faceDecoration(tester).border, isNull);
      expect(_argb(_dashColour(tester)), _argb(colors.lateNight));

      final Rect face = tester.getRect(find.byKey(streakPillFaceKey));
      final Rect badge = tester.getRect(find.byKey(streakMoonBadgeKey));
      expect(badge.size, const Size(18, 18));
      expect(badge.right, face.right + 6);
      expect(badge.top, face.top - 6);
      final BoxDecoration ring = _moonDecoration(tester);
      expect(_argb(ring.color!), _argb(colors.page));
      expect(_argb(ring.border!.top.color), _argb(colors.lateNight));
      expect(ring.border!.top.width, 1.5);

      expect(
        find.bySemanticsLabel('2 days in a row, late night until 4 AM'),
        findsOneWidget,
      );

      await _showTip(tester);
      expect(
        find.textContaining(
          'Monday still counts until 4 AM\n'
          'Add a log and pick its bloom to keep your run going.\n',
        ),
        findsOneWidget,
      );
      expect(_openMondayLink, findsOneWidget);
      final TextStyle link = tester
          .widget<Text>(find.text('Open Monday'))
          .style!;
      expect(_argb(link.color!), _argb(FieldNotesColors.light.accentInkStrong));
      expect(link.decoration, TextDecoration.underline);
      expect(
        tester.getSemantics(_openMondayLink),
        isSemantics(
          label: 'Open Monday',
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );

      handle.dispose();
    },
  );

  testWidgets(
    'over the Garden scene in light mode the late-night pill stays pale sage',
    (WidgetTester tester) async {
      const Color paleSage = Color(0xFFA9C2A9);

      await _pumpLive(
        tester,
        now: _oneAm,
        form: StreakPillForm.headerOverScene,
        width: null,
      );

      expect(
        Theme.of(tester.element(find.byType(StreakPill))).brightness,
        Brightness.light,
      );
      expect(find.text('2 days'), findsOneWidget);
      expect(_argb(_dashColour(tester)), _argb(paleSage));
      expect(_argb(_flameColour(tester)), _argb(paleSage));
      expect(_argb(_textColour(tester, '2 days')), _argb(paleSage));
      final BoxDecoration moon = _moonDecoration(tester);
      expect(_argb(moon.color!), _argb(FieldNotesColors.dark.page));
      expect(_argb(moon.border!.top.color), _argb(paleSage));
    },
  );

  testWidgets('at 4:01 AM the pill is back in its accent form', (
    WidgetTester tester,
  ) async {
    const FieldNotesColors colors = FieldNotesColors.light;

    await _pumpLive(tester, now: _justAfterFour);

    expect(find.text('0 days'), findsOneWidget);
    expect(find.text(_lateLine), findsNothing);
    expect(find.byKey(streakMoonBadgeKey), findsNothing);
    expect(_argb(_flameColour(tester)), _argb(colors.accentInk));
    expect(_argb(_textColour(tester, '0 days')), _argb(colors.accentInk));
    expect(_faceDecoration(tester).border, isNotNull);
    expect(_tooltip(tester), '0 days in a row');
  });

  testWidgets('the tooltip link and the pill itself open Monday', (
    WidgetTester tester,
  ) async {
    await _onMac(() async {
      await _pumpLive(tester, now: _oneAm);

      await _showTip(tester);
      await tester.tap(_openMondayLink);
      await tester.pumpAndSettle();
      expect(find.text(_mondayHeading), findsOneWidget);

      Navigator.of(tester.element(find.text(_mondayHeading))).pop();
      await tester.pumpAndSettle();
      expect(find.text(_mondayHeading), findsNothing);

      await _showTip(tester);
      Focus.of(tester.element(find.text('Open Monday'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text(_mondayHeading), findsOneWidget);

      Navigator.of(tester.element(find.text(_mondayHeading))).pop();
      await tester.pumpAndSettle();
      expect(find.text(_mondayHeading), findsNothing);

      await tester.tap(find.byType(StreakPill));
      await tester.pumpAndSettle();
      expect(find.text(_mondayHeading), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('on a phone the late-night pill offers Monday in a sheet', (
    WidgetTester tester,
  ) async {
    const FieldNotesColors colors = FieldNotesColors.light;

    await _pumpLive(
      tester,
      now: _oneAm,
      form: StreakPillForm.header,
      width: null,
    );

    expect(find.byKey(streakMoonBadgeKey), findsOneWidget);
    expect(_argb(_flameColour(tester)), _argb(colors.lateNight));
    expect(_argb(_textColour(tester, '2 days')), _argb(colors.lateNight));
    expect(_faceDecoration(tester).border, isNull);

    await tester.tap(find.byType(StreakPill));
    await tester.pumpAndSettle();

    expect(find.text('Monday still counts until 4 AM'), findsOneWidget);
    expect(
      find.text('Add a log and pick its bloom to keep your run going.'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(streakLateNightOpenKey),
        matching: find.text('Open Monday'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(streakLateNightOpenKey));
    await tester.pumpAndSettle();

    expect(find.text('Monday still counts until 4 AM'), findsNothing);
    expect(find.text(_mondayHeading), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the rail pill is 44 wide and 56 tall, late at night or not', (
    WidgetTester tester,
  ) async {
    const FieldNotesColors colors = FieldNotesColors.light;

    for (final DateTime now in <DateTime>[_justAfterFour, _oneAm]) {
      await _pumpLive(tester, now: now, form: StreakPillForm.rail, width: null);

      expect(tester.getSize(find.byType(StreakPill)), const Size(44, 56));
      final Rect face = tester.getRect(find.byKey(streakPillFaceKey));
      final Rect flame = tester.getRect(find.byType(FlameIcon));
      final Rect count = tester.getRect(find.byType(Text));
      expect(face.size, const Size(44, 56));
      expect(count.top, greaterThanOrEqualTo(flame.bottom));
      expect((count.center.dx - flame.center.dx).abs(), lessThan(0.5));
      expect(flame.top - face.top, inInclusiveRange(10, 14));
      expect(face.bottom - count.bottom, inInclusiveRange(10, 14));
    }

    expect(find.text('2'), findsOneWidget);
    expect(find.byKey(streakMoonBadgeKey), findsOneWidget);
    expect(_argb(_flameColour(tester)), _argb(colors.lateNight));
    expect(_argb(_textColour(tester, '2')), _argb(colors.lateNight));

    await _pumpPill(
      tester,
      streak: 12,
      pill: const StreakPill(form: StreakPillForm.rail),
    );
    expect(tester.getSize(find.byKey(streakPillFaceKey)), const Size(44, 56));
  });
}
