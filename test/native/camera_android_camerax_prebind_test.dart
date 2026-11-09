import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _appPubspec = 'pubspec.yaml';
const String _vendoredDirectory = 'third_party/camera_android_camerax';
const String _vendoredPubspec =
    'third_party/camera_android_camerax/pubspec.yaml';
const String _pluginSource =
    'third_party/camera_android_camerax/lib/src/android_camera_camerax.dart';
const String _localModifications =
    'third_party/camera_android_camerax/LOCAL_MODIFICATIONS.md';

String _readExisting(String path) {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  return file.readAsStringSync();
}

int _skipLiteralOrComment(String source, int index) {
  final String character = source[index];
  if (character == '/' &&
      index + 1 < source.length &&
      source[index + 1] == '/') {
    final int end = source.indexOf('\n', index);
    return end == -1 ? source.length : end;
  }
  if (character == "'" || character == '"') {
    for (int cursor = index + 1; cursor < source.length; cursor++) {
      if (source[cursor] == r'\') {
        cursor++;
      } else if (source[cursor] == character) {
        return cursor;
      }
    }
    fail('unterminated string literal at $index');
  }
  return index;
}

int _matchingClose(String source, int open, String opener, String closer) {
  int depth = 0;
  for (int index = open; index < source.length; index++) {
    final int skipped = _skipLiteralOrComment(source, index);
    if (skipped != index) {
      index = skipped;
      continue;
    }
    final String character = source[index];
    if (character == opener) {
      depth++;
    } else if (character == closer) {
      depth--;
      if (depth == 0) {
        return index;
      }
    }
  }
  fail('no closing $closer for the $opener at $open');
}

String _methodBody(String source, String signature) {
  final int start = source.indexOf(signature);
  expect(start, isNot(-1), reason: '$signature is missing');
  final int parametersOpen = source.indexOf('(', start + signature.length - 1);
  final int parametersClose = _matchingClose(source, parametersOpen, '(', ')');
  final int bodyOpen = source.indexOf('{', parametersClose);
  final int bodyClose = _matchingClose(source, bodyOpen, '{', '}');
  return source.substring(bodyOpen + 1, bodyClose);
}

List<String> _firstBindToLifecycleList(String body) {
  final int call = body.indexOf('bindToLifecycle(');
  expect(call, isNot(-1), reason: 'initializeCamera binds nothing');
  final int listStart = body.indexOf('<UseCase>[', call);
  expect(
    listStart,
    isNot(-1),
    reason: 'the first bindToLifecycle call has no <UseCase>[ list',
  );
  final int open = listStart + '<UseCase>'.length;
  final int close = _matchingClose(body, open, '[', ']');
  return body
      .substring(open + 1, close)
      .split(',')
      .map((String entry) => entry.trim())
      .where((String entry) => entry.isNotEmpty)
      .toList();
}

String _overridePath(String pubspec, String package) {
  final RegExpMatch? section = RegExp(
    r'^dependency_overrides:\s*\n((?:[ \t]+.*\n|[ \t]*\n)*)',
    multiLine: true,
  ).firstMatch(pubspec);
  expect(
    section,
    isNotNull,
    reason: 'pubspec.yaml has no dependency_overrides',
  );
  final RegExpMatch? entry = RegExp(
    '^  $package:[ \\t]*\\n[ \\t]+path:[ \\t]*(\\S+)[ \\t]*\$',
    multiLine: true,
  ).firstMatch(section!.group(1)!);
  expect(
    entry,
    isNotNull,
    reason: 'dependency_overrides has no path entry for $package',
  );
  return entry!.group(1)!;
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
  test('the app builds with the vendored camerax plugin at 0.7.5', () {
    final String pubspec = _readExisting(_appPubspec);
    final String vendored = _readExisting(_vendoredPubspec);

    final String overridePath = _overridePath(
      pubspec,
      'camera_android_camerax',
    );
    final RegExpMatch? name = RegExp(
      r'^name:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(vendored);
    final RegExpMatch? version = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(vendored);

    expect(overridePath, _vendoredDirectory);
    expect(name?.group(1), 'camera_android_camerax');
    expect(version?.group(1), '0.7.5');
  });

  test('the camera opens with preview, still capture and video capture bound together', () {
    final String source = _readExisting(_pluginSource);
    final String body = _methodBody(source, 'Future<void> initializeCamera(');

    final List<String> bound = _firstBindToLifecycleList(body);

    expect(bound, contains('preview!'));
    expect(bound, contains('imageCapture!'));
    expect(bound, contains('videoCapture!'));
    expect(bound, isNot(contains('imageAnalysis!')));
  });

  test('stopping a take leaves video capture bound', () {
    final String source = _readExisting(_pluginSource);
    final String body = _methodBody(
      source,
      'Future<XFile> stopVideoRecording(',
    );

    expect(
      body.replaceAll(RegExp(r'\s+'), ''),
      isNot(contains('_unbindUseCaseFromLifecycle(videoCapture!)')),
    );
  });

  test('every take uses the screen rotation unless the orientation is locked', () {
    final String source = _readExisting(_pluginSource);
    final String body = _methodBody(
      source,
      'Future<void> startVideoCapturing(',
    );

    expect(
      body.replaceAll(RegExp(r'\s+'), ''),
      contains('if(!captureOrientationLocked){awaitvideoCapture!.setTargetRotation('),
    );
    expect(body, isNot(contains('shouldSetDefaultRotation')));
  });

  test('local modifications names the binding change', () {
    final String markdown = _readExisting(_localModifications);

    final List<String> items = _numberedDeltaItems(markdown);

    expect(
      items.where(
        (String item) =>
            item.contains('startVideoCapturing') &&
            item.contains('setTargetRotation'),
      ),
      isNotEmpty,
      reason: 'no delta item names the rotation set before every take',
    );

    expect(
      items.where(
        (String item) =>
            item.contains('initializeCamera') && item.contains('videoCapture'),
      ),
      isNotEmpty,
      reason: 'no delta item names initializeCamera and videoCapture',
    );
    expect(
      items.where((String item) => item.contains('stopVideoRecording')),
      isNotEmpty,
      reason: 'no delta item names stopVideoRecording',
    );
  });
}
