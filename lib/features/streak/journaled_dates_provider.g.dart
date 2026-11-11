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
    r'82c1d8537260ac20e5530dfe869f20b2918f45dc';

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

@ProviderFor(streakDays)
final streakDaysProvider = StreakDaysProvider._();

final class StreakDaysProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StreakDay>>,
          List<StreakDay>,
          Stream<List<StreakDay>>
        >
    with $FutureModifier<List<StreakDay>>, $StreamProvider<List<StreakDay>> {
  StreakDaysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streakDaysProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streakDaysHash();

  @$internal
  @override
  $StreamProviderElement<List<StreakDay>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<StreakDay>> create(Ref ref) {
    return streakDays(ref);
  }
}

String _$streakDaysHash() => r'fef899e37e1463b96e6d03afbb097c6071d80f5e';
