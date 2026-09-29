import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/onboarding_surface.dart';
import 'package:field_notes/features/onboarding/setup/setup_reminder_step.dart';
import 'package:field_notes/features/onboarding/setup/setup_storage_step.dart';
import 'package:field_notes/features/onboarding/setup/setup_week_step.dart';
import 'package:field_notes/features/onboarding/welcome/onboarding_welcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/theme_harness.dart';

const Size _desktop = Size(1280, 800);
const Size _phone = Size(360, 740);

const ReminderTime _evening = ReminderTime(hour: 20, minute: 30);

Future<void> _pumpDark(
  WidgetTester tester,
  ShellLayout layout,
  Widget child,
) async {
  final bool sidebar = layout == ShellLayout.sidebar;
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpThemed(
    tester,
    child,
    brightness: Brightness.dark,
    platform: sidebar ? TargetPlatform.macOS : TargetPlatform.android,
    size: sidebar ? _desktop : _phone,
  );
  await tester.pumpAndSettle();
}

BoxDecoration _fillWithin(WidgetTester tester, Key key) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byKey(key),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

TextStyle _styleWithin(WidgetTester tester, Key key, String text) => tester
    .widget<Text>(
      find.descendant(of: find.byKey(key), matching: find.text(text)),
    )
    .style!;

SetupReminderStep _reminderStep(ShellLayout layout) => SetupReminderStep(
  layout: layout,
  enabled: true,
  preset: ReminderPreset.evening,
  time: _evening,
  onEnabledChanged: (bool value) {},
  onPresetChanged: (ReminderPreset preset) {},
  onTimeChanged: (ReminderTime time) {},
);

void main() {
  test('onboarding names no light-only colour', () {
    expect(lightOnlyTokenUses(<String>['lib/features/onboarding']), isEmpty);
  });

  testWidgets('welcome card draws its dark colours', (
    WidgetTester tester,
  ) async {
    await _pumpDark(
      tester,
      ShellLayout.sidebar,
      OnboardingWelcome(
        layout: ShellLayout.sidebar,
        onBegin: () {},
        onSkip: () {},
      ),
    );

    final BoxDecoration card =
        tester.widget<Container>(find.byKey(onboardingCardKey)).decoration!
            as BoxDecoration;
    expect(card.color, const Color(0xFF2B241C));
    expect(card.border, Border.all(color: const Color(0xFF9D8870), width: 2));
    expect(
      card.boxShadow!.first,
      const BoxShadow(color: Color(0x59000000), offset: Offset(5, 5)),
    );

    expect(
      tester.widget<Text>(find.text('field notes')).style!.color,
      const Color(0xFFE8927A),
    );

    for (final String number in <String>['1', '2']) {
      final BoxDecoration badge =
          tester
                  .widget<DecoratedBox>(
                    find
                        .ancestor(
                          of: find.text(number),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(badge.shape, BoxShape.circle, reason: number);
      expect(badge.color, const Color(0xFF3D3229), reason: number);
      expect(
        tester.widget<Text>(find.text(number)).style!.color,
        const Color(0xFFFBF3E4),
        reason: number,
      );
    }
  });

  testWidgets('setup options and reminder preview draw their dark colours', (
    WidgetTester tester,
  ) async {
    await _pumpDark(
      tester,
      ShellLayout.sidebar,
      SetupWeekStep(
        layout: ShellLayout.sidebar,
        suggestion: WeekStart.monday,
        selected: WeekStart.sunday,
        onChanged: (WeekStart start) {},
      ),
    );
    expect(
      _fillWithin(tester, setupWeekOptionKey(WeekStart.monday)).color,
      const Color(0xFF29221B),
    );
    expect(
      _fillWithin(tester, setupWeekOptionKey(WeekStart.sunday)).color,
      const Color(0xFF342A20),
    );

    await _pumpDark(
      tester,
      ShellLayout.sidebar,
      const SetupStorageStep(layout: ShellLayout.sidebar),
    );
    expect(
      _fillWithin(tester, setupStorageServerKey).color,
      const Color(0xFF29221B),
    );
    expect(
      _fillWithin(tester, setupStorageDeviceKey).color,
      const Color(0xFF342A20),
    );

    await _pumpDark(
      tester,
      ShellLayout.sidebar,
      _reminderStep(ShellLayout.sidebar),
    );
    expect(
      _fillWithin(tester, setupNotificationPreviewKey).color,
      const Color(0xF2211B16),
    );

    await _pumpDark(
      tester,
      ShellLayout.bottomBar,
      _reminderStep(ShellLayout.bottomBar),
    );
    for (final String header in <String>['Field Notes', '20:30']) {
      expect(
        _styleWithin(tester, setupNotificationPreviewKey, header).color,
        const Color(0xFFB09C80),
        reason: header,
      );
    }
    expect(
      _styleWithin(
        tester,
        setupNotificationPreviewKey,
        'You haven’t written today’s field note yet.',
      ).color,
      const Color(0xFFC4B39A),
    );
  });

  testWidgets('phone onboarding page draws its dark gradient', (
    WidgetTester tester,
  ) async {
    await _pumpDark(
      tester,
      ShellLayout.bottomBar,
      const OnboardingSurface(
        layout: ShellLayout.bottomBar,
        child: SizedBox.expand(),
      ),
    );

    final BoxDecoration page =
        tester.widget<DecoratedBox>(find.byKey(onboardingPageKey)).decoration
            as BoxDecoration;
    expect((page.gradient! as LinearGradient).colors, const <Color>[
      Color(0xFF2D261E),
      Color(0xFF2E261F),
    ]);
  });
}
