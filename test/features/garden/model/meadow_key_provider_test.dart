import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../settings/support/fake_settings_repository.dart';

void main() {
  test('a failed save still gives a key for this session', () async {
    final int first = await _readMeadowKey(
      FakeSettingsRepository(failMeadowKey: true),
    );
    final int second = await _readMeadowKey(
      FakeSettingsRepository(failMeadowKey: true),
    );

    expect(first, inInclusiveRange(0, 4294967295));
    expect(second, first);
  });

  test('a later launch asks the settings for the key again', () async {
    await _readMeadowKey(FakeSettingsRepository(failMeadowKey: true));

    expect(await _readMeadowKey(FakeSettingsRepository(meadowKey: 7)), 7);
  });
}

Future<int> _readMeadowKey(SettingsRepository settings) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      settingsRepositoryProvider.overrideWithValue(settings),
      journalSettingChangesProvider.overrideWith(
        (Ref ref) => const Stream<Map<String, String>>.empty(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(meadowKeyProvider.future);
}
