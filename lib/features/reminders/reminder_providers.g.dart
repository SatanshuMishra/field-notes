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

String _$reminderSyncHash() => r'06a46fc24e28604d79264385bab6876b2202cad2';
