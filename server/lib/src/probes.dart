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
