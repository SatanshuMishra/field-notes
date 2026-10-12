// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installed_app_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(installedApp)
final installedAppProvider = InstalledAppProvider._();

final class InstalledAppProvider
    extends
        $FunctionalProvider<
          AsyncValue<InstalledApp>,
          InstalledApp,
          FutureOr<InstalledApp>
        >
    with $FutureModifier<InstalledApp>, $FutureProvider<InstalledApp> {
  InstalledAppProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installedAppProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installedAppHash();

  @$internal
  @override
  $FutureProviderElement<InstalledApp> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InstalledApp> create(Ref ref) {
    return installedApp(ref);
  }
}

String _$installedAppHash() => r'8dad72823f01f0069cc75b5a76ee317bd3053433';
