import 'dart:math' as math;
import 'dart:ui';

import 'package:qr/qr.dart';

const int flowerQrFirstVersion = 7;
const int flowerQrLastVersion = 13;
const int flowerPetalCount = 5;
const double flowerPetalDistance = 4.3;
const double flowerPetalRadius = 3;
const double flowerHeartRadius = 2.5;
const double flowerGap = 0.5;
const int qrFinderSize = 7;

final class FlowerQr {
  FlowerQr._(this.payload, this._image)
    : heart = _heartOf(_image),
      petalCentres = List<Offset>.unmodifiable(_petalsAround(_heartOf(_image)));

  factory FlowerQr.encode(String payload) {
    final QrCode fitted = QrCode.fromData(
      data: payload,
      errorCorrectLevel: QrErrorCorrectLevel.H,
    );
    final QrCode code = fitted.typeNumber >= flowerQrFirstVersion
        ? fitted
        : (QrCode(flowerQrFirstVersion, QrErrorCorrectLevel.H)
            ..addData(payload));
    return FlowerQr._(payload, QrImage(code));
  }

  final String payload;
  final QrImage _image;
  final Offset heart;
  final List<Offset> petalCentres;

  int get size => _image.moduleCount;

  int get version => _image.typeNumber;

  bool get blooms =>
      version >= flowerQrFirstVersion && version <= flowerQrLastVersion;

  bool isDark(int row, int col) => _image.isDark(row, col);

  bool inFinder(int row, int col) {
    final bool top = row < qrFinderSize;
    final bool left = col < qrFinderSize;
    final bool right = col >= size - qrFinderSize;
    final bool bottom = row >= size - qrFinderSize;
    return (top && (left || right)) || (bottom && left);
  }

  bool hiddenByFlower(int row, int col) {
    if (!blooms) {
      return false;
    }
    final Offset centre = Offset(col + 0.5, row + 0.5);
    if ((centre - heart).distance <= flowerHeartRadius + flowerGap) {
      return true;
    }
    for (final Offset petal in petalCentres) {
      if ((centre - petal).distance <= flowerPetalRadius + flowerGap) {
        return true;
      }
    }
    return false;
  }

  List<Offset> get finderCorners => <Offset>[
    Offset.zero,
    Offset((size - qrFinderSize).toDouble(), 0),
    Offset(0, (size - qrFinderSize).toDouble()),
  ];

  static Offset _heartOf(QrImage image) {
    final double middle = image.moduleCount ~/ 2 + 0.5;
    return Offset(middle, middle);
  }

  static List<Offset> _petalsAround(Offset heart) => <Offset>[
    for (int petal = 0; petal < flowerPetalCount; petal++)
      heart +
          Offset.fromDirection(
            -math.pi / 2 + petal * 2 * math.pi / flowerPetalCount,
            flowerPetalDistance,
          ),
  ];
}
