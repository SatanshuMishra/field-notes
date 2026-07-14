// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(allDays)
final allDaysProvider = AllDaysProvider._();

final class AllDaysProvider
    extends
        $FunctionalProvider<AsyncValue<List<Day>>, List<Day>, Stream<List<Day>>>
    with $FutureModifier<List<Day>>, $StreamProvider<List<Day>> {
  AllDaysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allDaysProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allDaysHash();

  @$internal
  @override
  $StreamProviderElement<List<Day>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Day>> create(Ref ref) {
    return allDays(ref);
  }
}

String _$allDaysHash() => r'748ddb8aa1d44585ab41d02e01529831154ddd9d';

@ProviderFor(dayForDate)
final dayForDateProvider = DayForDateFamily._();

final class DayForDateProvider
    extends $FunctionalProvider<AsyncValue<Day?>, Day?, Stream<Day?>>
    with $FutureModifier<Day?>, $StreamProvider<Day?> {
  DayForDateProvider._({
    required DayForDateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'dayForDateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dayForDateHash();

  @override
  String toString() {
    return r'dayForDateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Day?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Day?> create(Ref ref) {
    final argument = this.argument as String;
    return dayForDate(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DayForDateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dayForDateHash() => r'a8a5525c9bee51563ecc8ba8c0746870fa7cf362';

final class DayForDateFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Day?>, String> {
  DayForDateFamily._()
    : super(
        retry: null,
        name: r'dayForDateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DayForDateProvider call(String date) =>
      DayForDateProvider._(argument: date, from: this);

  @override
  String toString() => r'dayForDateProvider';
}

@ProviderFor(daysInMonth)
final daysInMonthProvider = DaysInMonthFamily._();

final class DaysInMonthProvider
    extends
        $FunctionalProvider<AsyncValue<List<Day>>, List<Day>, Stream<List<Day>>>
    with $FutureModifier<List<Day>>, $StreamProvider<List<Day>> {
  DaysInMonthProvider._({
    required DaysInMonthFamily super.from,
    required ({int year, int month}) super.argument,
  }) : super(
         retry: null,
         name: r'daysInMonthProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$daysInMonthHash();

  @override
  String toString() {
    return r'daysInMonthProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<Day>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Day>> create(Ref ref) {
    final argument = this.argument as ({int year, int month});
    return daysInMonth(ref, year: argument.year, month: argument.month);
  }

  @override
  bool operator ==(Object other) {
    return other is DaysInMonthProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$daysInMonthHash() => r'fa4d5cebc4aac13f815fa18533812ab4c5466325';

final class DaysInMonthFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Day>>, ({int year, int month})> {
  DaysInMonthFamily._()
    : super(
        retry: null,
        name: r'daysInMonthProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DaysInMonthProvider call({required int year, required int month}) =>
      DaysInMonthProvider._(argument: (year: year, month: month), from: this);

  @override
  String toString() => r'daysInMonthProvider';
}

@ProviderFor(entriesForDate)
final entriesForDateProvider = EntriesForDateFamily._();

final class EntriesForDateProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Entry>>,
          List<Entry>,
          Stream<List<Entry>>
        >
    with $FutureModifier<List<Entry>>, $StreamProvider<List<Entry>> {
  EntriesForDateProvider._({
    required EntriesForDateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'entriesForDateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$entriesForDateHash();

  @override
  String toString() {
    return r'entriesForDateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Entry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Entry>> create(Ref ref) {
    final argument = this.argument as String;
    return entriesForDate(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EntriesForDateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$entriesForDateHash() => r'be71b5d787c778a3f0612a26c0bf0437bb7ad3ec';

final class EntriesForDateFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Entry>>, String> {
  EntriesForDateFamily._()
    : super(
        retry: null,
        name: r'entriesForDateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EntriesForDateProvider call(String date) =>
      EntriesForDateProvider._(argument: date, from: this);

  @override
  String toString() => r'entriesForDateProvider';
}

@ProviderFor(entriesForDay)
final entriesForDayProvider = EntriesForDayFamily._();

final class EntriesForDayProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Entry>>,
          List<Entry>,
          Stream<List<Entry>>
        >
    with $FutureModifier<List<Entry>>, $StreamProvider<List<Entry>> {
  EntriesForDayProvider._({
    required EntriesForDayFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'entriesForDayProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$entriesForDayHash();

  @override
  String toString() {
    return r'entriesForDayProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Entry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Entry>> create(Ref ref) {
    final argument = this.argument as String;
    return entriesForDay(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EntriesForDayProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$entriesForDayHash() => r'8824fe3769bce6f989c7e9919857051cd2079f8a';

final class EntriesForDayFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Entry>>, String> {
  EntriesForDayFamily._()
    : super(
        retry: null,
        name: r'entriesForDayProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EntriesForDayProvider call(String dayId) =>
      EntriesForDayProvider._(argument: dayId, from: this);

  @override
  String toString() => r'entriesForDayProvider';
}

@ProviderFor(photosForEntry)
final photosForEntryProvider = PhotosForEntryFamily._();

final class PhotosForEntryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EntryPhoto>>,
          List<EntryPhoto>,
          Stream<List<EntryPhoto>>
        >
    with $FutureModifier<List<EntryPhoto>>, $StreamProvider<List<EntryPhoto>> {
  PhotosForEntryProvider._({
    required PhotosForEntryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'photosForEntryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$photosForEntryHash();

  @override
  String toString() {
    return r'photosForEntryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<EntryPhoto>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<EntryPhoto>> create(Ref ref) {
    final argument = this.argument as String;
    return photosForEntry(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PhotosForEntryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$photosForEntryHash() => r'1a55db7a224bf5ed9bf443e7fb4737bd2acc141f';

final class PhotosForEntryFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<EntryPhoto>>, String> {
  PhotosForEntryFamily._()
    : super(
        retry: null,
        name: r'photosForEntryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PhotosForEntryProvider call(String entryId) =>
      PhotosForEntryProvider._(argument: entryId, from: this);

  @override
  String toString() => r'photosForEntryProvider';
}
