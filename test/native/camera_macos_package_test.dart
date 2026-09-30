import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _plugin = 'third_party/camera_macos/macos';

const List<String> _swiftSources = <String>[
  'AVCaptureDevice+Extension.swift',
  'CameraMacOSNativeFactory.swift',
  'CameraMacosPlugin.swift',
  'FlutterMacOS+Extension.swift',
  'ImageStreamHandler.swift',
  'URL+Extension.swift',
];

void main() {
  test('camera_macos is a Swift package that CocoaPods can still build', () {
    final File manifest = File('$_plugin/camera_macos/Package.swift');
    expect(manifest.existsSync(), isTrue, reason: '${manifest.path} missing');
    final String package = manifest.readAsStringSync();
    expect(
      package,
      contains('.library(name: "camera-macos", targets: ["camera_macos"])'),
    );
    expect(
      package,
      contains(
        '.package(name: "FlutterFramework", path: "../FlutterFramework")',
      ),
    );
    expect(
      package,
      contains(
        '.product(name: "FlutterFramework", package: "FlutterFramework")',
      ),
    );

    for (final String source in _swiftSources) {
      expect(
        File('$_plugin/camera_macos/Sources/camera_macos/$source').existsSync(),
        isTrue,
        reason: '$source must live in the package Sources folder',
      );
      expect(
        File('$_plugin/Classes/$source').existsSync(),
        isFalse,
        reason: '$source must no longer live under Classes',
      );
    }

    final String podspec = File('$_plugin/camera_macos.podspec')
        .readAsStringSync();
    final RegExpMatch? sourceFiles = RegExp(r"s\.source_files\s*=\s*'([^']*)'")
        .firstMatch(podspec);
    expect(sourceFiles, isNotNull, reason: 'the podspec must set source_files');
    expect(
      sourceFiles!.group(1),
      'camera_macos/Sources/camera_macos/**/*.swift',
    );

    final List<String> urlImports =
        File('$_plugin/camera_macos/Sources/camera_macos/URL+Extension.swift')
            .readAsLinesSync()
            .where((String line) => line.startsWith('import '))
            .toList();
    expect(urlImports, contains('import AppKit'));
  });
}
