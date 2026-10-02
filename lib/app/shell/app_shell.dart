import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/motion/petal_drift.dart';
import 'package:field_notes/domain/models/day.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/reminders/reminder_lifecycle.dart';
import 'package:field_notes/features/settings/settings_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/sound/sound_providers.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:field_notes/features/today/today.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/shell_navigation.dart';

import 'appearance_toggle.dart';
import 'bottom_bar_shell.dart';
import 'shell_content.dart';
import 'shell_destination.dart';
import 'shell_layout.dart';
import 'sidebar_shell.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.onCapturePressed, this.onSoundPressed});

  final VoidCallback? onCapturePressed;
  final VoidCallback? onSoundPressed;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  void _select(ShellDestination destination) {
    ref.read(shellNavigationProvider.notifier).select(destination);
  }

  void _onBottomBarPop(bool didPop, Object? result) {
    if (!didPop) {
      ref.read(shellNavigationProvider.notifier).back();
    }
  }

  Future<void> _openCapture() async {
    await openCapture(context, ref, date: ref.read(todayDateProvider));
  }

  Future<void> _toggleSound() async {
    final bool next = !ref.read(soundEnabledProvider);
    final SettingsWriteResult result = await ref
        .read(settingsControllerProvider)
        .setSoundEnabled(next);
    if (result is SettingsWriteFailed) {
      debugPrint('Sound toggle failed: ${result.message}');
    }
  }

  FlowerKind? _todayFlower() {
    final String today = ref.watch(todayDateProvider);
    return ref.watch(
      dayForDateProvider(today)
          .select((AsyncValue<Day?> day) => day.value?.mood?.flower),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ShellLayout layout = resolveShellLayout(Theme.of(context).platform);
    final ShellDestination selected = ref.watch(shellNavigationProvider);
    final VoidCallback onCapture = widget.onCapturePressed ?? _openCapture;
    final VoidCallback onSound = widget.onSoundPressed ?? _toggleSound;
    final bool obscured =
        ref.watch(onboardingControllerProvider) is! OnboardingFlowHidden;
    final FlowerKind? flower = _todayFlower();
    final Widget body = ShellContent(destination: selected);
    final Widget shell = switch (layout) {
      ShellLayout.sidebar => SidebarShell(
        destinations: ShellDestination.primary,
        selected: selected,
        onSelect: _select,
        onSound: onSound,
        soundOn: ref.watch(soundEnabledProvider),
        streak: const StreakCard(),
        body: body,
        obscured: obscured,
        appearanceToggle: const AppearanceToggle(),
      ),
      ShellLayout.bottomBar => PopScope<Object?>(
        canPop: obscured || selected == ShellDestination.today,
        onPopInvokedWithResult: obscured ? null : _onBottomBarPop,
        child: BottomBarShell(
          destinations: ShellDestination.primary,
          selected: selected,
          onSelect: _select,
          onCapture: onCapture,
          body: body,
          obscured: obscured,
          appearanceToggle: const AppearanceToggle(),
        ),
      ),
    };

    return ReminderLifecycle(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          shell,
          if (!obscured && selected != ShellDestination.garden)
            IgnorePointer(
              child: ExcludeFocus(child: PetalDrift(flower: flower)),
            ),
        ],
      ),
    );
  }
}
