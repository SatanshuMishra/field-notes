import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/note_engine/platform/image_pasteboard.dart';

const MethodChannel _channel = MethodChannel(imagePasteboardChannelName);

List<MethodCall> _mockChannel(Object? Function(MethodCall) answer) {
  final List<MethodCall> calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (MethodCall call) async {
        calls.add(call);
        return answer(call);
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );
  return calls;
}

String _block(String project, String header) {
  final int start = project.indexOf(header);
  expect(start, isNot(-1), reason: '$header must exist');
  final int end = project.indexOf('\t\t};', start);
  return project.substring(start, end);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImagePasteboard', () {
    test(
      'the pasteboard bridge reports file urls, image data and text',
      () async {
        Object? image = <String, Object?>{
          'bytes': Uint8List.fromList(<int>[137, 80, 78, 71]),
          'mime': 'image/png',
        };
        final List<MethodCall> calls = _mockChannel(
          (MethodCall call) => switch (call.method) {
            'contents' => <String, Object?>{
              'paths': <String>['/Users/me/a.png', '/Users/me/b.txt'],
              'imageTypes': <String>['png', 'tiff', 'bmp'],
              'hasText': true,
            },
            'image' => image,
            _ => null,
          },
        );
        const ImagePasteboard pasteboard = ImagePasteboard();

        final PasteboardContents contents = await pasteboard.readContents();
        expect(
          contents,
          const PasteboardContents(
            filePaths: <String>['/Users/me/a.png', '/Users/me/b.txt'],
            imageTypes: <PasteboardImageType>{
              PasteboardImageType.png,
              PasteboardImageType.tiff,
            },
            hasText: true,
          ),
        );
        expect(contents.hasImageData, isTrue);
        expect(calls.map((MethodCall call) => call.method), <String>[
          'contents',
        ]);

        expect(
          await pasteboard.readImage(),
          PastedImage(
            bytes: Uint8List.fromList(<int>[137, 80, 78, 71]),
            mime: 'image/png',
          ),
        );
        expect(calls.map((MethodCall call) => call.method), <String>[
          'contents',
          'image',
        ]);

        image = null;
        expect(await pasteboard.readImage(), isNull);
        expect(calls.map((MethodCall call) => call.method), <String>[
          'contents',
          'image',
          'image',
        ]);
      },
    );

    test('readImageFile converts one file and maps the answer', () async {
      Object? answer = <String, Object?>{
        'bytes': Uint8List.fromList(<int>[1, 2, 3]),
        'mime': 'image/png',
      };
      final List<MethodCall> calls = _mockChannel((MethodCall call) => answer);
      const ImagePasteboard pasteboard = ImagePasteboard();

      expect(
        await pasteboard.readImageFile('/p/IMG_1.HEIC'),
        PastedImage(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          mime: 'image/png',
        ),
      );
      expect(calls, hasLength(1));
      expect(calls.single.method, 'imageFile');
      expect(calls.single.arguments, <String, Object?>{
        'path': '/p/IMG_1.HEIC',
      });

      answer = null;
      expect(await pasteboard.readImageFile('/p/IMG_1.HEIC'), isNull);
      expect(calls, hasLength(2));
    });

    test('a missing plugin gives empty contents and no images', () async {
      const ImagePasteboard pasteboard = ImagePasteboard();

      final PasteboardContents contents = await pasteboard.readContents();
      expect(contents, const PasteboardContents());
      expect(contents.hasImageData, isFalse);
      expect(await pasteboard.readImage(), isNull);
      expect(await pasteboard.readImageFile('/p/a.tiff'), isNull);
    });

    test('a platform exception gives empty contents and no images', () async {
      _mockChannel(
        (MethodCall call) => throw PlatformException(code: 'bad-arguments'),
      );
      const ImagePasteboard pasteboard = ImagePasteboard();

      final PasteboardContents contents = await pasteboard.readContents();
      expect(contents, const PasteboardContents());
      expect(contents.hasImageData, isFalse);
      expect(await pasteboard.readImage(), isNull);
      expect(await pasteboard.readImageFile('/p/a.tiff'), isNull);
    });

    test('missing keys default to empty and false', () async {
      _mockChannel((MethodCall call) => <String, Object?>{});

      expect(
        await const ImagePasteboard().readContents(),
        const PasteboardContents(),
      );
      expect(await const ImagePasteboard().readImage(), isNull);
    });

    test('constructing the pasteboard makes no call', () {
      final List<MethodCall> calls = _mockChannel((MethodCall call) => null);

      const ImagePasteboard pasteboard = ImagePasteboard(channel: _channel);

      expect(pasteboard, isNotNull);
      expect(calls, isEmpty);
    });
  });

  group('macOS pasteboard bridge sources', () {
    final String bridge = File(
      'macos/Runner/ImagePasteboardBridge.swift',
    ).readAsStringSync();
    final String window = File(
      'macos/Runner/MainFlutterWindow.swift',
    ).readAsStringSync();
    final String project = File(
      'macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    test('the bridge reads the pasteboard and converts with ImageIO', () {
      for (final String fragment in <String>[
        '"$imagePasteboardChannelName"',
        '"contents"',
        '"image"',
        '"imageFile"',
        'urlReadingFileURLsOnly',
        'public.jpeg',
        'public.heic',
        'CGImageSourceCreateThumbnailAtIndex',
        'kCGImageSourceThumbnailMaxPixelSize',
        '2048',
        'DispatchQueue.global',
      ]) {
        expect(bridge, contains(fragment));
      }
    });

    test('the window registers the bridge after spell check', () {
      expect(window, contains('ImagePasteboardBridge(messenger:'));
      expect(window, contains('SpellCheckBridge(messenger:'));
    });

    test('the runner target compiles the bridge', () {
      expect(
        project,
        contains(
          'F1E1D0012EA0000100000003 /* ImagePasteboardBridge.swift */ = '
          '{isa = PBXFileReference;',
        ),
      );
      expect(
        _block(project, '\t\t33FAB671232836740065AC1E /* Runner */ = {'),
        contains('F1E1D0012EA0000100000003 /* ImagePasteboardBridge.swift */'),
      );
      expect(
        _block(project, '\t\t33CC10E92044A3C60003C045 /* Sources */ = {'),
        contains(
          'F1E1D0012EA0000100000004 /* ImagePasteboardBridge.swift in Sources */',
        ),
      );
      expect(
        _block(project, '\t\t331C80D1294CF70F00263BE5 /* Sources */ = {'),
        isNot(contains('ImagePasteboardBridge.swift')),
      );
    });
  });
}
