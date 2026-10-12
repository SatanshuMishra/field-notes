// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UpdateGreeting)
final updateGreetingProvider = UpdateGreetingProvider._();

final class UpdateGreetingProvider
    extends $NotifierProvider<UpdateGreeting, String?> {
  UpdateGreetingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateGreetingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateGreetingHash();

  @$internal
  @override
  UpdateGreeting create() => UpdateGreeting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$updateGreetingHash() => r'962a3cb4cc8e8906c40567654abe5fedae988179';

abstract class _$UpdateGreeting extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(UpdateController)
final updateControllerProvider = UpdateControllerProvider._();

final class UpdateControllerProvider
    extends $NotifierProvider<UpdateController, UpdateStatus> {
  UpdateControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateControllerHash();

  @$internal
  @override
  UpdateController create() => UpdateController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateStatus>(value),
    );
  }
}

String _$updateControllerHash() => r'0eaef21c300e6d50c492e5f0ea349601eaf92756';

abstract class _$UpdateController extends $Notifier<UpdateStatus> {
  UpdateStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UpdateStatus, UpdateStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UpdateStatus, UpdateStatus>,
              UpdateStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
