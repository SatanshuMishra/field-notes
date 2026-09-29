import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Appearance.fromId reads light, dark and system and nothing else', () {
    expect(Appearance.fromId('light'), Appearance.light);
    expect(Appearance.fromId('dark'), Appearance.dark);
    expect(Appearance.fromId('system'), Appearance.system);
    expect(Appearance.fromId(null), isNull);
    expect(Appearance.fromId(''), isNull);
    expect(Appearance.fromId('sepia'), isNull);
    expect(Appearance.fromId('Dark'), isNull);
    expect(Appearance.values.map((Appearance value) => value.id), <String>[
      'light',
      'dark',
      'system',
    ]);
  });

  test('AppSettings defaults to the light appearance', () {
    expect(AppSettings.defaults.appearance, Appearance.light);

    final AppSettings dark = AppSettings.defaults.copyWith(
      appearance: Appearance.dark,
    );

    expect(dark.appearance, Appearance.dark);
    expect(dark, isNot(AppSettings.defaults));
    expect(dark.copyWith(), dark);
    expect(dark.hashCode, dark.copyWith().hashCode);
    expect(dark.toString(), contains('appearance: Appearance.dark'));
    expect(dark.copyWith(soundEnabled: false).appearance, Appearance.dark);
  });
}
