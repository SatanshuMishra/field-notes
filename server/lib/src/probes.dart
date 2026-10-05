import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'timers.dart';

typedef FreeSpaceProbe = Future<int?> Function(String directory);

const Duration probeLifetime = Duration(seconds: 5);
const Duration dfTimeLimit = Duration(seconds: 5);
const Duration goodReadingLifetime = Duration(minutes: 10);

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

typedef StartProcess = Future<Process> Function(
  String executable,
  List<String> arguments,
);

final class DfProbe {
  DfProbe({
    this.executable = 'df',
    this._startTimer = Timer.new,
    this._startProcess = Process.start,
  });

  final String executable;
  final StartTimer _startTimer;
  final StartProcess _startProcess;
  final Set<String> _unfinished = <String>{};

  Future<int?> read(String directory) async {
    if (!_unfinished.add(directory)) {
      return null;
    }
    final Process process;
    try {
      process = await _startProcess(executable, <String>['-Pk', directory]);
    } on ProcessException {
      _unfinished.remove(directory);
      return null;
    }
    unawaited(
      process.exitCode.then<void>(
        (int _) {
          _unfinished.remove(directory);
        },
        onError: (Object _) {
          _unfinished.remove(directory);
        },
      ),
    );
    final Completer<int?> killed = Completer<int?>();
    final Timer limit = _startTimer(dfTimeLimit, () {
      process.kill(ProcessSignal.sigkill);
      killed.complete(null);
    });
    try {
      return await Future.any(<Future<int?>>[
        _dfReading(process),
        killed.future,
      ]);
    } finally {
      limit.cancel();
    }
  }
}

Future<int?> dfFreeBytes(
  String directory, {
  String executable = 'df',
  StartTimer startTimer = Timer.new,
}) => DfProbe(executable: executable, startTimer: startTimer).read(directory);

Future<int?> _dfReading(Process process) async {
  try {
    final List<String> output = await Future.wait(<Future<String>>[
      process.stdout.transform(systemEncoding.decoder).join(),
      process.stderr.transform(systemEncoding.decoder).join(),
    ]);
    return await process.exitCode == 0
        ? parseDfAvailableBytes(output.first)
        : null;
  } on Object {
    return null;
  }
}

final class FreeSpace {
  FreeSpace({
    required this._probe,
    required this._clock,
    required this.minFreeBytes,
    this.lifetime = probeLifetime,
    this._onFailedReading,
  });

  final Future<int?> Function() _probe;
  final DateTime Function() _clock;
  final int minFreeBytes;
  final Duration lifetime;
  final void Function()? _onFailedReading;
  int _reserved = 0;
  int _written = 0;
  ({DateTime at, int? free})? _reading;
  ({DateTime at, int free})? _lastGood;
  Future<int?>? _probing;

  int get reservedBytes => _reserved;

  int get writtenBytes => _written;

  Future<bool> reserve(int bytes) async {
    final int? free = await _read();
    return free != null && _take(free, bytes);
  }

  Future<bool> reservePush(int bytes) async {
    final int? free = await _read();
    if (free != null) {
      return _take(free, bytes);
    }
    final ({DateTime at, int free})? lastGood = _lastGood;
    if (lastGood != null &&
        _clock().difference(lastGood.at) < goodReadingLifetime) {
      return _take(lastGood.free, bytes);
    }
    _reserved += bytes;
    return true;
  }

  bool _take(int free, int bytes) {
    if (free - _reserved - _written - bytes < minFreeBytes) {
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
    if (free == null) {
      _onFailedReading?.call();
      return null;
    }
    _lastGood = (at: now, free: free);
    _written -= writtenBefore;
    return free;
  }
}
