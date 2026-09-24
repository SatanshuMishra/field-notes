import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the old float plan and wrap block tests are retired', () {
    expect(
      File('test/features/notes/render/note_photo_plan_test.dart').existsSync(),
      isFalse,
    );
    expect(
      File('test/features/notes/render/photo_wrap_block_test.dart').existsSync(),
      isFalse,
    );
  });
}
