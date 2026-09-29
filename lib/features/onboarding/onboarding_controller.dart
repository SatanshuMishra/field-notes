import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/features/onboarding/setup/onboarding_setup.dart';
import 'package:field_notes/features/onboarding/tour/onboarding_tour.dart';
import 'package:field_notes/features/onboarding/tour/tour_tips.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_controller.g.dart';

sealed class OnboardingFlow {
  const OnboardingFlow();
}

final class OnboardingFlowHidden extends OnboardingFlow {
  const OnboardingFlowHidden();
}

final class OnboardingFlowWelcome extends OnboardingFlow {
  const OnboardingFlowWelcome();
}

final class OnboardingFlowAppearance extends OnboardingFlow {
  const OnboardingFlowAppearance({required this.skippedTips});

  final bool skippedTips;

  @override
  bool operator ==(Object other) =>
      other is OnboardingFlowAppearance && other.skippedTips == skippedTips;

  @override
  int get hashCode => skippedTips.hashCode;
}

final class OnboardingFlowTour extends OnboardingFlow {
  const OnboardingFlowTour({required this.tip, required this.mode});

  final int tip;
  final TourMode mode;

  @override
  bool operator ==(Object other) =>
      other is OnboardingFlowTour && other.tip == tip && other.mode == mode;

  @override
  int get hashCode => Object.hash(tip, mode);
}

final class OnboardingFlowSetup extends OnboardingFlow {
  const OnboardingFlowSetup({this.skippedTips = false});

  final bool skippedTips;

  @override
  bool operator ==(Object other) =>
      other is OnboardingFlowSetup && other.skippedTips == skippedTips;

  @override
  int get hashCode => skippedTips.hashCode;
}

@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  @override
  OnboardingFlow build() => const OnboardingFlowHidden();

  void start() => state = const OnboardingFlowWelcome();

  void begin() => state = const OnboardingFlowAppearance(skippedTips: false);

  void skipFromWelcome() =>
      state = const OnboardingFlowAppearance(skippedTips: true);

  void continueFromAppearance() => state = switch (state) {
    OnboardingFlowAppearance(skippedTips: true) => const OnboardingFlowSetup(
      skippedTips: true,
    ),
    _ => const OnboardingFlowTour(tip: 0, mode: TourMode.firstRun),
  };

  void backFromAppearance() => state = const OnboardingFlowWelcome();

  void skipTour() => _leaveTour();

  void finishTour() => _leaveTour();

  void backFromTour() {
    if (_replaying) {
      return;
    }
    state = const OnboardingFlowAppearance(skippedTips: false);
  }

  void backFromSetup() => state = switch (state) {
    OnboardingFlowSetup(skippedTips: true) => const OnboardingFlowAppearance(
      skippedTips: true,
    ),
    _ => OnboardingFlowTour(tip: tourTips.length - 1, mode: TourMode.firstRun),
  };

  void finishSetup(SetupOutcome outcome) =>
      state = const OnboardingFlowHidden();

  void replayTour() {
    ref.read(shellNavigationProvider.notifier).select(ShellDestination.today);
    state = const OnboardingFlowTour(tip: 0, mode: TourMode.replay);
  }

  bool get _replaying => switch (state) {
    OnboardingFlowTour(mode: TourMode.replay) => true,
    _ => false,
  };

  void _leaveTour() {
    state = _replaying
        ? const OnboardingFlowHidden()
        : const OnboardingFlowSetup();
  }
}
