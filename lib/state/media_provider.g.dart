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

String _$mediaRootHash() => r'84ef9346470d4cea8a36d53b7810cf0fb3e91f04';

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

String _$mediaStoreHash() => r'92c2f1f8467cf15631c902dd9083d524a99c9963';

@ProviderFor(filesystemMediaStore)
final filesystemMediaStoreProvider = FilesystemMediaStoreProvider._();

final class FilesystemMediaStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<FilesystemMediaStore>,
          FilesystemMediaStore,
          FutureOr<FilesystemMediaStore>
        >
    with
        $FutureModifier<FilesystemMediaStore>,
        $FutureProvider<FilesystemMediaStore> {
  FilesystemMediaStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filesystemMediaStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filesystemMediaStoreHash();

  @$internal
  @override
  $FutureProviderElement<FilesystemMediaStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FilesystemMediaStore> create(Ref ref) {
    return filesystemMediaStore(ref);
  }
}

String _$filesystemMediaStoreHash() =>
    r'9d5c4d3d28380d56c1ee336a50443323f73db0b9';
