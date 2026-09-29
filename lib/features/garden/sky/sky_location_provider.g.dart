// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sky_location_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(localTimezoneIdentifier)
final localTimezoneIdentifierProvider = LocalTimezoneIdentifierProvider._();

final class LocalTimezoneIdentifierProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  LocalTimezoneIdentifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localTimezoneIdentifierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localTimezoneIdentifierHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return localTimezoneIdentifier(ref);
  }
}

String _$localTimezoneIdentifierHash() =>
    r'7eaf50997b9e6833d3122083e41a1f18502d64f4';

@ProviderFor(localUtcOffset)
final localUtcOffsetProvider = LocalUtcOffsetProvider._();

final class LocalUtcOffsetProvider
    extends $FunctionalProvider<Duration, Duration, Duration>
    with $Provider<Duration> {
  LocalUtcOffsetProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localUtcOffsetProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localUtcOffsetHash();

  @$internal
  @override
  $ProviderElement<Duration> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Duration create(Ref ref) {
    return localUtcOffset(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration>(value),
    );
  }
}

String _$localUtcOffsetHash() => r'bceafa25d4016fa329d1caaedf92bfbb38c8e50f';

@ProviderFor(skyLocation)
final skyLocationProvider = SkyLocationProvider._();

final class SkyLocationProvider
    extends
        $FunctionalProvider<
          AsyncValue<SkyLocation>,
          SkyLocation,
          FutureOr<SkyLocation>
        >
    with $FutureModifier<SkyLocation>, $FutureProvider<SkyLocation> {
  SkyLocationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skyLocationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skyLocationHash();

  @$internal
  @override
  $FutureProviderElement<SkyLocation> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SkyLocation> create(Ref ref) {
    return skyLocation(ref);
  }
}

String _$skyLocationHash() => r'5f258eb8bedfdb885a4f82ceefb08d4e8fad5140';
