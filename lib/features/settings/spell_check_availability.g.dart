// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spell_check_availability.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(spellCheckAvailabilityPlatform)
final spellCheckAvailabilityPlatformProvider =
    SpellCheckAvailabilityPlatformProvider._();

final class SpellCheckAvailabilityPlatformProvider
    extends $FunctionalProvider<TargetPlatform, TargetPlatform, TargetPlatform>
    with $Provider<TargetPlatform> {
  SpellCheckAvailabilityPlatformProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'spellCheckAvailabilityPlatformProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$spellCheckAvailabilityPlatformHash();

  @$internal
  @override
  $ProviderElement<TargetPlatform> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TargetPlatform create(Ref ref) {
    return spellCheckAvailabilityPlatform(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TargetPlatform value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TargetPlatform>(value),
    );
  }
}

String _$spellCheckAvailabilityPlatformHash() =>
    r'27eecb0baa795a064a3fc98cf1fd547c145d8fd9';

@ProviderFor(spellCheckAvailabilityService)
final spellCheckAvailabilityServiceProvider =
    SpellCheckAvailabilityServiceProvider._();

final class SpellCheckAvailabilityServiceProvider
    extends
        $FunctionalProvider<
          SpellCheckService?,
          SpellCheckService?,
          SpellCheckService?
        >
    with $Provider<SpellCheckService?> {
  SpellCheckAvailabilityServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'spellCheckAvailabilityServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$spellCheckAvailabilityServiceHash();

  @$internal
  @override
  $ProviderElement<SpellCheckService?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SpellCheckService? create(Ref ref) {
    return spellCheckAvailabilityService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SpellCheckService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SpellCheckService?>(value),
    );
  }
}

String _$spellCheckAvailabilityServiceHash() =>
    r'1560d4e3a5971b13f13f382d86df84f4ea726e1c';

@ProviderFor(spellCheckAvailability)
final spellCheckAvailabilityProvider = SpellCheckAvailabilityProvider._();

final class SpellCheckAvailabilityProvider
    extends
        $FunctionalProvider<
          AsyncValue<SpellCheckAvailability>,
          SpellCheckAvailability,
          FutureOr<SpellCheckAvailability>
        >
    with
        $FutureModifier<SpellCheckAvailability>,
        $FutureProvider<SpellCheckAvailability> {
  SpellCheckAvailabilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'spellCheckAvailabilityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$spellCheckAvailabilityHash();

  @$internal
  @override
  $FutureProviderElement<SpellCheckAvailability> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SpellCheckAvailability> create(Ref ref) {
    return spellCheckAvailability(ref);
  }
}

String _$spellCheckAvailabilityHash() =>
    r'657bf3c77bcecf6dc9f6f5648dceb636b2a2c09a';
