// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(database)
final databaseProvider = DatabaseProvider._();

final class DatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  DatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return database(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$databaseHash() => r'1379a860768fcad4b90eb85e30508800f4d68e44';

@ProviderFor(changeRecorder)
final changeRecorderProvider = ChangeRecorderProvider._();

final class ChangeRecorderProvider
    extends $FunctionalProvider<ChangeRecorder, ChangeRecorder, ChangeRecorder>
    with $Provider<ChangeRecorder> {
  ChangeRecorderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'changeRecorderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$changeRecorderHash();

  @$internal
  @override
  $ProviderElement<ChangeRecorder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChangeRecorder create(Ref ref) {
    return changeRecorder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChangeRecorder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChangeRecorder>(value),
    );
  }
}

String _$changeRecorderHash() => r'f1969355e662578cf44f8fe2ee9a4da6bedd5bde';
