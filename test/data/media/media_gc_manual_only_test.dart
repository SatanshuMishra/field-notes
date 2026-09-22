import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('only the Reclaim space controller calls collectGarbage in lib', () {
    final Directory lib = Directory('lib');
    final RegExp callSite = RegExp(r'(?<!Future<int>\s)\bcollectGarbage\b');

    final Map<String, int> callers = <String, int>{};
    for (final FileSystemEntity entity
        in lib.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      if (!entity.path.endsWith('.dart') || entity.path.endsWith('.g.dart')) {
        continue;
      }
      final String contents = entity.readAsStringSync();
      final int calls = callSite.allMatches(contents).length;
      if (calls > 0) {
        callers[p.posix.joinAll(p.split(entity.path))] = calls;
      }
    }

    expect(
      callers,
      <String, int>{
        'lib/features/settings/journal_data_controller.dart': 1,
        'lib/data/media/filesystem_media_store.dart': 1,
      },
    );
  });
}
