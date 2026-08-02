@Tags(<String>['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const String _probe = 'Handgloves quickly 0123456789';
const double _probeFontSize = 32;
const String _probeFamily = 'Instrument Sans';
const double _ahemTolerance = 0.01;

void main() {
  test('the vendored sans loads instead of falling back to the test font', () {
    final TextPainter painter = TextPainter(
      text: const TextSpan(
        text: _probe,
        style: TextStyle(
          fontFamily: _probeFamily,
          fontSize: _probeFontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    expect(
      painter.width,
      isNot(closeTo(_probe.length * _probeFontSize, _ahemTolerance)),
    );
  });
}
