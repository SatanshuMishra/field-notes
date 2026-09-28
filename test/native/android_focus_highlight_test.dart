import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _mainActivity =
    'android/app/src/main/kotlin/dev/satanshumishra/field_notes/MainActivity.kt';

final RegExp _guardedHighlightOff = RegExp(
  r'if\s*\(\s*Build\.VERSION\.SDK_INT\s*>=\s*Build\.VERSION_CODES\.O\s*\)\s*\{[^{}]*'
  r'findViewById<View>\(\s*FLUTTER_VIEW_ID\s*\)\??\.'
  r'(defaultFocusHighlightEnabled\s*=\s*false|setDefaultFocusHighlightEnabled\(\s*false\s*\))'
  r'[^{}]*\}',
);

String _onCreateBody(String kotlin) {
  final int start = kotlin.indexOf('override fun onCreate(');
  expect(start, isNot(-1), reason: 'MainActivity overrides no onCreate');
  final int end = kotlin.indexOf(
    RegExp(r'\bfun\s'),
    start + 'override fun'.length,
  );
  return kotlin.substring(start, end == -1 ? kotlin.length : end);
}

void main() {
  test(
    'the Flutter view does not draw the Android default focus highlight',
    () {
      final String onCreate = _onCreateBody(
        File(_mainActivity).readAsStringSync(),
      );
      final int superCall = onCreate.indexOf('super.onCreate(');
      final Match? guarded = _guardedHighlightOff.firstMatch(onCreate);
      expect(
        superCall,
        isNot(-1),
        reason: 'onCreate never calls super.onCreate',
      );
      expect(
        guarded,
        isNotNull,
        reason:
            'onCreate never turns off the default focus highlight on '
            'FLUTTER_VIEW_ID inside an Android 8 (API 26) check',
      );
      expect(superCall, lessThan(guarded!.start));
    },
  );
}
