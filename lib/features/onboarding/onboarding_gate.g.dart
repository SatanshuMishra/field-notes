// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_gate.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OnboardingGate)
final onboardingGateProvider = OnboardingGateProvider._();

final class OnboardingGateProvider
    extends $AsyncNotifierProvider<OnboardingGate, OnboardingVisibility> {
  OnboardingGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingGateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingGateHash();

  @$internal
  @override
  OnboardingGate create() => OnboardingGate();
}

String _$onboardingGateHash() => r'fea2906b50c35fb4d19aa2c3f19558cf2940d1c8';

abstract class _$OnboardingGate extends $AsyncNotifier<OnboardingVisibility> {
  FutureOr<OnboardingVisibility> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<OnboardingVisibility>, OnboardingVisibility>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<OnboardingVisibility>,
                OnboardingVisibility
              >,
              AsyncValue<OnboardingVisibility>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
