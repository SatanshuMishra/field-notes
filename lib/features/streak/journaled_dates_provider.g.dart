// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journaled_dates_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(journaledDates)
final journaledDatesProvider = JournaledDatesProvider._();

final class JournaledDatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          Stream<List<String>>
        >
    with $FutureModifier<List<String>>, $StreamProvider<List<String>> {
  JournaledDatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journaledDatesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journaledDatesHash();

  @$internal
  @override
  $StreamProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<String>> create(Ref ref) {
    return journaledDates(ref);
  }
}

String _$journaledDatesHash() => r'996b7b1989d1a286a8e9d2e0a1744a5c035561c8';
