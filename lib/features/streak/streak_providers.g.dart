// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'streak_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(streakClock)
final streakClockProvider = StreakClockProvider._();

final class StreakClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  StreakClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streakClockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streakClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return streakClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$streakClockHash() => r'7be55627a0faf9b53321aed59dd9f5e90e9494c0';

@ProviderFor(streakSummary)
final streakSummaryProvider = StreakSummaryProvider._();

final class StreakSummaryProvider
    extends $FunctionalProvider<StreakSummary, StreakSummary, StreakSummary>
    with $Provider<StreakSummary> {
  StreakSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streakSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streakSummaryHash();

  @$internal
  @override
  $ProviderElement<StreakSummary> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StreakSummary create(Ref ref) {
    return streakSummary(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StreakSummary value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StreakSummary>(value),
    );
  }
}

String _$streakSummaryHash() => r'2fcf51049660f3ad287bb97193588e33986a9144';
