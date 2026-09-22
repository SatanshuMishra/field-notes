// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(settingsController)
final settingsControllerProvider = SettingsControllerProvider._();

final class SettingsControllerProvider
    extends
        $FunctionalProvider<
          SettingsController,
          SettingsController,
          SettingsController
        >
    with $Provider<SettingsController> {
  SettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsControllerHash();

  @$internal
  @override
  $ProviderElement<SettingsController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SettingsController create(Ref ref) {
    return settingsController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsController>(value),
    );
  }
}

String _$settingsControllerHash() =>
    r'5d94ee532f876243fdd455b60499e0981bf5fcca';

@ProviderFor(settingsDataController)
final settingsDataControllerProvider = SettingsDataControllerProvider._();

final class SettingsDataControllerProvider
    extends
        $FunctionalProvider<
          AsyncValue<SettingsDataController>,
          SettingsDataController,
          FutureOr<SettingsDataController>
        >
    with
        $FutureModifier<SettingsDataController>,
        $FutureProvider<SettingsDataController> {
  SettingsDataControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsDataControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsDataControllerHash();

  @$internal
  @override
  $FutureProviderElement<SettingsDataController> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SettingsDataController> create(Ref ref) {
    return settingsDataController(ref);
  }
}

String _$settingsDataControllerHash() =>
    r'7041cccd430e73237314bdcacd7532fef23067f3';
