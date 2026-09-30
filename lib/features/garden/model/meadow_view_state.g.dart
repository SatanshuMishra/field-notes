// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meadow_view_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MeadowViewState)
final meadowViewStateProvider = MeadowViewStateProvider._();

final class MeadowViewStateProvider
    extends $NotifierProvider<MeadowViewState, MeadowView> {
  MeadowViewStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'meadowViewStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$meadowViewStateHash();

  @$internal
  @override
  MeadowViewState create() => MeadowViewState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MeadowView value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MeadowView>(value),
    );
  }
}

String _$meadowViewStateHash() => r'c4ae0cf181f1711d520620c000260870733d9d3d';

abstract class _$MeadowViewState extends $Notifier<MeadowView> {
  MeadowView build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MeadowView, MeadowView>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MeadowView, MeadowView>,
              MeadowView,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
