// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(todayClock)
final todayClockProvider = TodayClockProvider._();

final class TodayClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  TodayClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayClockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return todayClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$todayClockHash() => r'43e4960a0bfc42507fbb193b421a2e046efc0f0b';

@ProviderFor(todayStart)
final todayStartProvider = TodayStartProvider._();

final class TodayStartProvider
    extends $FunctionalProvider<DateTime, DateTime, DateTime>
    with $Provider<DateTime> {
  TodayStartProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayStartProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayStartHash();

  @$internal
  @override
  $ProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DateTime create(Ref ref) {
    return todayStart(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$todayStartHash() => r'f529a8c5d435ae24124476e329bd08238dc56208';

@ProviderFor(todayDate)
final todayDateProvider = TodayDateProvider._();

final class TodayDateProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  TodayDateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayDateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayDateHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return todayDate(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$todayDateHash() => r'267fddb8cf35ffc9c795de70da76b08c32fd53f1';

@ProviderFor(thisWeekCells)
final thisWeekCellsProvider = ThisWeekCellsProvider._();

final class ThisWeekCellsProvider
    extends
        $FunctionalProvider<
          List<TodayWeekCell>,
          List<TodayWeekCell>,
          List<TodayWeekCell>
        >
    with $Provider<List<TodayWeekCell>> {
  ThisWeekCellsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'thisWeekCellsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$thisWeekCellsHash();

  @$internal
  @override
  $ProviderElement<List<TodayWeekCell>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<TodayWeekCell> create(Ref ref) {
    return thisWeekCells(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TodayWeekCell> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TodayWeekCell>>(value),
    );
  }
}

String _$thisWeekCellsHash() => r'232dacfb4785764d05ace104487b1503242d65dc';

@ProviderFor(todayMediaResolver)
final todayMediaResolverProvider = TodayMediaResolverProvider._();

final class TodayMediaResolverProvider
    extends
        $FunctionalProvider<
          AsyncValue<MediaResolver>,
          MediaResolver,
          FutureOr<MediaResolver>
        >
    with $FutureModifier<MediaResolver>, $FutureProvider<MediaResolver> {
  TodayMediaResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayMediaResolverProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayMediaResolverHash();

  @$internal
  @override
  $FutureProviderElement<MediaResolver> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MediaResolver> create(Ref ref) {
    return todayMediaResolver(ref);
  }
}

String _$todayMediaResolverHash() =>
    r'b28f58c652302976706b6f8d63d64c0bc00d2859';

@ProviderFor(todayAudioPlayerFactory)
final todayAudioPlayerFactoryProvider = TodayAudioPlayerFactoryProvider._();

final class TodayAudioPlayerFactoryProvider
    extends
        $FunctionalProvider<
          EntryAudioPlayerFactory,
          EntryAudioPlayerFactory,
          EntryAudioPlayerFactory
        >
    with $Provider<EntryAudioPlayerFactory> {
  TodayAudioPlayerFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayAudioPlayerFactoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayAudioPlayerFactoryHash();

  @$internal
  @override
  $ProviderElement<EntryAudioPlayerFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EntryAudioPlayerFactory create(Ref ref) {
    return todayAudioPlayerFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EntryAudioPlayerFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EntryAudioPlayerFactory>(value),
    );
  }
}

String _$todayAudioPlayerFactoryHash() =>
    r'3cad6b1bbf9172f189c6e7221927e5a8e9e1c6e5';

@ProviderFor(todayVideoPlayerFactory)
final todayVideoPlayerFactoryProvider = TodayVideoPlayerFactoryProvider._();

final class TodayVideoPlayerFactoryProvider
    extends
        $FunctionalProvider<
          EntryVideoPlayerFactory,
          EntryVideoPlayerFactory,
          EntryVideoPlayerFactory
        >
    with $Provider<EntryVideoPlayerFactory> {
  TodayVideoPlayerFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayVideoPlayerFactoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayVideoPlayerFactoryHash();

  @$internal
  @override
  $ProviderElement<EntryVideoPlayerFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EntryVideoPlayerFactory create(Ref ref) {
    return todayVideoPlayerFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EntryVideoPlayerFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EntryVideoPlayerFactory>(value),
    );
  }
}

String _$todayVideoPlayerFactoryHash() =>
    r'5631e1de1134d4b88b7a497ab431ade6d72a542f';

@ProviderFor(onThisDayMemory)
final onThisDayMemoryProvider = OnThisDayMemoryProvider._();

final class OnThisDayMemoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<OnThisDayMemory?>,
          OnThisDayMemory?,
          FutureOr<OnThisDayMemory?>
        >
    with $FutureModifier<OnThisDayMemory?>, $FutureProvider<OnThisDayMemory?> {
  OnThisDayMemoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onThisDayMemoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onThisDayMemoryHash();

  @$internal
  @override
  $FutureProviderElement<OnThisDayMemory?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<OnThisDayMemory?> create(Ref ref) {
    return onThisDayMemory(ref);
  }
}

String _$onThisDayMemoryHash() => r'1c82f4ef0ac48f38b285c60e3cf33b8f898eb8ca';
