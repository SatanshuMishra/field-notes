// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OnboardingController)
final onboardingControllerProvider = OnboardingControllerProvider._();

final class OnboardingControllerProvider
    extends $NotifierProvider<OnboardingController, OnboardingFlow> {
  OnboardingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingControllerHash();

  @$internal
  @override
  OnboardingController create() => OnboardingController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnboardingFlow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnboardingFlow>(value),
    );
  }
}

String _$onboardingControllerHash() =>
    r'3392e8e52e618fb23b810eb51e82833ae16a1be7';

abstract class _$OnboardingController extends $Notifier<OnboardingFlow> {
  OnboardingFlow build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<OnboardingFlow, OnboardingFlow>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<OnboardingFlow, OnboardingFlow>,
              OnboardingFlow,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
