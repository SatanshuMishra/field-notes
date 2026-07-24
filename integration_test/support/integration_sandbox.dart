import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:path/path.dart' as p;

class IntegrationSandbox {
  IntegrationSandbox._({
    required this.root,
    required this.database,
    required this.mediaRoot,
  });

  static Future<IntegrationSandbox> create(String label) async {
    if (label.trim().isEmpty) {
      throw ArgumentError.value(
        label,
        'label',
        'integration sandbox label must not be empty',
      );
    }
    final Directory root = await Directory.systemTemp.createTemp(
      'field-notes-integ-$label-',
    );
    final Directory mediaRoot = Directory(p.join(root.path, mediaSubdir));
    await mediaRoot.create(recursive: true);
    return IntegrationSandbox._(
      root: root,
      database: AppDatabase(NativeDatabase.memory()),
      mediaRoot: mediaRoot,
    );
  }

  final Directory root;
  final AppDatabase database;
  final Directory mediaRoot;

  Future<void>? _disposal;

  List<Override> get overrides => <Override>[
        databaseProvider.overrideWithValue(database),
        mediaRootProvider.overrideWith((Ref ref) async => mediaRoot),
      ];

  ProviderContainer createContainer({
    List<Override> extraOverrides = const <Override>[],
  }) {
    return ProviderContainer(
      retry: (_, _) => null,
      overrides: <Override>[...overrides, ...extraOverrides],
    );
  }

  Future<void> dispose() => _disposal ??= _disposeOnce();

  Future<void> _disposeOnce() async {
    await database.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}
