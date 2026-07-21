// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_entries_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(searchAllEntries)
final searchAllEntriesProvider = SearchAllEntriesProvider._();

final class SearchAllEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Entry>>,
          List<Entry>,
          Stream<List<Entry>>
        >
    with $FutureModifier<List<Entry>>, $StreamProvider<List<Entry>> {
  SearchAllEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchAllEntriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchAllEntriesHash();

  @$internal
  @override
  $StreamProviderElement<List<Entry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Entry>> create(Ref ref) {
    return searchAllEntries(ref);
  }
}

String _$searchAllEntriesHash() => r'da6089a28dc5a4eda108f5acbbf147ebc78fbddd';
