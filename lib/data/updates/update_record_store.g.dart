// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_record_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(updateRecordStore)
final updateRecordStoreProvider = UpdateRecordStoreProvider._();

final class UpdateRecordStoreProvider
    extends
        $FunctionalProvider<
          UpdateRecordStore,
          UpdateRecordStore,
          UpdateRecordStore
        >
    with $Provider<UpdateRecordStore> {
  UpdateRecordStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateRecordStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateRecordStoreHash();

  @$internal
  @override
  $ProviderElement<UpdateRecordStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UpdateRecordStore create(Ref ref) {
    return updateRecordStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateRecordStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateRecordStore>(value),
    );
  }
}

String _$updateRecordStoreHash() => r'248514f3030eea2f566ec3ce70bb8738a3add5a1';
