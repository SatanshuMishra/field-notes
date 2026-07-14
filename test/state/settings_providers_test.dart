import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'state_test_support.dart';

void main() {
  group('settings-backed providers', () {
    test('textScale starts at the medium default then tracks changes',
        () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);
      final settings = container.read(settingsRepositoryProvider);

      final sub = container.listen(textScaleProvider, (_, _) {},
          fireImmediately: true);
      addTearDown(sub.close);

      await pumpEventQueue();
      expect(container.read(textScaleProvider), 1.0);

      await settings.setTextSize(TextSize.large);
      await pumpEventQueue();
      expect(container.read(textScaleProvider), 1.15);

      await settings.setTextSize(TextSize.small);
      await pumpEventQueue();
      expect(container.read(textScaleProvider), 0.9);
    });

    test('weekStart starts at Sunday then tracks changes', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);
      final settings = container.read(settingsRepositoryProvider);

      final sub = container.listen(weekStartProvider, (_, _) {},
          fireImmediately: true);
      addTearDown(sub.close);

      await pumpEventQueue();
      expect(container.read(weekStartProvider), WeekStart.sunday);

      await settings.setWeekStart(WeekStart.monday);
      await pumpEventQueue();
      expect(container.read(weekStartProvider), WeekStart.monday);
    });

    test('appSettings emits defaults then the updated settings', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);
      final settings = container.read(settingsRepositoryProvider);

      final sub = container.listen(appSettingsProvider, (_, _) {},
          fireImmediately: true);
      addTearDown(sub.close);

      await pumpEventQueue();
      expect(
        container.read(appSettingsProvider).value,
        AppSettings.defaults,
      );

      await settings.setWeekStart(WeekStart.monday);
      await pumpEventQueue();
      expect(
        container.read(appSettingsProvider).value?.weekStart,
        WeekStart.monday,
      );
    });
  });
}
