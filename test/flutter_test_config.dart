import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, List<String>> _fontFamilies = <String, List<String>>{
  'Newsreader': <String>[
    'assets/fonts/Newsreader-Variable.ttf',
    'assets/fonts/Newsreader-Italic-Variable.ttf',
  ],
  'Instrument Sans': <String>['assets/fonts/InstrumentSans-Variable.ttf'],
  'Caveat': <String>['assets/fonts/Caveat-Variable.ttf'],
};

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final MapEntry<String, List<String>> family in _fontFamilies.entries) {
    final FontLoader loader = FontLoader(family.key);
    for (final String asset in family.value) {
      loader.addFont(
        File(asset).readAsBytes().then(
              (Uint8List bytes) => ByteData.view(bytes.buffer),
            ),
      );
    }
    await loader.load();
  }
  return testMain();
}
