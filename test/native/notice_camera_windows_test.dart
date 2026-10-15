import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NOTICE credits the vendored camera_windows', () {
    final String notice = File('NOTICE').readAsStringSync();
    final int listStart = notice.indexOf('Third-party material');
    expect(listStart, isNot(-1));
    final String thirdParty = notice.substring(listStart);

    expect(
      thirdParty,
      contains(
        '- third_party/camera_windows/: a copy of camera_windows 0.3.0 by the '
        'Flutter authors, under the BSD 3-Clause License '
        '(third_party/camera_windows/LICENSE), changed to record from the '
        'chosen microphone',
      ),
    );
    expect(thirdParty, contains('third_party/camera_windows/'));
    expect(thirdParty, contains('the Flutter authors'));
    expect(thirdParty, contains('BSD 3-Clause License'));
    expect(
      thirdParty,
      contains('third_party/camera_windows/LOCAL_MODIFICATIONS.md'),
    );

    final File license = File('third_party/camera_windows/LICENSE');
    expect(license.existsSync(), isTrue);
    expect(
      license.readAsStringSync(),
      contains('Copyright 2013 The Flutter Authors'),
    );
  });
}
