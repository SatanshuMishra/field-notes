import 'dart:async';

import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/onboarding_gate.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reminder_coordinator.dart';
import 'reminder_providers.dart';

class ReminderLifecycle extends ConsumerStatefulWidget {
  const ReminderLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ReminderLifecycle> createState() => _ReminderLifecycleState();
}

class _ReminderLifecycleState extends ConsumerState<ReminderLifecycle> {
  late final AppLifecycleListener _lifecycle;
  bool _promptStarted = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _resync);
    ref.listenManual<AsyncValue<ReminderSyncResult?>>(
      reminderSyncProvider,
      (AsyncValue<ReminderSyncResult?>? _, AsyncValue<ReminderSyncResult?> _) {},
    );
    ref.listenManual<AsyncValue<AppSettings>>(
      appSettingsProvider,
      (AsyncValue<AppSettings>? _, AsyncValue<AppSettings> _) =>
          _promptOnFirstLaunch(),
      fireImmediately: true,
    );
    ref.listenManual<AsyncValue<OnboardingVisibility>>(
      onboardingGateProvider,
      (
        AsyncValue<OnboardingVisibility>? _,
        AsyncValue<OnboardingVisibility> _,
      ) => _promptOnFirstLaunch(),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _resync() {
    ref.invalidate(reminderPermissionStatusProvider);
    ref.invalidate(reminderSyncProvider);
  }

  void _promptOnFirstLaunch() {
    final AppSettings? settings = ref.read(appSettingsProvider).value;
    final OnboardingVisibility? onboarding = ref
        .read(onboardingGateProvider)
        .value;
    if (_promptStarted ||
        onboarding != OnboardingVisibility.hidden ||
        settings == null ||
        !settings.reminderEnabled ||
        settings.notificationPermissionAsked) {
      return;
    }
    _promptStarted = true;
    unawaited(
      ref.read(reminderPermissionStatusProvider.notifier).askOnFirstLaunch(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
