import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NOTICE credits the vendored RNNoise', () {
    final String notice = File('NOTICE').readAsStringSync();
    final int listStart = notice.indexOf('Third-party material');
    expect(listStart, isNot(-1));
    final String thirdParty = notice.substring(listStart);

    expect(
      thirdParty,
      contains(
        '- packages/rnnoise/third_party/rnnoise/: RNNoise 0.2 with upstream '
        'commit 372f7b4, by Jean-Marc Valin, the Xiph.Org Foundation, '
        'Mozilla, Amazon and contributors, under the BSD 3-Clause License '
        '(packages/rnnoise/LICENSE)',
      ),
    );
    expect(thirdParty, contains('packages/rnnoise/third_party/rnnoise'));
    expect(thirdParty, contains('the Xiph.Org Foundation'));
    expect(thirdParty, contains('BSD 3-Clause License'));

    final File license = File('packages/rnnoise/LICENSE');
    expect(license.existsSync(), isTrue);
    expect(
      license.readAsStringSync().split('\n'),
      contains('Copyright (c) 2005-2017, Xiph.Org Foundation'),
    );
  });
}
