// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journaled_dates_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(journalEntryCounts)
final journalEntryCountsProvider = JournalEntryCountsProvider._();

final class JournalEntryCountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          Stream<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $StreamProvider<Map<String, int>> {
  JournalEntryCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journalEntryCountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journalEntryCountsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, int>> create(Ref ref) {
    return journalEntryCounts(ref);
  }
}

String _$journalEntryCountsHash() =>
    r'a4ab9b9ca3c074150a134b77f0360b9aba8dedd0';

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

String _$journaledDatesHash() => r'55294b552e96f27dcbb82e42170735067acabad6';
