import 'dart:async';
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

final class LiveFrameGuard {
  LiveFrameGuard(this.limit);

  final int limit;
  final List<int> _header = <int>[];
  int _payloadLeft = 0;
  int _messageBytes = 0;

  bool admit(List<int> chunk) {
    int index = 0;
    while (index < chunk.length) {
      if (_payloadLeft > 0) {
        final int taken = min(_payloadLeft, chunk.length - index);
        _payloadLeft -= taken;
        index += taken;
        continue;
      }
      _header.add(chunk[index]);
      index++;
      final int? headerLength = _headerLength();
      if (headerLength == null || _header.length < headerLength) {
        continue;
      }
      if (!_frameFits()) {
        return false;
      }
      _header.clear();
    }
    return true;
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

  bool _frameFits() {
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
        return false;
      }
      length = length * 256 + _header[2 + index];
    }
    if (opcode >= _firstControlOpcode) {
      if (length > _maxControlPayload) {
        return false;
      }
      _payloadLeft = length;
      return true;
    }
    final int total = (opcode == _continuation ? _messageBytes : 0) + length;
    if (total > limit) {
      return false;
    }
    _messageBytes = fin ? 0 : total;
    _payloadLeft = length;
    return true;
  }
}

Stream<Uint8List> guardedFrames(
  Stream<Uint8List> source,
  LiveFrameGuard guard,
  void Function() onRefused,
) {
  bool refused = false;
  return source.transform(
    StreamTransformer<Uint8List, Uint8List>.fromHandlers(
      handleData: (Uint8List chunk, EventSink<Uint8List> sink) {
        if (refused) {
          return;
        }
        if (guard.admit(chunk)) {
          sink.add(chunk);
          return;
        }
        refused = true;
        onRefused();
      },
    ),
  );
}

final class GuardedSocket extends StreamView<Uint8List> implements Socket {
  GuardedSocket(this._socket, Stream<Uint8List> incoming) : super(incoming);

  final Socket _socket;

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
  Future<void> addStream(Stream<List<int>> stream) => _socket.addStream(stream);

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
