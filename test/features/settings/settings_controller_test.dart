import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/settings_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_settings_repository.dart';

void main() {
  group('SettingsController', () {
    test('writes the daily reminder toggle through the repository', () async {
      final FakeSettingsRepository repository = FakeSettingsRepository();
      final SettingsController controller =
          SettingsController(repository: repository);

      final SettingsWriteResult result =
          await controller.setReminderEnabled(false);

      expect(result, isA<SettingsWriteSucceeded>());
      expect(repository.reminderEnabledWrites, <bool>[false]);
    });

    test('writes the reminder time, sound, and week start', () async {
      final FakeSettingsRepository repository = FakeSettingsRepository();
      final SettingsController controller =
          SettingsController(repository: repository);

      await controller
          .setReminderTime(const ReminderTime(hour: 7, minute: 5));
      await controller.setSoundEnabled(false);
      await controller.setWeekStart(WeekStart.monday);

      expect(
        repository.reminderTimeWrites,
        <ReminderTime>[const ReminderTime(hour: 7, minute: 5)],
      );
      expect(repository.soundEnabledWrites, <bool>[false]);
      expect(repository.weekStartWrites, <WeekStart>[WeekStart.monday]);
    });

    test('maps a slider value to a text size before writing', () async {
      final FakeSettingsRepository repository = FakeSettingsRepository();
      final SettingsController controller =
          SettingsController(repository: repository);

      final SettingsWriteResult result = await controller.setTextSize(3);

      expect(result, isA<SettingsWriteSucceeded>());
      expect(repository.textSizeWrites, <TextSize>[TextSize.large]);
    });

    test('refuses an out-of-range text size without writing', () async {
      final FakeSettingsRepository repository = FakeSettingsRepository();
      final SettingsController controller =
          SettingsController(repository: repository);

      final SettingsWriteResult result = await controller.setTextSize(9);

      expect(
        result,
        isA<SettingsWriteFailed>().having(
          (SettingsWriteFailed f) => f.message,
          'message',
          'That text size is not supported.',
        ),
      );
      expect(repository.textSizeWrites, isEmpty);
    });

    test('turns a repository failure into a user-facing message', () async {
      final FakeSettingsRepository repository =
          FakeSettingsRepository(writeError: StateError('disk full'));
      final List<Object> reported = <Object>[];
      final SettingsController controller = SettingsController(
        repository: repository,
        onError: (Object error, StackTrace _) => reported.add(error),
      );

      final SettingsWriteResult result =
          await controller.setSoundEnabled(true);

      expect(
        result,
        isA<SettingsWriteFailed>().having(
          (SettingsWriteFailed f) => f.message,
          'message',
          'Could not save your sound setting.',
        ),
      );
      expect(reported, hasLength(1));
    });
  });

  test('settingsControllerProvider writes through the app repository',
      () async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(settingsControllerProvider).setWeekStart(
          WeekStart.monday,
        );

    expect(repository.weekStartWrites, <WeekStart>[WeekStart.monday]);
  });
}
