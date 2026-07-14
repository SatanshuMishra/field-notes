import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase newTestDatabase() => AppDatabase(NativeDatabase.memory());

ProviderContainer newTestContainer(
  AppDatabase db, {
  List<Override> overrides = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}
