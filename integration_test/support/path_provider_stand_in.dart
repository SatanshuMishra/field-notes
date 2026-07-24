import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'sandbox_path_provider.dart';

Future<void> _deleteIfExists(Directory directory) async {
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}

Future<Directory> installPathProviderStandIn({
  required String prefix,
  required String label,
}) async {
  if (prefix.trim().isEmpty) {
    throw ArgumentError.value(
      prefix,
      'prefix',
      'path provider stand-in prefix must not be empty',
    );
  }
  if (label.trim().isEmpty) {
    throw ArgumentError.value(
      label,
      'label',
      'path provider stand-in label must not be empty',
    );
  }

  final Directory standInRoot =
      await Directory.systemTemp.createTemp('$prefix-$label-');
  addTearDown(() => _deleteIfExists(standInRoot));
  final SandboxPathProviderInstallation installation =
      installSandboxPathProvider(standInRoot);
  addTearDown(() => restorePathProviderPlatform(installation));

  final Directory documents = await getApplicationDocumentsDirectory();
  expect(p.isWithin(standInRoot.path, documents.path), isTrue);
  return documents;
}
