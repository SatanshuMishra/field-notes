// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sky_time.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(skyClock)
final skyClockProvider = SkyClockProvider._();

final class SkyClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  SkyClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skyClockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skyClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return skyClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$skyClockHash() => r'61e7ebf98be9ec48ffdf40e510495897b06b644d';

@ProviderFor(SkyTime)
final skyTimeProvider = SkyTimeProvider._();

final class SkyTimeProvider extends $NotifierProvider<SkyTime, SkyMoment> {
  SkyTimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skyTimeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skyTimeHash();

  @$internal
  @override
  SkyTime create() => SkyTime();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SkyMoment value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SkyMoment>(value),
    );
  }
}

String _$skyTimeHash() => r'b482d2a1f3649533271a472cec1ee7e20a8ce1de';

abstract class _$SkyTime extends $Notifier<SkyMoment> {
  SkyMoment build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SkyMoment, SkyMoment>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SkyMoment, SkyMoment>,
              SkyMoment,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
