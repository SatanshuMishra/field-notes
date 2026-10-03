import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/features/reminders/local_notifications_reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

const String _androidRes = 'android/app/src/main/res';

const Map<String, int> _densities = <String, int>{
  'mdpi': 24,
  'hdpi': 36,
  'xhdpi': 48,
  'xxhdpi': 72,
  'xxxhdpi': 96,
};

const int _nearWhite = 250;
const int _opaque = 128;
const double _minimumCover = 0.2;
const double _maximumCover = 0.7;
const double _minimumGaps = 0.08;

class _Image {
  const _Image(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final ByteData rgba;

  int channel(int x, int y, int channel) =>
      rgba.getUint8((y * width + x) * 4 + channel);

  int alphaAt(int x, int y) => channel(x, y, 3);
}

Future<_Image> _decode(String path) async {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  final Uint8List bytes = file.readAsBytesSync();
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ui.Image image = frame.image;
  final ByteData? rgba = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final _Image decoded = _Image(image.width, image.height, rgba!);
  image.dispose();
  codec.dispose();
  return decoded;
}

String get _iconName => reminderNotificationIcon.split('/').last;

void main() {
  test('the reminder notification icon is a white peony silhouette at every density', () async {
    expect(reminderNotificationIcon, '@drawable/ic_stat_peony');
    for (final MapEntry<String, int> density in _densities.entries) {
      final String path = '$_androidRes/drawable-${density.key}/$_iconName.png';
      final _Image image = await _decode(path);
      final int size = density.value;
      expect(image.width, size, reason: path);
      expect(image.height, size, reason: path);
      for (final (int x, int y) in <(int, int)>[
        (0, 0),
        (size - 1, 0),
        (0, size - 1),
        (size - 1, size - 1),
      ]) {
        expect(image.alphaAt(x, y), 0, reason: '$path corner ($x, $y)');
      }
      int opaque = 0;
      int left = size;
      int top = size;
      int right = -1;
      int bottom = -1;
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          final int alpha = image.alphaAt(x, y);
          if (alpha == 0) {
            continue;
          }
          for (int c = 0; c < 3; c++) {
            expect(
              image.channel(x, y, c),
              greaterThanOrEqualTo(_nearWhite),
              reason: '$path ($x, $y) is not white',
            );
          }
          if (alpha >= _opaque) {
            opaque++;
            left = x < left ? x : left;
            top = y < top ? y : top;
            right = x > right ? x : right;
            bottom = y > bottom ? y : bottom;
          }
        }
      }
      final double cover = opaque / (size * size);
      expect(cover, greaterThan(_minimumCover), reason: path);
      expect(cover, lessThan(_maximumCover), reason: path);
      int gaps = 0;
      for (int y = top; y <= bottom; y++) {
        for (int x = left; x <= right; x++) {
          if (image.alphaAt(x, y) < _opaque) {
            gaps++;
          }
        }
      }
      final int box = (right - left + 1) * (bottom - top + 1);
      expect(
        gaps / box,
        greaterThan(_minimumGaps),
        reason: '$path draws one solid blob with no petal gaps',
      );
    }
  });

  test('release builds keep the reminder notification icon', () {
    final File keep = File('$_androidRes/raw/keep.xml');
    expect(keep.existsSync(), isTrue);
    final RegExpMatch? kept = RegExp(r'tools:keep="([^"]*)"')
        .firstMatch(keep.readAsStringSync());
    expect(kept, isNotNull);
    expect(kept!.group(1)!.split(','), contains(reminderNotificationIcon));
  });
}
