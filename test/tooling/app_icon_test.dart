import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const String _macIconSet = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
const String _androidRes = 'android/app/src/main/res';
const String _windowsIcon = 'windows/runner/resources/app_icon.ico';

const Set<String> _macIcons = <String>{
  '$_macIconSet/app_icon_16.png',
  '$_macIconSet/app_icon_32.png',
  '$_macIconSet/app_icon_64.png',
  '$_macIconSet/app_icon_128.png',
  '$_macIconSet/app_icon_256.png',
  '$_macIconSet/app_icon_512.png',
  '$_macIconSet/app_icon_1024.png',
};

const Map<String, int> _legacyLaunchers = <String, int>{
  '$_androidRes/mipmap-mdpi/ic_launcher.png': 48,
  '$_androidRes/mipmap-hdpi/ic_launcher.png': 72,
  '$_androidRes/mipmap-xhdpi/ic_launcher.png': 96,
  '$_androidRes/mipmap-xxhdpi/ic_launcher.png': 144,
  '$_androidRes/mipmap-xxxhdpi/ic_launcher.png': 192,
};

const List<int> _windowsIconSizes = <int>[16, 24, 32, 48, 64, 128, 256];

const Map<String, String> _flutterDefaultMd5 = <String, String>{
  '$_macIconSet/app_icon_16.png': '8bf511604bc6ed0a6aeb380c5113fdcf',
  '$_macIconSet/app_icon_32.png': '8e0ae58e362a6636bdfccbc04da2c58c',
  '$_macIconSet/app_icon_64.png': '04e7b6ef05346c70b663ca1d97de3ad5',
  '$_macIconSet/app_icon_128.png': '3ded30823804caaa5ccc944067c54a36',
  '$_macIconSet/app_icon_256.png': 'dfe2c93d1536ae02f085cc63faa3430e',
  '$_macIconSet/app_icon_512.png': '0ad44039155424738917502c69667699',
  '$_macIconSet/app_icon_1024.png': 'c9becc9105f8cabce934d20c7bfb6aac',
  '$_androidRes/mipmap-mdpi/ic_launcher.png':
      '6270344430679711b81476e29878caa7',
  '$_androidRes/mipmap-hdpi/ic_launcher.png':
      '13e9c72ec37fac220397aa819fa1ef2d',
  '$_androidRes/mipmap-xhdpi/ic_launcher.png':
      'a0a8db5985280b3679d99a820ae2db79',
  '$_androidRes/mipmap-xxhdpi/ic_launcher.png':
      'afe1b655b9f32da22f9a4301bb8e6ba8',
  '$_androidRes/mipmap-xxxhdpi/ic_launcher.png':
      '57838d52c318faff743130c3fcfae0c6',
};

const int _rose = 0xFFB8566A;
const int _cream = 0xFFFBF3E4;
const int _blush = 0xFFF3CFD2;

const double _safeMin = 21;
const double _safeMax = 87;

class _Pixels {
  const _Pixels(this.width, this.rgba);

  final int width;
  final ByteData rgba;

  int _channel(int x, int y, int channel) =>
      rgba.getUint8((y * width + x) * 4 + channel);

  int alphaAt(int x, int y) => _channel(x, y, 3);

  int argbAt(int x, int y) =>
      (_channel(x, y, 3) << 24) |
      (_channel(x, y, 0) << 16) |
      (_channel(x, y, 1) << 8) |
      _channel(x, y, 2);
}

Uint8List _read(String path) {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  return file.readAsBytesSync();
}

(int, int) _pngSize(String path, Uint8List bytes) {
  expect(bytes.sublist(0, 8), const <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ], reason: '$path is not a PNG');
  expect(ascii.decode(bytes.sublist(12, 16)), 'IHDR', reason: path);
  final ByteData header = ByteData.sublistView(bytes);
  return (header.getUint32(16), header.getUint32(20));
}

void _expectChanged(String path, Uint8List bytes) {
  expect(
    md5.convert(bytes).toString(),
    isNot(_flutterDefaultMd5[path]),
    reason: '$path is still the Flutter default icon',
  );
}

Future<_Pixels> _decode(Uint8List bytes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ui.Image image = frame.image;
  final ByteData? rgba = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final int width = image.width;
  image.dispose();
  codec.dispose();
  return _Pixels(width, rgba!);
}

int _byte(int argb, int shift) => (argb >> shift) & 0xFF;

void _expectNear(_Pixels pixels, int x, int y, int expected, String what) {
  final int actual = pixels.argbAt(x, y);
  for (final int shift in const <int>[24, 16, 8, 0]) {
    expect(
      (_byte(actual, shift) - _byte(expected, shift)).abs(),
      lessThanOrEqualTo(8),
      reason:
          '$what at ($x, $y) is 0x${actual.toRadixString(16)}, '
          'expected near 0x${expected.toRadixString(16)}',
    );
  }
}

void _expectTransparent(_Pixels pixels, List<(int, int)> points, String what) {
  for (final (int x, int y) in points) {
    expect(
      pixels.alphaAt(x, y),
      0,
      reason: '$what at ($x, $y) should be transparent',
    );
  }
}

int _pixelsListed(Map<String, Object?> image) {
  final int points = int.parse((image['size']! as String).split('x').first);
  final int scale = int.parse((image['scale']! as String).replaceAll('x', ''));
  return points * scale;
}

String _attribute(String element, String name) {
  final RegExpMatch? match = RegExp('$name="([^"]*)"').firstMatch(element);
  expect(match, isNotNull, reason: '$name is missing from $element');
  return match!.group(1)!;
}

String _resourceName(String reference) => reference.split('/').last;

void main() {
  test("the macOS icon set is the rose icon on Apple's grid", () async {
    final Map<String, Object?> contents = jsonDecode(
      utf8.decode(_read('$_macIconSet/Contents.json')),
    ) as Map<String, Object?>;
    final List<Map<String, Object?>> listed =
        (contents['images']! as List<Object?>).cast<Map<String, Object?>>();
    expect(
      listed
          .map(
            (Map<String, Object?> image) => '$_macIconSet/${image['filename']}',
          )
          .toSet(),
      _macIcons,
    );
    for (final Map<String, Object?> image in listed) {
      final String path = '$_macIconSet/${image['filename']}';
      final int size = _pixelsListed(image);
      final Uint8List bytes = _read(path);
      expect(_pngSize(path, bytes), (
        size,
        size,
      ), reason: '$path is listed at $size pixels');
      _expectChanged(path, bytes);
    }

    final _Pixels icon = await _decode(_read('$_macIconSet/app_icon_1024.png'));
    _expectTransparent(icon, const <(int, int)>[
      (0, 0),
      (1023, 0),
      (0, 1023),
      (1023, 1023),
      (104, 104),
      (919, 104),
      (104, 919),
      (919, 919),
      (512, 40),
      (40, 512),
      (983, 512),
      (512, 990),
    ], 'outside the 824-point body');

    for (final (int x, int y) in const <(int, int)>[
      (104, 512),
      (919, 512),
      (512, 104),
      (512, 919),
    ]) {
      expect(icon.alphaAt(x, y), 255, reason: '($x, $y) is inside the body');
    }
    for (final (int x, int y) in const <(int, int)>[
      (96, 512),
      (927, 512),
      (512, 96),
      (512, 928),
    ]) {
      expect(
        icon.alphaAt(x, y),
        lessThan(128),
        reason: '($x, $y) is outside the 824-point body',
      );
    }

    final int shadowBelow = icon.alphaAt(512, 930);
    final int shadowAbove = icon.alphaAt(512, 94);
    expect(shadowBelow, inInclusiveRange(16, 160), reason: 'soft shadow');
    expect(
      shadowAbove,
      lessThan(shadowBelow ~/ 2),
      reason: 'shadow falls down',
    );
    expect(icon.argbAt(512, 930) & 0xFFFFFF, lessThan(0x202020));

    _expectNear(icon, 120, 512, _rose, 'the rounded square near its left edge');
    _expectNear(icon, 512, 347, _cream, 'the top petal');
    _expectNear(icon, 512, 548, _blush, 'the peony centre');
  });

  test(
    'android declares an adaptive rose icon with a safe-zone foreground',
    () async {
      final String manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
      expect(manifest, isNot(contains('android:roundIcon')));

      final String adaptive = utf8.decode(
        _read('$_androidRes/mipmap-anydpi-v26/ic_launcher.xml'),
      );
      expect(adaptive, contains('<adaptive-icon'));
      expect(adaptive, isNot(contains('<monochrome')));
      final String background = _attribute(
        RegExp(r'<background\b[^>]*>').firstMatch(adaptive)!.group(0)!,
        'android:drawable',
      );
      final String foreground = _attribute(
        RegExp(r'<foreground\b[^>]*>').firstMatch(adaptive)!.group(0)!,
        'android:drawable',
      );
      expect(background, '@color/ic_launcher_background');
      expect(foreground, '@drawable/ic_launcher_foreground');

      final String colours = utf8.decode(
        _read('$_androidRes/values/${_resourceName(background)}.xml'),
      );
      final RegExpMatch? colour = RegExp(
        '<color\\s+name="${_resourceName(background)}"\\s*>\\s*'
        r'(#[0-9A-Fa-f]{6})\s*</color>',
      ).firstMatch(colours);
      expect(colour?.group(1)?.toLowerCase(), '#b8566a');

      final String vector = utf8.decode(
        _read('$_androidRes/drawable/${_resourceName(foreground)}.xml'),
      );
      final String root = RegExp(r'<vector\b[^>]*>')
          .firstMatch(vector)!
          .group(0)!;
      expect(_attribute(root, 'android:width'), '108dp');
      expect(_attribute(root, 'android:height'), '108dp');
      expect(_attribute(root, 'android:viewportWidth'), '108');
      expect(_attribute(root, 'android:viewportHeight'), '108');

      final List<String> paths = RegExp(r'<path\b[^>]*>')
          .allMatches(vector)
          .map((RegExpMatch match) => match.group(0)!)
          .toList();
      expect(paths, isNotEmpty);
      for (final String path in paths) {
        final String data = _attribute(path, 'android:pathData');
        expect(
          data,
          matches(RegExp(r'^[MLQCZ0-9.,\s-]+$')),
          reason: 'only absolute commands, so every number is a coordinate',
        );
        final List<double> coordinates = RegExp(r'-?\d+(?:\.\d+)?')
            .allMatches(data)
            .map((RegExpMatch match) => double.parse(match.group(0)!))
            .toList();
        expect(coordinates, isNotEmpty);
        expect(coordinates.length.isEven, isTrue);
        final double halfStroke = path.contains('android:strokeColor=')
            ? double.parse(_attribute(path, 'android:strokeWidth')) / 2
            : 0;
        for (final double coordinate in coordinates) {
          expect(
            coordinate - halfStroke,
            greaterThanOrEqualTo(_safeMin),
            reason: '$coordinate leaves the safe zone',
          );
          expect(
            coordinate + halfStroke,
            lessThanOrEqualTo(_safeMax),
            reason: '$coordinate leaves the safe zone',
          );
        }
      }
      final Set<String> fills = RegExp(r'android:fillColor="([^"]*)"')
          .allMatches(vector)
          .map((RegExpMatch match) => match.group(1)!.toLowerCase())
          .toSet();
      final Set<String> strokes = RegExp(r'android:strokeColor="([^"]*)"')
          .allMatches(vector)
          .map((RegExpMatch match) => match.group(1)!.toLowerCase())
          .toSet();
      expect(fills, <String>{'#fbf3e4', '#f3cfd2'});
      expect(strokes, <String>{'#b8566a'});

      for (final MapEntry<String, int> launcher in _legacyLaunchers.entries) {
        final Uint8List bytes = _read(launcher.key);
        expect(_pngSize(launcher.key, bytes), (
          launcher.value,
          launcher.value,
        ), reason: '${launcher.key} is ${launcher.value} pixels');
        _expectChanged(launcher.key, bytes);
      }

      final _Pixels legacy = await _decode(
        _read('$_androidRes/mipmap-xxxhdpi/ic_launcher.png'),
      );
      _expectTransparent(legacy, const <(int, int)>[
        (0, 0),
        (191, 0),
        (0, 191),
        (191, 191),
      ], 'the rounded corner');
      _expectNear(
        legacy,
        10,
        96,
        _rose,
        'the rounded square near its left edge',
      );
      _expectNear(legacy, 96, 58, _cream, 'the top petal');
      _expectNear(legacy, 96, 104, _blush, 'the peony centre');
    },
  );

  test(
    'the Windows icon is the rose icon at every size Windows asks for',
    () async {
      final Uint8List icon = _read(_windowsIcon);
      final ByteData directory = ByteData.sublistView(icon);
      expect(directory.getUint16(0, Endian.little), 0, reason: 'reserved');
      expect(directory.getUint16(2, Endian.little), 1, reason: 'an icon');
      final int count = directory.getUint16(4, Endian.little);
      expect(count, _windowsIconSizes.length);

      final Map<int, Uint8List> entries = <int, Uint8List>{};
      for (int index = 0; index < count; index += 1) {
        final int entry = 6 + index * 16;
        final int width = icon[entry] == 0 ? 256 : icon[entry];
        final int height = icon[entry + 1] == 0 ? 256 : icon[entry + 1];
        expect(height, width, reason: 'entry $index is square');
        expect(icon[entry + 2], 0, reason: 'entry $index colour count');
        expect(icon[entry + 3], 0, reason: 'entry $index reserved');
        expect(directory.getUint16(entry + 4, Endian.little), 1);
        expect(directory.getUint16(entry + 6, Endian.little), 32);
        final int length = directory.getUint32(entry + 8, Endian.little);
        final int offset = directory.getUint32(entry + 12, Endian.little);
        expect(offset, greaterThanOrEqualTo(6 + count * 16));
        expect(offset + length, lessThanOrEqualTo(icon.length));
        final Uint8List png = Uint8List.sublistView(
          icon,
          offset,
          offset + length,
        );
        expect(_pngSize('$_windowsIcon at $width', png), (
          width,
          height,
        ), reason: 'the $width entry states its size');
        entries[width] = png;
      }
      expect(entries.keys.toList()..sort(), _windowsIconSizes);

      final _Pixels largest = await _decode(entries[256]!);
      _expectTransparent(largest, const <(int, int)>[
        (0, 0),
        (255, 0),
        (0, 255),
        (255, 255),
      ], 'the rounded corner');
      _expectNear(
        largest,
        13,
        128,
        _rose,
        'the rounded square near its left edge',
      );
      _expectNear(largest, 128, 77, _cream, 'the top petal');
      _expectNear(largest, 128, 139, _blush, 'the peony centre');
    },
  );
}
