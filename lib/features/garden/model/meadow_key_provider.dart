import 'dart:math';

import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'meadow_key_provider.g.dart';

final int _sessionMeadowKey = Random.secure().nextInt(1 << 32);

@Riverpod(keepAlive: true)
Future<int> meadowKey(Ref ref) async {
  try {
    return await ref.watch(settingsRepositoryProvider).meadowKey();
  } catch (error) {
    debugPrint('Could not keep the meadow key: $error');
    return _sessionMeadowKey;
  }
}
