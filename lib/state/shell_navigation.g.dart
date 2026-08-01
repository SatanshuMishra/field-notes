// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shell_navigation.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ShellNavigation)
final shellNavigationProvider = ShellNavigationProvider._();

final class ShellNavigationProvider
    extends $NotifierProvider<ShellNavigation, ShellDestination> {
  ShellNavigationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellNavigationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellNavigationHash();

  @$internal
  @override
  ShellNavigation create() => ShellNavigation();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShellDestination value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShellDestination>(value),
    );
  }
}

String _$shellNavigationHash() => r'c7fc0efb9610318f65c006b7813628e968fc253b';

abstract class _$ShellNavigation extends $Notifier<ShellDestination> {
  ShellDestination build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ShellDestination, ShellDestination>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ShellDestination, ShellDestination>,
              ShellDestination,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
