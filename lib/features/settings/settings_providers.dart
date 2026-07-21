import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'settings_controller.dart';

part 'settings_providers.g.dart';

@Riverpod(keepAlive: true)
SettingsController settingsController(Ref ref) {
  return SettingsController(
    repository: ref.watch(settingsRepositoryProvider),
    onError: (Object error, StackTrace _) =>
        debugPrint('Settings write failed: $error'),
  );
}
