// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mediaRoot)
final mediaRootProvider = MediaRootProvider._();

final class MediaRootProvider
    extends
        $FunctionalProvider<
          AsyncValue<Directory>,
          Directory,
          FutureOr<Directory>
        >
    with $FutureModifier<Directory>, $FutureProvider<Directory> {
  MediaRootProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaRootProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaRootHash();

  @$internal
  @override
  $FutureProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Directory> create(Ref ref) {
    return mediaRoot(ref);
  }
}

String _$mediaRootHash() => r'e52e7eea4a76102b3e05c4b7f5d54bd0629af225';

@ProviderFor(mediaDraftsRoot)
final mediaDraftsRootProvider = MediaDraftsRootProvider._();

final class MediaDraftsRootProvider
    extends
        $FunctionalProvider<
          AsyncValue<Directory>,
          Directory,
          FutureOr<Directory>
        >
    with $FutureModifier<Directory>, $FutureProvider<Directory> {
  MediaDraftsRootProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaDraftsRootProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaDraftsRootHash();

  @$internal
  @override
  $FutureProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Directory> create(Ref ref) {
    return mediaDraftsRoot(ref);
  }
}

String _$mediaDraftsRootHash() => r'bc34b9131d4f81f6925a7384fc3027908b46699d';

@ProviderFor(mediaStore)
final mediaStoreProvider = MediaStoreProvider._();

final class MediaStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<MediaStore>,
          MediaStore,
          FutureOr<MediaStore>
        >
    with $FutureModifier<MediaStore>, $FutureProvider<MediaStore> {
  MediaStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaStoreHash();

  @$internal
  @override
  $FutureProviderElement<MediaStore> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<MediaStore> create(Ref ref) {
    return mediaStore(ref);
  }
}

String _$mediaStoreHash() => r'ce51d3c11b0a660b538a69d1338dfd1357be374c';
