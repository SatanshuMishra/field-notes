// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SearchQuery)
final searchQueryProvider = SearchQueryProvider._();

final class SearchQueryProvider extends $NotifierProvider<SearchQuery, String> {
  SearchQueryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchQueryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchQueryHash();

  @$internal
  @override
  SearchQuery create() => SearchQuery();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$searchQueryHash() => r'9f97403b5659152608c0dbc158267442c72403bc';

abstract class _$SearchQuery extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(searchDayViews)
final searchDayViewsProvider = SearchDayViewsProvider._();

final class SearchDayViewsProvider
    extends
        $FunctionalProvider<
          List<SearchDayView>,
          List<SearchDayView>,
          List<SearchDayView>
        >
    with $Provider<List<SearchDayView>> {
  SearchDayViewsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchDayViewsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchDayViewsHash();

  @$internal
  @override
  $ProviderElement<List<SearchDayView>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<SearchDayView> create(Ref ref) {
    return searchDayViews(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SearchDayView> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SearchDayView>>(value),
    );
  }
}

String _$searchDayViewsHash() => r'de88cceeb3b514f8da0979365214390995ed1d52';

@ProviderFor(searchResults)
final searchResultsProvider = SearchResultsProvider._();

final class SearchResultsProvider
    extends
        $FunctionalProvider<
          List<SearchDayView>,
          List<SearchDayView>,
          List<SearchDayView>
        >
    with $Provider<List<SearchDayView>> {
  SearchResultsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchResultsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchResultsHash();

  @$internal
  @override
  $ProviderElement<List<SearchDayView>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<SearchDayView> create(Ref ref) {
    return searchResults(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SearchDayView> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SearchDayView>>(value),
    );
  }
}

String _$searchResultsHash() => r'f1631b0fa4372355b48b7864dcc7136acd436d31';
