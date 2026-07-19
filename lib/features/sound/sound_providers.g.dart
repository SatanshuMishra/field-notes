// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sound_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(soundEnabled)
final soundEnabledProvider = SoundEnabledProvider._();

final class SoundEnabledProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  SoundEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soundEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soundEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return soundEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$soundEnabledHash() => r'827831e144bf57234eea7dbbaa141cefd2a1aaf0';

@ProviderFor(soundPlayer)
final soundPlayerProvider = SoundPlayerProvider._();

final class SoundPlayerProvider
    extends $FunctionalProvider<SoundPlayer, SoundPlayer, SoundPlayer>
    with $Provider<SoundPlayer> {
  SoundPlayerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soundPlayerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soundPlayerHash();

  @$internal
  @override
  $ProviderElement<SoundPlayer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SoundPlayer create(Ref ref) {
    return soundPlayer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SoundPlayer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SoundPlayer>(value),
    );
  }
}

String _$soundPlayerHash() => r'273d0044adea04ade60f7f30ff4c71ff6e9b0867';

@ProviderFor(soundService)
final soundServiceProvider = SoundServiceProvider._();

final class SoundServiceProvider
    extends $FunctionalProvider<SoundService, SoundService, SoundService>
    with $Provider<SoundService> {
  SoundServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soundServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soundServiceHash();

  @$internal
  @override
  $ProviderElement<SoundService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SoundService create(Ref ref) {
    return soundService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SoundService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SoundService>(value),
    );
  }
}

String _$soundServiceHash() => r'eda42288d6322debc688c0ab8e07984f95ae86d9';
