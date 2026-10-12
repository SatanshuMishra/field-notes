// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bundled_changelog.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bundledChangelog)
final bundledChangelogProvider = BundledChangelogProvider._();

final class BundledChangelogProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  BundledChangelogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bundledChangelogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bundledChangelogHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return bundledChangelog(ref);
  }
}

String _$bundledChangelogHash() => r'996d1a457c2e21b0442c2f4f129e8ebcc56bb98a';

@ProviderFor(installedReleaseNotes)
final installedReleaseNotesProvider = InstalledReleaseNotesProvider._();

final class InstalledReleaseNotesProvider
    extends
        $FunctionalProvider<
          AsyncValue<ChangelogSection?>,
          ChangelogSection?,
          FutureOr<ChangelogSection?>
        >
    with
        $FutureModifier<ChangelogSection?>,
        $FutureProvider<ChangelogSection?> {
  InstalledReleaseNotesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installedReleaseNotesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installedReleaseNotesHash();

  @$internal
  @override
  $FutureProviderElement<ChangelogSection?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ChangelogSection?> create(Ref ref) {
    return installedReleaseNotes(ref);
  }
}

String _$installedReleaseNotesHash() =>
    r'6ccedbae1cdbc846daa1c54ed873f0c90a77f351';
