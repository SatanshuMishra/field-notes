import 'package:field_notes/domain/settings/settings.dart';

typedef SettingsErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
);

sealed class SettingsWriteResult {
  const SettingsWriteResult();
}

class SettingsWriteSucceeded extends SettingsWriteResult {
  const SettingsWriteSucceeded();
}

class SettingsWriteFailed extends SettingsWriteResult {
  const SettingsWriteFailed(this.message);

  final String message;
}

class SettingsController {
  const SettingsController({
    required this._repository,
    this._onError,
  });

  final SettingsRepository _repository;
  final SettingsErrorHandler? _onError;

  Future<SettingsWriteResult> setReminderEnabled(bool value) {
    return _write(
      () => _repository.setReminderEnabled(value),
      'Could not save your daily reminder setting.',
    );
  }

  Future<SettingsWriteResult> setReminderTime(ReminderTime value) {
    return _write(
      () => _repository.setReminderTime(value),
      'Could not save your reminder time.',
    );
  }

  Future<SettingsWriteResult> setSoundEnabled(bool value) {
    return _write(
      () => _repository.setSoundEnabled(value),
      'Could not save your sound setting.',
    );
  }

  Future<SettingsWriteResult> setTextSize(int sliderValue) {
    final TextSize? size = TextSize.fromValue(sliderValue);
    if (size == null) {
      return Future<SettingsWriteResult>.value(
        const SettingsWriteFailed('That text size is not supported.'),
      );
    }
    return _write(
      () => _repository.setTextSize(size),
      'Could not save your text size.',
    );
  }

  Future<SettingsWriteResult> setWeekStart(WeekStart value) {
    return _write(
      () => _repository.setWeekStart(value),
      'Could not save your week start.',
    );
  }

  Future<SettingsWriteResult> setSpellCheckEnabled(bool value) {
    return _write(
      () => _repository.setSpellCheckEnabled(value),
      'Could not save your spell check setting.',
    );
  }

  Future<SettingsWriteResult> _write(
    Future<void> Function() action,
    String failureMessage,
  ) async {
    try {
      await action();
      return const SettingsWriteSucceeded();
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
      return SettingsWriteFailed(failureMessage);
    }
  }
}
