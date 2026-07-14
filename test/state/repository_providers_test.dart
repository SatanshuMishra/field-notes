import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'state_test_support.dart';

void main() {
  group('journalRepositoryProvider', () {
    test('yields a repository backed by the injected database', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);

      final repo = container.read(journalRepositoryProvider);
      expect(repo, isA<JournalRepository>());

      final created = await repo.createDay(date: '2026-07-14');
      final loaded = await repo.activeDayForDate('2026-07-14');
      expect(loaded?.id, created.id);
    });

    test('is a keepAlive singleton within one container', () {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);

      expect(
        container.read(journalRepositoryProvider),
        same(container.read(journalRepositoryProvider)),
      );
    });
  });

  group('settingsRepositoryProvider', () {
    test('yields a settings repository backed by the injected database',
        () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);

      final repo = container.read(settingsRepositoryProvider);
      expect(repo, isA<SettingsRepository>());

      await repo.setTextSize(TextSize.large);
      expect((await repo.load()).textSize, TextSize.large);
    });
  });
}
