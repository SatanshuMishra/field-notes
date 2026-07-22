import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CustomException implements Exception {
  const _CustomException();
}

final _throwsError =
    FutureProvider<int>((ref) async => throw StateError('err'));
final _throwsException =
    FutureProvider<int>((ref) async => throw const _CustomException());
final _throwsMissingPlugin =
    FutureProvider<int>((ref) async => throw MissingPluginException('x'));

Future<String> _classify(Future<Object?> Function() run) async {
  try {
    await run().timeout(const Duration(seconds: 2));
    return 'COMPLETED';
  } on TimeoutException {
    return 'HANG';
  } catch (e) {
    return 'THREW ${e.runtimeType}';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MECHANISM: Riverpod auto-retry holds .future pending for a thrown '
      'Exception (not Error); disabling retry makes it propagate', () async {
    ProviderContainer make({bool retry = true}) {
      final c = ProviderContainer(
        retry: retry ? null : (_, _) => null,
      );
      addTearDown(c.dispose);
      return c;
    }

    final errorOutcome = await _classify(() => make().read(_throwsError.future));
    final exceptionOutcome =
        await _classify(() => make().read(_throwsException.future));
    final missingPluginOutcome =
        await _classify(() => make().read(_throwsMissingPlugin.future));
    final exceptionNoRetry = await _classify(
        () => make(retry: false).read(_throwsException.future));

    debugPrint('MECHANISM Error=$errorOutcome Exception=$exceptionOutcome '
        'MissingPlugin=$missingPluginOutcome '
        'ExceptionNoRetry=$exceptionNoRetry');

    expect(errorOutcome, startsWith('THREW'));
    expect(exceptionOutcome, 'HANG');
    expect(missingPluginOutcome, 'HANG');
    expect(exceptionNoRetry, startsWith('THREW'));
  });

  test('FIX: with retry disabled (the app ProviderScope config), a platform '
      'Exception in the capture chain surfaces a bounded error instead of '
      'hanging under "Saving..."', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    Object? error;
    var timedOut = false;
    try {
      await container
          .read(captureServiceProvider.future)
          .timeout(const Duration(seconds: 4));
    } on TimeoutException {
      timedOut = true;
    } catch (e) {
      error = e;
    }

    debugPrint('FIX timedOut=$timedOut error=${error?.runtimeType}');

    expect(timedOut, isFalse,
        reason: 'save must not hang once retry is neutralized');
    expect(error, isNotNull,
        reason: 'the platform Exception must propagate to the composer');
  });

  test('PERSIST: full note-save Dart path persists an entry when the platform '
      'boundary is provided (file DB + real media dir)', () async {
    final tmp = await Directory.systemTemp.createTemp('fn_control');
    addTearDown(() => tmp.delete(recursive: true));
    final db = AppDatabase(
      NativeDatabase.createInBackground(File('${tmp.path}/fn.sqlite')),
    );
    addTearDown(db.close);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        databaseProvider.overrideWithValue(db),
        mediaRootProvider.overrideWith((ref) async => Directory('${tmp.path}/m')),
      ],
    );
    addTearDown(container.dispose);

    final service = await container.read(captureServiceProvider.future);
    final result = await service
        .capture(TextCaptureRequest(date: '2026-07-21', text: 'control'));
    final row = await (db.select(db.entries)
          ..where((t) => t.id.equals(result.entry.id)))
        .getSingleOrNull();

    expect(row, isNotNull);
    expect(row!.textContent, 'control');
  });
}
