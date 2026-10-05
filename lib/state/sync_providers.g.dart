// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(keyStore)
final keyStoreProvider = KeyStoreProvider._();

final class KeyStoreProvider
    extends $FunctionalProvider<KeyStore, KeyStore, KeyStore>
    with $Provider<KeyStore> {
  KeyStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'keyStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$keyStoreHash();

  @$internal
  @override
  $ProviderElement<KeyStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KeyStore create(Ref ref) {
    return keyStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KeyStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KeyStore>(value),
    );
  }
}

String _$keyStoreHash() => r'15f86623b2621af35a934e0c9d00ac53c5ff3410';

@ProviderFor(networkMonitor)
final networkMonitorProvider = NetworkMonitorProvider._();

final class NetworkMonitorProvider
    extends $FunctionalProvider<NetworkMonitor, NetworkMonitor, NetworkMonitor>
    with $Provider<NetworkMonitor> {
  NetworkMonitorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkMonitorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkMonitorHash();

  @$internal
  @override
  $ProviderElement<NetworkMonitor> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NetworkMonitor create(Ref ref) {
    return networkMonitor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkMonitor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkMonitor>(value),
    );
  }
}

String _$networkMonitorHash() => r'47c64daf83493f5cd050aebcf45501f974e719ac';

@ProviderFor(syncEnabled)
final syncEnabledProvider = SyncEnabledProvider._();

final class SyncEnabledProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  SyncEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncEnabledHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return syncEnabled(ref);
  }
}

String _$syncEnabledHash() => r'37f5853825e3aee0692bb7f37223148fa482d9c9';

@ProviderFor(relayAddress)
final relayAddressProvider = RelayAddressProvider._();

final class RelayAddressProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, Stream<String?>>
    with $FutureModifier<String?>, $StreamProvider<String?> {
  RelayAddressProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayAddressProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayAddressHash();

  @$internal
  @override
  $StreamProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String?> create(Ref ref) {
    return relayAddress(ref);
  }
}

String _$relayAddressHash() => r'81fef487628b42a8ee57c8a961b65c5886525dff';

@ProviderFor(appLifecycle)
final appLifecycleProvider = AppLifecycleProvider._();

final class AppLifecycleProvider
    extends
        $FunctionalProvider<LifecycleSource, LifecycleSource, LifecycleSource>
    with $Provider<LifecycleSource> {
  AppLifecycleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLifecycleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLifecycleHash();

  @$internal
  @override
  $ProviderElement<LifecycleSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LifecycleSource create(Ref ref) {
    return appLifecycle(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LifecycleSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LifecycleSource>(value),
    );
  }
}

String _$appLifecycleHash() => r'7281a22895fed5c6dda342e0b88790a1efab2a47';

@ProviderFor(syncEngine)
final syncEngineProvider = SyncEngineProvider._();

final class SyncEngineProvider
    extends $FunctionalProvider<SyncEngine, SyncEngine, SyncEngine>
    with $Provider<SyncEngine> {
  SyncEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncEngineHash();

  @$internal
  @override
  $ProviderElement<SyncEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncEngine create(Ref ref) {
    return syncEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncEngine>(value),
    );
  }
}

String _$syncEngineHash() => r'f130edb8f38d991475591632d9d340b3e5be724a';

@ProviderFor(syncStatus)
final syncStatusProvider = SyncStatusProvider._();

final class SyncStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncStatus?>,
          SyncStatus?,
          Stream<SyncStatus?>
        >
    with $FutureModifier<SyncStatus?>, $StreamProvider<SyncStatus?> {
  SyncStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncStatusHash();

  @$internal
  @override
  $StreamProviderElement<SyncStatus?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SyncStatus?> create(Ref ref) {
    return syncStatus(ref);
  }
}

String _$syncStatusHash() => r'4b6f6356590787c67c949968592d4e3769111e7d';

@ProviderFor(firstPullProgress)
final firstPullProgressProvider = FirstPullProgressProvider._();

final class FirstPullProgressProvider
    extends
        $FunctionalProvider<
          AsyncValue<FirstPullProgress?>,
          FirstPullProgress?,
          Stream<FirstPullProgress?>
        >
    with
        $FutureModifier<FirstPullProgress?>,
        $StreamProvider<FirstPullProgress?> {
  FirstPullProgressProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firstPullProgressProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firstPullProgressHash();

  @$internal
  @override
  $StreamProviderElement<FirstPullProgress?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<FirstPullProgress?> create(Ref ref) {
    return firstPullProgress(ref);
  }
}

String _$firstPullProgressHash() => r'cb7d6418ef449ae199732edca0ae405a84ba33d4';

@ProviderFor(syncMedia)
final syncMediaProvider = SyncMediaProvider._();

final class SyncMediaProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncMedia>,
          SyncMedia,
          FutureOr<SyncMedia>
        >
    with $FutureModifier<SyncMedia>, $FutureProvider<SyncMedia> {
  SyncMediaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncMediaProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncMediaHash();

  @$internal
  @override
  $FutureProviderElement<SyncMedia> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<SyncMedia> create(Ref ref) {
    return syncMedia(ref);
  }
}

String _$syncMediaHash() => r'0b317f71ca75b80c53692a15ef3f3db1bd1b8d26';

@ProviderFor(localJournalWipe)
final localJournalWipeProvider = LocalJournalWipeProvider._();

final class LocalJournalWipeProvider
    extends
        $FunctionalProvider<
          AsyncValue<LocalJournalWipe>,
          LocalJournalWipe,
          FutureOr<LocalJournalWipe>
        >
    with $FutureModifier<LocalJournalWipe>, $FutureProvider<LocalJournalWipe> {
  LocalJournalWipeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localJournalWipeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localJournalWipeHash();

  @$internal
  @override
  $FutureProviderElement<LocalJournalWipe> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LocalJournalWipe> create(Ref ref) {
    return localJournalWipe(ref);
  }
}

String _$localJournalWipeHash() => r'26eb47a24233113d888501a0bc5a1dcb3156ab5d';

@ProviderFor(deviceUnlinkService)
final deviceUnlinkServiceProvider = DeviceUnlinkServiceProvider._();

final class DeviceUnlinkServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeviceUnlinkService>,
          DeviceUnlinkService,
          FutureOr<DeviceUnlinkService>
        >
    with
        $FutureModifier<DeviceUnlinkService>,
        $FutureProvider<DeviceUnlinkService> {
  DeviceUnlinkServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceUnlinkServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceUnlinkServiceHash();

  @$internal
  @override
  $FutureProviderElement<DeviceUnlinkService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DeviceUnlinkService> create(Ref ref) {
    return deviceUnlinkService(ref);
  }
}

String _$deviceUnlinkServiceHash() =>
    r'db3b3fb9a22f886c43d7371c31c0ceb9a1725c6a';

@ProviderFor(journalEraseService)
final journalEraseServiceProvider = JournalEraseServiceProvider._();

final class JournalEraseServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<JournalEraseService>,
          JournalEraseService,
          FutureOr<JournalEraseService>
        >
    with
        $FutureModifier<JournalEraseService>,
        $FutureProvider<JournalEraseService> {
  JournalEraseServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journalEraseServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journalEraseServiceHash();

  @$internal
  @override
  $FutureProviderElement<JournalEraseService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<JournalEraseService> create(Ref ref) {
    return journalEraseService(ref);
  }
}

String _$journalEraseServiceHash() =>
    r'60795681f5ce8b06c56164080a5fb61d3071a4dd';

@ProviderFor(syncNotice)
final syncNoticeProvider = SyncNoticeProvider._();

final class SyncNoticeProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, Stream<String?>>
    with $FutureModifier<String?>, $StreamProvider<String?> {
  SyncNoticeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncNoticeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncNoticeHash();

  @$internal
  @override
  $StreamProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String?> create(Ref ref) {
    return syncNotice(ref);
  }
}

String _$syncNoticeHash() => r'd2a44ca6176944e05289a1a45c8ea206932b97b0';

@ProviderFor(backgroundUploader)
final backgroundUploaderProvider = BackgroundUploaderProvider._();

final class BackgroundUploaderProvider
    extends
        $FunctionalProvider<
          BackgroundUploader,
          BackgroundUploader,
          BackgroundUploader
        >
    with $Provider<BackgroundUploader> {
  BackgroundUploaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundUploaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundUploaderHash();

  @$internal
  @override
  $ProviderElement<BackgroundUploader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackgroundUploader create(Ref ref) {
    return backgroundUploader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackgroundUploader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackgroundUploader>(value),
    );
  }
}

String _$backgroundUploaderHash() =>
    r'8da26076f452774a4813cddf7ac8eb31419beafd';

@ProviderFor(backgroundTransfer)
final backgroundTransferProvider = BackgroundTransferProvider._();

final class BackgroundTransferProvider
    extends
        $FunctionalProvider<
          AsyncValue<BackgroundTransfer?>,
          BackgroundTransfer?,
          FutureOr<BackgroundTransfer?>
        >
    with
        $FutureModifier<BackgroundTransfer?>,
        $FutureProvider<BackgroundTransfer?> {
  BackgroundTransferProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundTransferProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundTransferHash();

  @$internal
  @override
  $FutureProviderElement<BackgroundTransfer?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BackgroundTransfer?> create(Ref ref) {
    return backgroundTransfer(ref);
  }
}

String _$backgroundTransferHash() =>
    r'9ac5f3ad7692f2c9bc8327c1e9865cb73ea8166b';

@ProviderFor(batterySettings)
final batterySettingsProvider = BatterySettingsProvider._();

final class BatterySettingsProvider
    extends
        $FunctionalProvider<BatterySettings, BatterySettings, BatterySettings>
    with $Provider<BatterySettings> {
  BatterySettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'batterySettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$batterySettingsHash();

  @$internal
  @override
  $ProviderElement<BatterySettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BatterySettings create(Ref ref) {
    return batterySettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BatterySettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BatterySettings>(value),
    );
  }
}

String _$batterySettingsHash() => r'3a2f6da26191b4e6036f536b9f26c880e652b292';

@ProviderFor(batteryExempt)
final batteryExemptProvider = BatteryExemptProvider._();

final class BatteryExemptProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  BatteryExemptProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'batteryExemptProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$batteryExemptHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return batteryExempt(ref);
  }
}

String _$batteryExemptHash() => r'8390f502561ddb8a98174d138ed6b492b4d9c5f6';

@ProviderFor(serverAddress)
final serverAddressProvider = ServerAddressProvider._();

final class ServerAddressProvider
    extends $FunctionalProvider<ServerAddress, ServerAddress, ServerAddress>
    with $Provider<ServerAddress> {
  ServerAddressProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverAddressProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverAddressHash();

  @$internal
  @override
  $ProviderElement<ServerAddress> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ServerAddress create(Ref ref) {
    return serverAddress(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServerAddress value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServerAddress>(value),
    );
  }
}

String _$serverAddressHash() => r'c2e0ca3e36bb1b963b14efb135e7eb2ea82a5572';

@ProviderFor(enrolmentService)
final enrolmentServiceProvider = EnrolmentServiceProvider._();

final class EnrolmentServiceProvider
    extends
        $FunctionalProvider<
          EnrolmentService,
          EnrolmentService,
          EnrolmentService
        >
    with $Provider<EnrolmentService> {
  EnrolmentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'enrolmentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$enrolmentServiceHash();

  @$internal
  @override
  $ProviderElement<EnrolmentService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EnrolmentService create(Ref ref) {
    return enrolmentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EnrolmentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EnrolmentService>(value),
    );
  }
}

String _$enrolmentServiceHash() => r'f46b3322a319dc1fb23a14d0d1e15f1b45c89602';

@ProviderFor(restoreService)
final restoreServiceProvider = RestoreServiceProvider._();

final class RestoreServiceProvider
    extends $FunctionalProvider<RestoreService, RestoreService, RestoreService>
    with $Provider<RestoreService> {
  RestoreServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restoreServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restoreServiceHash();

  @$internal
  @override
  $ProviderElement<RestoreService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RestoreService create(Ref ref) {
    return restoreService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RestoreService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RestoreService>(value),
    );
  }
}

String _$restoreServiceHash() => r'4fdbe616218025fb533bec97b1fa226493e2e2af';

@ProviderFor(pairingService)
final pairingServiceProvider = PairingServiceProvider._();

final class PairingServiceProvider
    extends $FunctionalProvider<PairingService, PairingService, PairingService>
    with $Provider<PairingService> {
  PairingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pairingServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pairingServiceHash();

  @$internal
  @override
  $ProviderElement<PairingService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PairingService create(Ref ref) {
    return pairingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PairingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PairingService>(value),
    );
  }
}

String _$pairingServiceHash() => r'4500c4666bdeabcc2c7575aca0390b025f91f890';

@ProviderFor(deviceService)
final deviceServiceProvider = DeviceServiceProvider._();

final class DeviceServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeviceService?>,
          DeviceService?,
          FutureOr<DeviceService?>
        >
    with $FutureModifier<DeviceService?>, $FutureProvider<DeviceService?> {
  DeviceServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceServiceHash();

  @$internal
  @override
  $FutureProviderElement<DeviceService?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DeviceService?> create(Ref ref) {
    return deviceService(ref);
  }
}

String _$deviceServiceHash() => r'e311210db9d94eb47f7b8f46456afe1a59cb14cc';

@ProviderFor(journalDevices)
final journalDevicesProvider = JournalDevicesProvider._();

final class JournalDevicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<JournalDevice>>,
          List<JournalDevice>,
          FutureOr<List<JournalDevice>>
        >
    with
        $FutureModifier<List<JournalDevice>>,
        $FutureProvider<List<JournalDevice>> {
  JournalDevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journalDevicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journalDevicesHash();

  @$internal
  @override
  $FutureProviderElement<List<JournalDevice>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<JournalDevice>> create(Ref ref) {
    return journalDevices(ref);
  }
}

String _$journalDevicesHash() => r'b7aa24bcfd15ecef2c473318c3a4675c1135a205';
