// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draft_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(draftRoot)
final draftRootProvider = DraftRootProvider._();

final class DraftRootProvider
    extends
        $FunctionalProvider<
          AsyncValue<Directory>,
          Directory,
          FutureOr<Directory>
        >
    with $FutureModifier<Directory>, $FutureProvider<Directory> {
  DraftRootProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'draftRootProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$draftRootHash();

  @$internal
  @override
  $FutureProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Directory> create(Ref ref) {
    return draftRoot(ref);
  }
}

String _$draftRootHash() => r'00069d8f65936a791340e344ba968712e3cfd827';

@ProviderFor(draftStore)
final draftStoreProvider = DraftStoreProvider._();

final class DraftStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<DraftStore>,
          DraftStore,
          FutureOr<DraftStore>
        >
    with $FutureModifier<DraftStore>, $FutureProvider<DraftStore> {
  DraftStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'draftStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$draftStoreHash();

  @$internal
  @override
  $FutureProviderElement<DraftStore> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DraftStore> create(Ref ref) {
    return draftStore(ref);
  }
}

String _$draftStoreHash() => r'c13d76d592d93970e2cdca06ce3d541b50c50eec';
