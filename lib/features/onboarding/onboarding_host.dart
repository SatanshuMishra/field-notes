import 'dart:async';

import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/features/onboarding/appearance/onboarding_appearance.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/onboarding_gate.dart';
import 'package:field_notes/features/onboarding/setup/onboarding_setup.dart';
import 'package:field_notes/features/onboarding/tour/onboarding_tour.dart';
import 'package:field_notes/features/onboarding/welcome/onboarding_welcome.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _finishedToast = 'All set. Plant your first bloom.';
const String _skippedToast = 'Defaults applied · change them in Settings';

const KeyDownEvent _backKey = KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.arrowLeft,
  logicalKey: LogicalKeyboardKey.arrowLeft,
  timeStamp: Duration.zero,
);

class OnboardingHost extends ConsumerStatefulWidget {
  const OnboardingHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OnboardingHost> createState() => _OnboardingHostState();
}

class _OnboardingHostState extends ConsumerState<OnboardingHost> {
  final FocusNode _surfaceFocus = FocusNode(
    debugLabel: 'onboarding-surface',
    canRequestFocus: false,
    skipTraversal: true,
  );
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
  }

  @override
  void dispose() {
    _surfaceFocus.dispose();
    super.dispose();
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

  Future<void> _finishSetup(SetupOutcome outcome) async {
    try {
      await ref.read(onboardingGateProvider.notifier).complete();
    } catch (error) {
      debugPrint('Could not record that onboarding finished: $error');
    }
    if (!mounted) {
      return;
    }
    _controller.finishSetup(outcome);
    showTransientToast(context, switch (outcome) {
      SetupOutcome.finished => _finishedToast,
      SetupOutcome.skipped => _skippedToast,
    });
  }

  void _onPop(bool didPop, Object? result) {
    if (didPop ||
        ref.read(onboardingControllerProvider) is OnboardingFlowHidden) {
      return;
    }
    final FocusNode? focused = FocusManager.instance.primaryFocus;
    if (focused == null || !focused.ancestors.contains(_surfaceFocus)) {
      return;
    }
    for (final FocusNode node in <FocusNode>[focused, ...focused.ancestors]) {
      if (identical(node, _surfaceFocus)) {
        return;
      }
      final KeyEventResult handled =
          node.onKeyEvent?.call(node, _backKey) ?? KeyEventResult.ignored;
      if (handled != KeyEventResult.ignored) {
        return;
      }
    }
  }

  Widget? _surface(OnboardingFlow flow, ShellLayout layout) {
    final OnboardingController controller = _controller;
    return switch (flow) {
      OnboardingFlowHidden() => null,
      OnboardingFlowWelcome() => OnboardingWelcome(
        layout: layout,
        onBegin: controller.begin,
        onSkip: controller.skipFromWelcome,
      ),
      OnboardingFlowAppearance() => OnboardingAppearance(
        layout: layout,
        onContinue: controller.continueFromAppearance,
        onBack: controller.backFromAppearance,
      ),
      final OnboardingFlowTour tour => OnboardingTour(
        key: ValueKey<OnboardingFlowTour>(tour),
        layout: layout,
        mode: tour.mode,
        initialTip: tour.tip,
        onBackOut: controller.backFromTour,
        onFinish: controller.finishTour,
        onSkip: controller.skipTour,
      ),
      OnboardingFlowSetup() => OnboardingSetup(
        layout: layout,
        onBackOut: controller.backFromSetup,
        onDone: _finishSetup,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final ShellLayout layout = resolveShellLayout(Theme.of(context).platform);
    final Widget? surface = _surface(
      ref.watch(onboardingControllerProvider),
      layout,
    );
    final bool showing = surface != null;
    return PopScope<Object?>(
      canPop: !showing,
      onPopInvokedWithResult: _onPop,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ExcludeFocus(
            excluding: showing,
            child: AbsorbPointer(absorbing: showing, child: widget.child),
          ),
          if (surface != null)
            Focus(
              focusNode: _surfaceFocus,
              child: Material(type: MaterialType.transparency, child: surface),
            ),
        ],
      ),
    );
  }
}
