import 'dart:async';

import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/feedback/toast.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/onboarding_frame.dart';
import 'package:field_notes/features/onboarding/onboarding_gate.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _finishedToast = 'Your meadow starts today.';

class OnboardingHost extends ConsumerStatefulWidget {
  const OnboardingHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OnboardingHost> createState() => _OnboardingHostState();
}

class _OnboardingHostState extends ConsumerState<OnboardingHost> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<OnboardingVisibility>>(
      onboardingGateProvider,
      (
        AsyncValue<OnboardingVisibility>? _,
        AsyncValue<OnboardingVisibility> gate,
      ) => _onGate(gate),
      fireImmediately: true,
    );
    ref.listenManual<OnboardingFlow>(
      onboardingControllerProvider,
      (OnboardingFlow? previous, OnboardingFlow flow) =>
          _onFlow(previous, flow),
    );
  }

  OnboardingController get _controller =>
      ref.read(onboardingControllerProvider.notifier);

  void _onGate(AsyncValue<OnboardingVisibility> gate) {
    if (_started || gate.value != OnboardingVisibility.shown) {
      return;
    }
    _started = true;
    scheduleMicrotask(_start);
  }

  void _start() {
    if (!mounted) {
      return;
    }
    ref.read(shellNavigationProvider.notifier).select(ShellDestination.today);
    _controller.start();
  }

  void _onFlow(OnboardingFlow? previous, OnboardingFlow flow) {
    if (previous is! OnboardingFlowRunning ||
        flow is! OnboardingFlowHidden ||
        !mounted) {
      return;
    }
    ref.read(shellNavigationProvider.notifier).select(ShellDestination.today);
    showTransientToast(context, _finishedToast);
  }

  void _onPop(bool didPop, Object? result) {
    if (didPop ||
        ref.read(onboardingControllerProvider) is OnboardingFlowHidden) {
      return;
    }
    _controller.back();
  }

  @override
  Widget build(BuildContext context) {
    final ShellLayout layout = resolveShellLayout(Theme.of(context).platform);
    final bool showing =
        ref.watch(onboardingControllerProvider) is! OnboardingFlowHidden;
    return PopScope<Object?>(
      canPop: !showing,
      onPopInvokedWithResult: _onPop,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          if (showing)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: switch (layout) {
                ShellLayout.sidebar => shellTitleBarHeight,
                ShellLayout.bottomBar => 0,
              },
              child: OnboardingFrame(layout: layout),
            ),
        ],
      ),
    );
  }
}
