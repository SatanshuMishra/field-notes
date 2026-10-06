import 'dart:math' as math;

import 'package:field_notes/features/sync/ui/flower_qr.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<int, List<int>> _highBlocks = <int, List<int>>{
  7: <int>[4, 39, 13, 1, 40, 14],
  8: <int>[4, 40, 14, 2, 41, 15],
  9: <int>[4, 36, 12, 4, 37, 13],
  10: <int>[6, 43, 15, 2, 44, 16],
  11: <int>[3, 36, 12, 8, 37, 13],
  12: <int>[7, 42, 14, 4, 43, 15],
  13: <int>[12, 33, 11, 4, 34, 12],
};

const Map<int, List<int>> _alignment = <int, List<int>>{
  7: <int>[6, 22, 38],
  8: <int>[6, 24, 42],
  9: <int>[6, 26, 46],
  10: <int>[6, 28, 50],
  11: <int>[6, 30, 54],
  12: <int>[6, 32, 58],
  13: <int>[6, 34, 62],
};

String _payloadOfLength(int length) {
  const String head = 'fieldnotes-pair:https://';
  const String tail = '.example#Q2xvdmVyLWZpZWxk';
  return '$head${'a' * (length - head.length - tail.length)}$tail';
}

List<List<bool>> _functionModules(int version) {
  final int size = version * 4 + 17;
  final List<List<bool>> function = List<List<bool>>.generate(
    size,
    (_) => List<bool>.filled(size, false),
  );
  void mark(int row, int col) {
    if (row >= 0 && col >= 0 && row < size && col < size) {
      function[row][col] = true;
    }
  }

  for (final (int top, int left) in <(int, int)>[
    (0, 0),
    (size - 7, 0),
    (0, size - 7),
  ]) {
    for (int row = -1; row <= 7; row++) {
      for (int col = -1; col <= 7; col++) {
        mark(top + row, left + col);
      }
    }
  }
  final List<int> centres = _alignment[version]!;
  for (final int row in centres) {
    for (final int col in centres) {
      if (function[row][col]) {
        continue;
      }
      for (int dr = -2; dr <= 2; dr++) {
        for (int dc = -2; dc <= 2; dc++) {
          mark(row + dr, col + dc);
        }
      }
    }
  }
  for (int i = 0; i < size; i++) {
    mark(6, i);
    mark(i, 6);
  }
  for (int i = 0; i <= 8; i++) {
    mark(8, i);
    mark(i, 8);
  }
  for (int i = size - 8; i < size; i++) {
    mark(8, i);
    mark(i, 8);
  }
  for (int i = 0; i < 6; i++) {
    for (int j = size - 11; j < size - 8; j++) {
      mark(i, j);
      mark(j, i);
    }
  }
  return function;
}

List<List<int>> _codewordOwners(List<List<bool>> function) {
  final int size = function.length;
  final List<List<int>> owner = List<List<int>>.generate(
    size,
    (_) => List<int>.filled(size, -1),
  );
  int bit = 0;
  int row = size - 1;
  int step = -1;
  for (int col = size - 1; col > 0; col -= 2) {
    if (col == 6) {
      col--;
    }
    while (true) {
      for (int side = 0; side < 2; side++) {
        if (!function[row][col - side]) {
          owner[row][col - side] = bit ~/ 8;
          bit++;
        }
      }
      row += step;
      if (row < 0 || row >= size) {
        row -= step;
        step = -step;
        break;
      }
    }
  }
  return owner;
}

List<int> _blockOfCodeword(int version) {
  final List<int> table = _highBlocks[version]!;
  final List<int> data = <int>[];
  final List<int> correction = <int>[];
  for (int i = 0; i < table.length; i += 3) {
    for (int block = 0; block < table[i]; block++) {
      data.add(table[i + 2]);
      correction.add(table[i + 1] - table[i + 2]);
    }
  }
  return <int>[
    for (int i = 0; i < data.reduce(math.max); i++)
      for (int block = 0; block < data.length; block++)
        if (i < data[block]) block,
    for (int i = 0; i < correction.reduce(math.max); i++)
      for (int block = 0; block < correction.length; block++)
        if (i < correction[block]) block,
  ];
}

Map<int, FlowerQr> _codesByVersion() {
  final Map<int, FlowerQr> codes = <int, FlowerQr>{};
  for (int length = 40; length <= 177; length++) {
    final FlowerQr code = FlowerQr.encode(_payloadOfLength(length));
    codes.putIfAbsent(code.version, () => code);
  }
  return codes;
}

void main() {
  test('every flower version from 7 to 13 is reachable', () {
    expect(_codesByVersion().keys.toList()..sort(), <int>[
      for (int version = 7; version <= 13; version++) version,
    ]);
  });

  test('a short pairing code is raised to version 7 so it has a heart', () {
    final FlowerQr code = FlowerQr.encode(
      'fieldnotes-pair:https://sync.satanshu.tech#Q2xvdmVyLWZpZWxk',
    );

    expect(code.version, flowerQrFirstVersion);
    expect(code.blooms, isTrue);
    expect(code.payload, contains('sync.satanshu.tech'));
  });

  test('the heart sits on the centre alignment pattern', () {
    for (final FlowerQr code in _codesByVersion().values) {
      final int middle = code.size ~/ 2;
      expect(code.heart, Offset(middle + 0.5, middle + 0.5));
      for (int dr = -2; dr <= 2; dr++) {
        for (int dc = -2; dc <= 2; dc++) {
          final int ring = math.max(dr.abs(), dc.abs());
          expect(
            code.isDark(middle + dr, middle + dc),
            ring != 1,
            reason: 'version ${code.version} at ($dr, $dc)',
          );
        }
      }
    }
  });

  test('the flower hides no finder, timing, format or version module', () {
    for (final FlowerQr code in _codesByVersion().values) {
      final List<List<bool>> function = _functionModules(code.version);
      final int middle = code.size ~/ 2;
      for (int row = 0; row < code.size; row++) {
        for (int col = 0; col < code.size; col++) {
          final bool heart =
              (row - middle).abs() <= 2 && (col - middle).abs() <= 2;
          if (function[row][col] && !heart) {
            expect(
              code.hiddenByFlower(row, col),
              isFalse,
              reason: 'version ${code.version} at ($row, $col)',
            );
          }
        }
      }
    }
  });

  test('the flower uses at most half of any block\'s error correction', () {
    for (final FlowerQr code in _codesByVersion().values) {
      final List<List<int>> owner = _codewordOwners(
        _functionModules(code.version),
      );
      final List<int> blockOf = _blockOfCodeword(code.version);
      final List<int> table = _highBlocks[code.version]!;
      final int correctable = (table[1] - table[2]) ~/ 2;
      final Set<int> hidden = <int>{
        for (int row = 0; row < code.size; row++)
          for (int col = 0; col < code.size; col++)
            if (code.hiddenByFlower(row, col) && owner[row][col] >= 0)
              owner[row][col],
      };
      final List<int> perBlock = List<int>.filled(table[0] + table[3], 0);
      for (final int codeword in hidden) {
        perBlock[blockOf[codeword]]++;
      }

      expect(hidden, isNotEmpty);
      expect(
        perBlock.reduce(math.max) * 2,
        lessThanOrEqualTo(correctable),
        reason: 'version ${code.version} hides $perBlock of $correctable',
      );
    }
  });

  test('a code too long for a centre heart is drawn without a flower', () {
    final FlowerQr code = FlowerQr.encode(_payloadOfLength(200));

    expect(code.version, greaterThan(flowerQrLastVersion));
    expect(code.blooms, isFalse);
    for (int row = 0; row < code.size; row++) {
      for (int col = 0; col < code.size; col++) {
        expect(code.hiddenByFlower(row, col), isFalse);
      }
    }
  });
}
