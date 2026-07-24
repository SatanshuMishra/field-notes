// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'camera_selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SelectedCameraDevice)
final selectedCameraDeviceProvider = SelectedCameraDeviceProvider._();

final class SelectedCameraDeviceProvider
    extends $NotifierProvider<SelectedCameraDevice, String?> {
  SelectedCameraDeviceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedCameraDeviceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedCameraDeviceHash();

  @$internal
  @override
  SelectedCameraDevice create() => SelectedCameraDevice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$selectedCameraDeviceHash() =>
    r'52009ffb78f67a63817289c3e627496631b73b84';

abstract class _$SelectedCameraDevice extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
