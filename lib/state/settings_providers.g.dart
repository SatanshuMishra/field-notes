// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appSettings)
final appSettingsProvider = AppSettingsProvider._();

final class AppSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppSettings>,
          AppSettings,
          Stream<AppSettings>
        >
    with $FutureModifier<AppSettings>, $StreamProvider<AppSettings> {
  AppSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingsHash();

  @$internal
  @override
  $StreamProviderElement<AppSettings> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<AppSettings> create(Ref ref) {
    return appSettings(ref);
  }
}

String _$appSettingsHash() => r'42881025817ecbfbd52e4e563bb80521e3e14d0d';

@ProviderFor(textScale)
final textScaleProvider = TextScaleProvider._();

final class TextScaleProvider
    extends $FunctionalProvider<double, double, double>
    with $Provider<double> {
  TextScaleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'textScaleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$textScaleHash();

  @$internal
  @override
  $ProviderElement<double> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  double create(Ref ref) {
    return textScale(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$textScaleHash() => r'a6a48c34bbc62891ee29cad41a33c86d2c7c180c';

@ProviderFor(weekStart)
final weekStartProvider = WeekStartProvider._();

final class WeekStartProvider
    extends $FunctionalProvider<WeekStart, WeekStart, WeekStart>
    with $Provider<WeekStart> {
  WeekStartProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weekStartProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weekStartHash();

  @$internal
  @override
  $ProviderElement<WeekStart> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WeekStart create(Ref ref) {
    return weekStart(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WeekStart value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WeekStart>(value),
    );
  }
}

String _$weekStartHash() => r'62914b2e9fa9c5c0af94f55f3c189a2d1307453f';

@ProviderFor(spellCheckEnabled)
final spellCheckEnabledProvider = SpellCheckEnabledProvider._();

final class SpellCheckEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  SpellCheckEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'spellCheckEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$spellCheckEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return spellCheckEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$spellCheckEnabledHash() => r'fe6e15d4a43dc37e1ebad23e519cd08963487228';
