// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meadow_key_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(meadowKey)
final meadowKeyProvider = MeadowKeyProvider._();

final class MeadowKeyProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  MeadowKeyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'meadowKeyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$meadowKeyHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return meadowKey(ref);
  }
}

String _$meadowKeyHash() => r'3bf1635f4ed47c3815bb60f390878e74328deaf3';
