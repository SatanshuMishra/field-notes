import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'state_test_support.dart';

void main() {
  group('databaseProvider', () {
    test('yields the injected database instance', () {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);

      expect(container.read(databaseProvider), same(db));
    });

    test('all data providers share one database via the override seam', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);

      final viaProvider = container.read(databaseProvider);
      await viaProvider.into(viaProvider.settings).insert(
            SettingsCompanion.insert(key: 'probe', value: 'v1'),
          );

      final rows = await db.select(db.settings).get();
      expect(rows.single.value, 'v1');
    });
  });
}
