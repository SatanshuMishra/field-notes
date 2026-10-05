import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef FreeSpaceProbe = Future<int?> Function(String directory);

const Duration probeLifetime = Duration(seconds: 5);

final RegExp _dfColumns = RegExp(r'\s(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%\s');

final class CachedProbe<T> {
  CachedProbe({
    required this._probe,
    required this._clock,
    this.lifetime = probeLifetime,
  });

  final Future<T> Function() _probe;
  final DateTime Function() _clock;
  final Duration lifetime;
  ({DateTime at, T value})? _last;
  Future<T>? _running;

  Future<T> read() {
    final DateTime now = _clock();
    final ({DateTime at, T value})? last = _last;
    if (last != null &&
        !now.isBefore(last.at) &&
        now.isBefore(last.at.add(lifetime))) {
      return Future<T>.value(last.value);
    }
    return _running ??= _probe()
        .then((T value) {
          _last = (at: now, value: value);
          return value;
        })
        .whenComplete(() {
          _running = null;
        });
  }
}

int? parseDfAvailableBytes(String output) {
  final List<String> lines = const LineSplitter().convert(output.trim());
  if (lines.length < 2) {
    return null;
  }
  final RegExpMatch? columns = _dfColumns.firstMatch(' ${lines.last} ');
  final int? available = int.tryParse(columns?.group(3) ?? '');
  return available == null ? null : available * 1024;
}

Future<int?> dfFreeBytes(String directory) async {
  try {
    final ProcessResult result = await Process.run('df', <String>[
      '-Pk',
      directory,
    ]);
    return result.exitCode == 0
        ? parseDfAvailableBytes('${result.stdout}')
        : null;
  } on ProcessException {
    return null;
  }
}

final class FreeSpace {
  FreeSpace({
    required this._probe,
    required this._clock,
    required this.minFreeBytes,
    this.lifetime = probeLifetime,
  });

  final Future<int?> Function() _probe;
  final DateTime Function() _clock;
  final int minFreeBytes;
  final Duration lifetime;
  int _reserved = 0;
  int _written = 0;
  ({DateTime at, int? free})? _reading;
  Future<int?>? _probing;

  int get reservedBytes => _reserved;

  int get writtenBytes => _written;

  Future<bool> reserve(int bytes) async {
    final int? free = await _read();
    if (free == null || free - _reserved - _written - bytes < minFreeBytes) {
      return false;
    }
    _reserved += bytes;
    return true;
  }

  void release(int bytes, {required bool written}) {
    _reserved -= bytes;
    if (written) {
      _written += bytes;
    }
  }

  Future<int?> _read() {
    final DateTime now = _clock();
    final ({DateTime at, int? free})? reading = _reading;
    if (reading != null &&
        !now.isBefore(reading.at) &&
        now.isBefore(reading.at.add(lifetime))) {
      return Future<int?>.value(reading.free);
    }
    return _probing ??= _fresh(now).whenComplete(() {
      _probing = null;
    });
  }

  Future<int?> _fresh(DateTime now) async {
    final int writtenBefore = _written;
    final int? free = await _probe();
    _reading = (at: now, free: free);
    _written -= writtenBefore;
    return free;
  }
}
