import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/domain/services/streak_service.dart';
import 'package:field_notes/features/mood/mood_banner.dart';
import 'package:field_notes/features/mood/mood_prompt_border.dart';
import 'package:field_notes/features/streak/streak_card.dart';
import 'package:field_notes/features/streak/streak_providers.dart';
import 'package:field_notes/features/today/today_header.dart';

import '../../support/theme_harness.dart';

const Color _panelTop = Color(0xFF1E1914);
const Color _panelBottom = Color(0xFF191511);
const Color _titleBar = Color(0xFF241E19);
const Color _windowTitle = Color(0xFF8A7560);
const Color _coral = Color(0xFFC76A54);
const Color _line = Color(0xFF9D8870);
const Color _shadow = Color(0xFF070504);
const Color _cardLight = Color(0xFF342A20);
const Color _cardWarm = Color(0xFF29221B);
const Color _accentInk = Color(0xFFE8927A);
const Color _ink = Color(0xFFEFE3CE);

const String _windowTitleCopy = 'field notes — a journal of days';
const String _moodQuestion = 'How are you feeling today?';

Future<void> _pumpDark(
  WidgetTester tester,
  Widget child, {
  TargetPlatform? platform,
  Size? size,
}) => pumpThemed(
  tester,
  child,
  brightness: Brightness.dark,
  platform: platform,
  size: size,
);

List<BoxDecoration> _decorationsIn(WidgetTester tester, Finder owner) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: owner, matching: find.byType(DecoratedBox)),
    )
    .map((DecoratedBox box) => box.decoration)
    .whereType<BoxDecoration>()
    .toList();

Color? _textColour(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  test('shell, Today, mood and streak name no light-only colour', () {
    expect(
      lightOnlyTokenUses(<String>[
        'lib/app/shell',
        'lib/features/today',
        'lib/features/streak',
        'lib/features/mood',
      ]),
      isEmpty,
    );
  });

  testWidgets('sidebar and active navigation draw their dark colours', (
    WidgetTester tester,
  ) async {
    await _pumpDark(
      tester,
      SidebarShell(
        destinations: ShellDestination.primary,
        selected: ShellDestination.today,
        onSelect: (_) {},
        onSound: () {},
        streak: const SizedBox.shrink(),
        body: const SizedBox.shrink(),
      ),
      platform: TargetPlatform.macOS,
      size: const Size(1280, 900),
    );

    final LinearGradient wash =
        _decorationsIn(tester, find.byType(SidebarShell))
            .map((BoxDecoration decoration) => decoration.gradient)
            .whereType<LinearGradient>()
            .single;
    expect(wash.colors, <Color>[_panelTop, _panelBottom]);

    final Container titleBar = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(windowTitleBarKey),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((titleBar.decoration! as BoxDecoration).color, _titleBar);
    expect(_textColour(tester, _windowTitleCopy), _windowTitle);

    final BoxDecoration active = _decorationsIn(
      tester,
      find.byKey(const ValueKey<String>('rail-today')),
    ).singleWhere((BoxDecoration decoration) => decoration.color != null);
    expect(active.color, _coral);
    expect((active.border! as Border).top.color, _line);
    expect(active.boxShadow!.single.color, _shadow);
    expect(active.boxShadow!.single.offset, const Offset(2, 2));
  });

  testWidgets('streak card and Today header draw their dark colours', (
    WidgetTester tester,
  ) async {
    await _pumpDark(
      tester,
      ProviderScope(
        overrides: [
          streakSummaryProvider.overrideWithValue(
            const StreakSummary(current: 3, longest: 5),
          ),
        ],
        child: const StreakCard(),
      ),
    );

    final BoxDecoration card = _decorationsIn(
      tester,
      find.byKey(const ValueKey<String>('streak-card')),
    ).first;
    expect(card.color, _cardLight);
    expect(_textColour(tester, '3 days'), _accentInk);

    await _pumpDark(
      tester,
      const TodayHeader(
        greeting: 'Good evening',
        longDate: 'Sunday, July 19, 2026',
      ),
    );

    expect(_textColour(tester, 'Good evening'), _accentInk);
    expect(_textColour(tester, 'Sunday, July 19, 2026'), _ink);
  });

  testWidgets('mood prompt card draws its dark colours', (
    WidgetTester tester,
  ) async {
    await _pumpDark(tester, MoodBanner(mood: null, onChangeMood: () {}));

    final MoodPromptBorderPainter prompt = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((CustomPaint paint) => paint.painter)
        .whereType<MoodPromptBorderPainter>()
        .single;
    expect(prompt.fill, _cardWarm);
    expect(prompt.color, _line);
    expect(_textColour(tester, _moodQuestion), _ink);
  });
}
