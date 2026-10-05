import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int _finBit = 0x80;
const int _maskBit = 0x80;
const int _opcodeBits = 0x0f;
const int _lengthBits = 0x7f;
const int _continuation = 0x0;
const int _firstControlOpcode = 0x8;
const int _maxControlPayload = 125;
const int _twoByteLength = 126;
const int _eightByteLength = 127;

const int maxLiveRawBytes = 16 * 1024;
const int maxLiveFrames = 60;
const Duration liveFrameWindow = Duration(seconds: 60);
const Duration liveStallLimit = Duration(seconds: 30);
const int maxLiveWaitingBytes = 64 * 1024;

enum LiveRefusal { tooBig, tooFast }

final class LiveFrameGuard {
  LiveFrameGuard(this.limit, this._clock);

  final int limit;
  final DateTime Function() _clock;
  final List<int> _header = <int>[];
  final ListQueue<DateTime> _frames = ListQueue<DateTime>();
  int _payloadLeft = 0;
  int _messageBytes = 0;
  int _rawBytes = 0;
  bool _completesMessage = false;
  bool _inControlFrame = false;

  LiveRefusal? admit(List<int> chunk, [List<(int, int)>? controlFrames]) {
    int index = 0;
    int? controlStart = _inControlFrame ? 0 : null;
    void frameEnded() {
      _frameEnded();
      final int? start = controlStart;
      if (start != null) {
        controlFrames?.add((start, index));
        controlStart = null;
      }
      _inControlFrame = false;
    }

    while (index < chunk.length) {
      if (_payloadLeft > 0) {
        final int taken = min(_payloadLeft, chunk.length - index);
        _payloadLeft -= taken;
        index += taken;
        _rawBytes += taken;
        if (_rawBytes > maxLiveRawBytes) {
          return LiveRefusal.tooBig;
        }
        if (_payloadLeft == 0) {
          frameEnded();
        }
        continue;
      }
      if (_header.isEmpty) {
        _inControlFrame = (chunk[index] & _opcodeBits) >= _firstControlOpcode;
        controlStart = _inControlFrame ? index : null;
      }
      _header.add(chunk[index]);
      index++;
      _rawBytes++;
      if (_rawBytes > maxLiveRawBytes) {
        return LiveRefusal.tooBig;
      }
      final int? headerLength = _headerLength();
      if (headerLength == null || _header.length < headerLength) {
        continue;
      }
      final LiveRefusal? refusal = _frameStarts();
      if (refusal != null) {
        return refusal;
      }
      _header.clear();
      if (_payloadLeft == 0) {
        frameEnded();
      }
    }
    final int? start = controlStart;
    if (start != null) {
      controlFrames?.add((start, chunk.length));
    }
    return null;
  }

  int? _headerLength() {
    if (_header.length < 2) {
      return null;
    }
    final int lengthCode = _header[1] & _lengthBits;
    final int extended = switch (lengthCode) {
      _twoByteLength => 2,
      _eightByteLength => 8,
      _ => 0,
    };
    final int mask = (_header[1] & _maskBit) != 0 ? 4 : 0;
    return 2 + extended + mask;
  }

  bool _withinRate() {
    final DateTime now = _clock();
    if (_frames.isNotEmpty && now.isBefore(_frames.first)) {
      _frames.clear();
    }
    while (_frames.isNotEmpty &&
        !now.isBefore(_frames.first.add(liveFrameWindow))) {
      _frames.removeFirst();
    }
    if (_frames.length >= maxLiveFrames) {
      return false;
    }
    _frames.addLast(now);
    return true;
  }

  void _frameEnded() {
    if (_completesMessage) {
      _rawBytes = 0;
    }
  }

  LiveRefusal? _frameStarts() {
    if (!_withinRate()) {
      return LiveRefusal.tooFast;
    }
    final bool fin = (_header[0] & _finBit) != 0;
    final int opcode = _header[0] & _opcodeBits;
    final int lengthCode = _header[1] & _lengthBits;
    final int lengthBytes = switch (lengthCode) {
      _twoByteLength => 2,
      _eightByteLength => 8,
      _ => 0,
    };
    int length = lengthBytes == 0 ? lengthCode : 0;
    for (int index = 0; index < lengthBytes; index++) {
      if (length > limit) {
        return LiveRefusal.tooBig;
      }
      length = length * 256 + _header[2 + index];
    }
    if (opcode >= _firstControlOpcode) {
      if (length > _maxControlPayload) {
        return LiveRefusal.tooBig;
      }
      _completesMessage = false;
      _payloadLeft = length;
      return null;
    }
    final int total = (opcode == _continuation ? _messageBytes : 0) + length;
    if (total > limit) {
      return LiveRefusal.tooBig;
    }
    _messageBytes = fin ? 0 : total;
    _completesMessage = fin;
    _payloadLeft = length;
    return null;
  }
}

Stream<Uint8List> guardedFrames(
  Stream<Uint8List> source,
  LiveFrameGuard guard,
  void Function(LiveRefusal refusal) onRefused,
) {
  bool refused = false;
  return source.transform(
    StreamTransformer<Uint8List, Uint8List>.fromHandlers(
      handleData: (Uint8List chunk, EventSink<Uint8List> sink) {
        if (refused) {
          return;
        }
        final List<(int, int)> controlFrames = <(int, int)>[];
        final LiveRefusal? refusal = guard.admit(chunk, controlFrames);
        if (refusal != null) {
          refused = true;
          onRefused(refusal);
          return;
        }
        if (controlFrames.isEmpty) {
          sink.add(chunk);
          return;
        }
        int from = 0;
        for (final (int start, int end) in controlFrames) {
          if (start > from) {
            sink.add(Uint8List.sublistView(chunk, from, start));
          }
          sink.add(Uint8List.fromList(chunk.sublist(start, end)));
          from = end;
        }
        if (from < chunk.length) {
          sink.add(Uint8List.sublistView(chunk, from));
        }
      },
    ),
  );
}

typedef SendOutput = Future<void> Function(
  Socket socket,
  Stream<List<int>> output,
);

Future<void> sendOutput(Socket socket, Stream<List<int>> output) =>
    socket.addStream(output);

final class LiveOutput {
  LiveOutput(this._clock, this._onOverflow);

  final DateTime Function() _clock;
  final void Function() _onOverflow;
  final ListQueue<List<int>> _waiting = ListQueue<List<int>>();
  int _waitingBytes = 0;
  DateTime? _pausedSince;
  bool _overflowed = false;
  bool _sourceDone = false;
  StreamController<List<int>>? _out;
  StreamSubscription<List<int>>? _source;

  int get waitingBytes => _waitingBytes;

  bool get overflowed => _overflowed;

  bool stalled(DateTime now) {
    final DateTime? since = _pausedSince;
    return since != null && now.difference(since) > liveStallLimit;
  }

  Stream<List<int>> watch(Stream<List<int>> source) {
    final StreamController<List<int>> out = StreamController<List<int>>(
      sync: true,
    );
    out
      ..onListen = () {
        _source = source.listen(
          _add,
          onError: (Object error, StackTrace stackTrace) {
            if (!out.isClosed) {
              out.addError(error, stackTrace);
            }
          },
          onDone: () {
            _sourceDone = true;
            _flush();
          },
        );
      }
      ..onPause = () {
        _pausedSince ??= _clock();
      }
      ..onResume = () {
        _pausedSince = null;
        scheduleMicrotask(_flush);
      }
      ..onCancel = () => _source?.cancel();
    _out = out;
    return out.stream;
  }

  void _add(List<int> chunk) {
    final StreamController<List<int>>? out = _out;
    if (out == null || out.isClosed || _overflowed) {
      return;
    }
    if (!out.isPaused && _waiting.isEmpty) {
      out.add(chunk);
      return;
    }
    _waiting.addLast(chunk);
    _waitingBytes += chunk.length;
    if (_waitingBytes > maxLiveWaitingBytes) {
      _overflowed = true;
      _waiting.clear();
      _waitingBytes = 0;
      scheduleMicrotask(_onOverflow);
    }
  }

  void _flush() {
    final StreamController<List<int>>? out = _out;
    if (out == null || out.isClosed) {
      return;
    }
    while (!out.isPaused && _waiting.isNotEmpty) {
      final List<int> chunk = _waiting.removeFirst();
      _waitingBytes -= chunk.length;
      out.add(chunk);
    }
    if (_sourceDone && _waiting.isEmpty) {
      unawaited(out.close());
    }
  }
}

final class GuardedSocket extends StreamView<Uint8List> implements Socket {
  GuardedSocket(
    this._socket,
    Stream<Uint8List> incoming, {
    required this._output,
    this._send = sendOutput,
  }) : super(incoming);

  final Socket _socket;
  final LiveOutput _output;
  final SendOutput _send;

  @override
  Encoding get encoding => _socket.encoding;

  @override
  set encoding(Encoding value) => _socket.encoding = value;

  @override
  InternetAddress get address => _socket.address;

  @override
  int get port => _socket.port;

  @override
  InternetAddress get remoteAddress => _socket.remoteAddress;

  @override
  int get remotePort => _socket.remotePort;

  @override
  Future<void> get done => _socket.done;

  @override
  void add(List<int> data) => _socket.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _socket.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) =>
      _send(_socket, _output.watch(stream));

  @override
  Future<void> flush() => _socket.flush();

  @override
  Future<void> close() => _socket.close();

  @override
  void destroy() => _socket.destroy();

  @override
  void write(Object? object) => _socket.write(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _socket.writeAll(objects, separator);

  @override
  void writeln([Object? object = '']) => _socket.writeln(object);

  @override
  void writeCharCode(int charCode) => _socket.writeCharCode(charCode);

  @override
  bool setOption(SocketOption option, bool enabled) =>
      _socket.setOption(option, enabled);

  @override
  Uint8List getRawOption(RawSocketOption option) =>
      _socket.getRawOption(option);

  @override
  void setRawOption(RawSocketOption option) => _socket.setRawOption(option);
}
