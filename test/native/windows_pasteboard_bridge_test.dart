import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/note_engine/platform/image_pasteboard.dart';

const String _runner = 'windows/runner';

String _source(String name) {
  final File file = File('$_runner/$name');
  expect(file.existsSync(), isTrue, reason: '$_runner/$name is missing');
  return file.readAsStringSync();
}

int _integer(String source, RegExp pattern) {
  final RegExpMatch? match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: '${pattern.pattern} must be present');
  return int.parse(match!.group(1)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Windows pasteboard bridge answers the macOS contract', () async {
    final String bridge = _source('pasteboard_bridge.cpp');

    final Uint8List png = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47]);
    final List<MethodCall> calls = <MethodCall>[];
    const MethodChannel channel = MethodChannel(imagePasteboardChannelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          if (calls.length == 1) {
            return <String, Object?>{
              'paths': <String>[r'C:\Users\me\leaf.JPG'],
              'imageTypes': <String>['png', 'bitmap'],
              'hasText': true,
            };
          }
          return <String, Object?>{'bytes': png, 'mime': 'image/png'};
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    const ImagePasteboard pasteboard = ImagePasteboard();
    expect(
      await pasteboard.readContents(),
      const PasteboardContents(
        filePaths: <String>[r'C:\Users\me\leaf.JPG'],
        imageTypes: <PasteboardImageType>{
          PasteboardImageType.png,
          PasteboardImageType.bitmap,
        },
        hasText: true,
      ),
    );
    final PastedImage expected = PastedImage(bytes: png, mime: 'image/png');
    expect(await pasteboard.readImage(), expected);
    expect(await pasteboard.readImageFile(r'C:\Photos\leaf.heic'), expected);
    expect(calls, hasLength(3));
    final Map<Object?, Object?> fileArguments =
        calls.last.arguments as Map<Object?, Object?>;

    expect(
      bridge,
      contains('kPasteboardChannelName[] = "$imagePasteboardChannelName"'),
    );
    expect(bridge, contains('kContentsMethod[] = "${calls[0].method}"'));
    expect(bridge, contains('kImageMethod[] = "${calls[1].method}"'));
    expect(bridge, contains('kImageFileMethod[] = "${calls[2].method}"'));
    expect(
      bridge,
      contains('kPathArgument[] = "${fileArguments.keys.single}"'),
    );
    expect(
      bridge,
      contains('kPngImageType[] = "${PasteboardImageType.png.name}"'),
    );
    expect(
      bridge,
      contains('kBitmapImageType[] = "${PasteboardImageType.bitmap.name}"'),
    );
    expect(bridge, contains('kPngMime[] = "image/png"'));
    for (final String key in <String>[
      'paths',
      'imageTypes',
      'hasText',
      'bytes',
      'mime',
    ]) {
      expect(bridge, contains('flutter::EncodableValue("$key")'));
    }

    expect(bridge, contains('::OpenClipboard(owner)'));
    expect(bridge, contains('::CloseClipboard()'));
    expect(bridge, contains('FormatAvailable(CF_HDROP)'));
    expect(
      bridge,
      contains(
        'PathsFromDrop(static_cast<HDROP>(::GetClipboardData(CF_HDROP)))',
      ),
    );
    expect(_source('utils.cpp'), contains('::DragQueryFileW(drop, index,'));
    expect(bridge, contains('kPngClipboardFormat[] = L"PNG"'));
    expect(bridge, contains('::RegisterClipboardFormatW(kPngClipboardFormat)'));
    expect(
      bridge,
      contains('FormatAvailable(CF_DIBV5) || FormatAvailable(CF_DIB)'),
    );
    expect(bridge, contains('FormatAvailable(CF_UNICODETEXT)'));
    expect(bridge, contains('GlobalBytes(::GetClipboardData(png_format_))'));
    expect(
      bridge,
      contains(
        'PngFromBitmap(static_cast<HBITMAP>(::GetClipboardData(CF_BITMAP)))',
      ),
    );

    expect(bridge, contains('ComPtr<IWICImagingFactory> factory;'));
    expect(bridge, contains('CLSID_WICImagingFactory'));
    expect(bridge, contains('factory->CreateBitmapFromHBITMAP('));
    expect(bridge, contains('factory->CreateDecoderFromFilename('));
    expect(bridge, contains('GUID_ContainerFormatPng'));
    expect(bridge, contains('ComPtr<IWICBitmapScaler> scaler;'));
    expect(bridge, contains('if (longest <= kConvertedLongEdge)'));
    final String swift = File('macos/Runner/ImagePasteboardBridge.swift')
        .readAsStringSync();
    expect(
      _integer(bridge, RegExp(r'constexpr UINT kConvertedLongEdge = (\d+);')),
      _integer(swift, RegExp(r'private let convertedLongEdge = (\d+)\n')),
    );
    expect(
      _integer(bridge, RegExp(r'constexpr UINT kConvertedLongEdge = (\d+);')),
      2048,
    );

    expect(
      bridge,
      contains('kOrientationQuery[] = L"System.Photo.Orientation"'),
    );
    expect(bridge, contains('ComPtr<IWICBitmapFlipRotator> rotator;'));
    expect(bridge, contains('OrientationFor(PhotoOrientation(frame.Get()))'));

    expect(bridge, contains('::CreateThread('));
    expect(bridge, contains('::CoInitializeEx(nullptr, COINIT_MULTITHREADED)'));
    expect(bridge, contains('::CoUninitialize();'));
    expect(bridge, contains('::PostMessage(job->window, job->message, 0,'));
    expect(bridge, contains('::RegisterWindowMessageW(kImageFileMessageName)'));
    final String flutterWindow = _source('flutter_window.cpp');
    expect(
      flutterWindow,
      contains('pasteboard_bridge_->IsImageFileMessage(message)'),
    );
    expect(
      flutterWindow,
      contains('pasteboard_bridge_->CompleteImageFile(lparam)'),
    );
    expect(
      flutterWindow,
      matches(
        RegExp(
          r'std::make_unique<PasteboardBridge>\(\s*messenger, GetHandle\(\)\)',
        ),
      ),
    );

    expect(
      swift,
      contains(r'message: "imageFile expects a string under \"path\""'),
    );
    expect(
      bridge,
      matches(
        RegExp(
          r'result->Error\("bad-arguments",\s*'
          r'"imageFile expects a string under \\"path\\""\);',
        ),
      ),
    );
    expect(bridge, isNot(matches(RegExp(r'\b(try|catch|throw)\b'))));

    final String cmake = _source('CMakeLists.txt');
    expect(cmake, contains('"pasteboard_bridge.cpp"'));
    expect(cmake, contains('"windowscodecs.lib"'));
    expect(cmake, contains('"ole32.lib"'));
    expect(cmake, contains('"shell32.lib"'));
  });
}
