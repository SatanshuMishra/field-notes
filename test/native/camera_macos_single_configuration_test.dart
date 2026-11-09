import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _pluginSource =
    'third_party/camera_macos/macos/camera_macos/Sources/camera_macos/CameraMacosPlugin.swift';
const String _localModifications =
    'third_party/camera_macos/LOCAL_MODIFICATIONS.md';

String _readExisting(String path) {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  return file.readAsStringSync();
}

String _functionBody(String source, String signature) {
  final int start = source.indexOf(signature);
  expect(start, isNot(-1), reason: '$signature is missing');
  final int open = source.indexOf('{', start + signature.length);
  int depth = 0;
  for (int index = open; index < source.length; index++) {
    final String character = source[index];
    if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(open + 1, index);
      }
    }
  }
  fail('$signature has no closing brace');
}

List<String> _numberedDeltaItems(String markdown) {
  final int delta = markdown.indexOf('## Delta');
  expect(
    delta,
    isNot(-1),
    reason: 'LOCAL_MODIFICATIONS.md has no Delta section',
  );
  return markdown
      .substring(delta)
      .split(RegExp(r'\n(?=\d+\. )'))
      .where((String part) => RegExp(r'^\d+\. ').hasMatch(part))
      .toList();
}

void main() {
  test('no preview layer is created when the Mac camera opens', () {
    final String plugin = _readExisting(_pluginSource);
    final String initCamera = _functionBody(
      plugin,
      'func initCamera(_ arguments: Dictionary<String, Any>, _ result: @escaping FlutterResult)',
    );

    expect(
      initCamera,
      contains('startRunning()'),
      reason: 'initCamera no longer starts the capture session',
    );
    expect(initCamera, isNot(contains('AVCaptureVideoPreviewLayer(')));
  });

  test('local modifications names the preview layer removal', () {
    final String markdown = _readExisting(_localModifications);

    final List<String> items = _numberedDeltaItems(markdown);

    expect(
      items.where(
        (String item) =>
            item.contains('initCamera') &&
            item.contains('AVCaptureVideoPreviewLayer'),
      ),
      isNotEmpty,
      reason: 'no delta item names initCamera and AVCaptureVideoPreviewLayer',
    );
  });
}
