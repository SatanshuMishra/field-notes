import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_providers.g.dart';

const Map<TextSize, double> _textScaleBySize = <TextSize, double>{
  TextSize.small: 0.9,
  TextSize.medium: 1.0,
  TextSize.large: 1.15,
};

@riverpod
Stream<AppSettings> appSettings(Ref ref) {
  return ref.watch(settingsRepositoryProvider).watch();
}

@riverpod
double textScale(Ref ref) {
  final settings =
      ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
  return _textScaleBySize[settings.textSize] ?? 1.0;
}

@riverpod
WeekStart weekStart(Ref ref) {
  final settings =
      ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
  return settings.weekStart;
}

@riverpod
bool spellCheckEnabled(Ref ref) {
  final AppSettings settings =
      ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
  return settings.spellCheckEnabled;
}
