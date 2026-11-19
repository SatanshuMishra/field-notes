// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opening_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(playsOpening)
final playsOpeningProvider = PlaysOpeningProvider._();

final class PlaysOpeningProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  PlaysOpeningProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playsOpeningProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playsOpeningHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return playsOpening(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$playsOpeningHash() => r'67836853ea3eda092d90773160ed016fc38b44f8';
