// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(updateHttpClient)
final updateHttpClientProvider = UpdateHttpClientProvider._();

final class UpdateHttpClientProvider
    extends $FunctionalProvider<http.Client, http.Client, http.Client>
    with $Provider<http.Client> {
  UpdateHttpClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateHttpClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateHttpClientHash();

  @$internal
  @override
  $ProviderElement<http.Client> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  http.Client create(Ref ref) {
    return updateHttpClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(http.Client value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<http.Client>(value),
    );
  }
}

String _$updateHttpClientHash() => r'5364d3192d38b58f91f8fad605eae3213fdb3567';

@ProviderFor(updateClock)
final updateClockProvider = UpdateClockProvider._();

final class UpdateClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  UpdateClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return updateClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$updateClockHash() => r'ac0e13abc5435626ba8a23eb109da2bb0befe624';

@ProviderFor(releaseSource)
final releaseSourceProvider = ReleaseSourceProvider._();

final class ReleaseSourceProvider
    extends $FunctionalProvider<ReleaseSource, ReleaseSource, ReleaseSource>
    with $Provider<ReleaseSource> {
  ReleaseSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'releaseSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$releaseSourceHash();

  @$internal
  @override
  $ProviderElement<ReleaseSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReleaseSource create(Ref ref) {
    return releaseSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReleaseSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReleaseSource>(value),
    );
  }
}

String _$releaseSourceHash() => r'26fcd160da8f717fe67c41887a462dd99b752608';

@ProviderFor(updateInstaller)
final updateInstallerProvider = UpdateInstallerProvider._();

final class UpdateInstallerProvider
    extends
        $FunctionalProvider<
          AsyncValue<UpdateInstaller>,
          UpdateInstaller,
          FutureOr<UpdateInstaller>
        >
    with $FutureModifier<UpdateInstaller>, $FutureProvider<UpdateInstaller> {
  UpdateInstallerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateInstallerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateInstallerHash();

  @$internal
  @override
  $FutureProviderElement<UpdateInstaller> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UpdateInstaller> create(Ref ref) {
    return updateInstaller(ref);
  }
}

String _$updateInstallerHash() => r'6b7a7f20d62c39e68df5917fd9f3efdf450d9e3e';

@ProviderFor(updateRoute)
final updateRouteProvider = UpdateRouteProvider._();

final class UpdateRouteProvider
    extends
        $FunctionalProvider<
          AsyncValue<InstallRoute>,
          InstallRoute,
          FutureOr<InstallRoute>
        >
    with $FutureModifier<InstallRoute>, $FutureProvider<InstallRoute> {
  UpdateRouteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateRouteProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateRouteHash();

  @$internal
  @override
  $FutureProviderElement<InstallRoute> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InstallRoute> create(Ref ref) {
    return updateRoute(ref);
  }
}

String _$updateRouteHash() => r'73b0d3717bc94d74594a00f9d3cf2ae933f31634';

@ProviderFor(updateNotice)
final updateNoticeProvider = UpdateNoticeProvider._();

final class UpdateNoticeProvider
    extends $FunctionalProvider<ReleaseInfo?, ReleaseInfo?, ReleaseInfo?>
    with $Provider<ReleaseInfo?> {
  UpdateNoticeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateNoticeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateNoticeHash();

  @$internal
  @override
  $ProviderElement<ReleaseInfo?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReleaseInfo? create(Ref ref) {
    return updateNotice(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReleaseInfo? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReleaseInfo?>(value),
    );
  }
}

String _$updateNoticeHash() => r'71a89200ae929882c88507e85debd0a0180af3e1';
