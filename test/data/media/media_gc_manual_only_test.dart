import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('only the Reclaim space controller calls collectGarbage in lib', () {
    final Directory lib = Directory('lib');
    final RegExp callSite = RegExp(r'\.collectGarbage\(');

    final Set<String> callers = <String>{};
    for (final FileSystemEntity entity
        in lib.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      if (!entity.path.endsWith('.dart') || entity.path.endsWith('.g.dart')) {
        continue;
      }
      final String contents = entity.readAsStringSync();
      if (callSite.hasMatch(contents)) {
        callers.add(p.posix.joinAll(p.split(entity.path)));
      }
    }

    expect(
      callers,
      <String>{
        'lib/features/settings/journal_data_controller.dart',
        'lib/data/media/filesystem_media_store.dart',
      },
    );
  });
}
