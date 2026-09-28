// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reminderClock)
final reminderClockProvider = ReminderClockProvider._();

final class ReminderClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  ReminderClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return reminderClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$reminderClockHash() => r'487cf70baca1d734c2674f9fafa77f1f394b1bcf';

@ProviderFor(reminderScheduler)
final reminderSchedulerProvider = ReminderSchedulerProvider._();

final class ReminderSchedulerProvider
    extends
        $FunctionalProvider<
          ReminderScheduler,
          ReminderScheduler,
          ReminderScheduler
        >
    with $Provider<ReminderScheduler> {
  ReminderSchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderSchedulerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderSchedulerHash();

  @$internal
  @override
  $ProviderElement<ReminderScheduler> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReminderScheduler create(Ref ref) {
    return reminderScheduler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReminderScheduler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReminderScheduler>(value),
    );
  }
}

String _$reminderSchedulerHash() => r'a6e729e7974386505e81d2b0c35b7d39e324905b';

@ProviderFor(reminderCoordinator)
final reminderCoordinatorProvider = ReminderCoordinatorProvider._();

final class ReminderCoordinatorProvider
    extends
        $FunctionalProvider<
          ReminderCoordinator,
          ReminderCoordinator,
          ReminderCoordinator
        >
    with $Provider<ReminderCoordinator> {
  ReminderCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderCoordinatorHash();

  @$internal
  @override
  $ProviderElement<ReminderCoordinator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReminderCoordinator create(Ref ref) {
    return reminderCoordinator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReminderCoordinator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReminderCoordinator>(value),
    );
  }
}

String _$reminderCoordinatorHash() =>
    r'f0c92a742afb3b41c73a9a2b22e8445f53840aa4';

@ProviderFor(reminderSync)
final reminderSyncProvider = ReminderSyncProvider._();

final class ReminderSyncProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReminderSyncResult?>,
          ReminderSyncResult?,
          FutureOr<ReminderSyncResult?>
        >
    with
        $FutureModifier<ReminderSyncResult?>,
        $FutureProvider<ReminderSyncResult?> {
  ReminderSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderSyncHash();

  @$internal
  @override
  $FutureProviderElement<ReminderSyncResult?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReminderSyncResult?> create(Ref ref) {
    return reminderSync(ref);
  }
}

String _$reminderSyncHash() => r'41f0a31480613186587e6c1925d3217e5b37c9bc';

@ProviderFor(notificationSettingsOpener)
final notificationSettingsOpenerProvider =
    NotificationSettingsOpenerProvider._();

final class NotificationSettingsOpenerProvider
    extends
        $FunctionalProvider<
          NotificationSettingsOpener,
          NotificationSettingsOpener,
          NotificationSettingsOpener
        >
    with $Provider<NotificationSettingsOpener> {
  NotificationSettingsOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationSettingsOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationSettingsOpenerHash();

  @$internal
  @override
  $ProviderElement<NotificationSettingsOpener> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationSettingsOpener create(Ref ref) {
    return notificationSettingsOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationSettingsOpener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationSettingsOpener>(value),
    );
  }
}

String _$notificationSettingsOpenerHash() =>
    r'86de92dd1fc8cc823958d2130502d62ebee1a06e';

@ProviderFor(ReminderPermissionStatus)
final reminderPermissionStatusProvider = ReminderPermissionStatusProvider._();

final class ReminderPermissionStatusProvider
    extends
        $AsyncNotifierProvider<ReminderPermissionStatus, ReminderPermission> {
  ReminderPermissionStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderPermissionStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderPermissionStatusHash();

  @$internal
  @override
  ReminderPermissionStatus create() => ReminderPermissionStatus();
}

String _$reminderPermissionStatusHash() =>
    r'aed049fb05fefff51ed059627a71faf5d4cec629';

abstract class _$ReminderPermissionStatus
    extends $AsyncNotifier<ReminderPermission> {
  FutureOr<ReminderPermission> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ReminderPermission>, ReminderPermission>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ReminderPermission>, ReminderPermission>,
              AsyncValue<ReminderPermission>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
