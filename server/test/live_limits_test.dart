import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/auth.dart';
import 'package:relay_server/src/live.dart';
import 'package:relay_server/src/live_guard.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

const int replacedCode = 4002;
const int tooBigCode = 1009;
const int frameLimit = 4 * 1024;
const int readLimit = 64 * 1024;
const List<int> maskKey = <int>[1, 2, 3, 4];

List<int> frameHeader({required int first, required int length}) => <int>[
  first,
  if (length < 126)
    0x80 | length
  else if (length < 65536) ...<int>[
    0x80 | 126,
    length >> 8,
    length & 0xff,
  ] else ...<int>[
    0x80 | 127,
    for (int shift = 56; shift >= 0; shift -= 8) (length >> shift) & 0xff,
  ],
  ...maskKey,
];

const Timeout socketTimeout = Timeout(Duration(minutes: 2));
const int rawLimit = 16 * 1024;

Future<bool> eventually(
  bool Function() condition, {
  Duration within = const Duration(seconds: 10),
}) async {
  final Stopwatch watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > within) {
      return false;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return true;
}

String upgradeRequest(Uri live, SignedIn who) =>
    'GET ${live.path} HTTP/1.1\r\n'
    'Host: ${live.host}:${live.port}\r\n'
    'Upgrade: websocket\r\n'
    'Connection: Upgrade\r\n'
    'Sec-WebSocket-Key: ${base64.encode(List<int>.generate(16, (int index) => index))}\r\n'
    'Sec-WebSocket-Version: 13\r\n'
    '${SyncHeaders.protocol}: $syncProtocolVersion\r\n'
    '${SyncHeaders.authorization}: ${who.session.authorization}\r\n'
    '\r\n';

int? closeCodeIn(List<int> bytes) {
  int index = 0;
  while (index + 2 <= bytes.length) {
    final int opcode = bytes[index] & 0x0f;
    int length = bytes[index + 1] & 0x7f;
    int header = 2;
    if (length == 126 && index + 4 <= bytes.length) {
      length = (bytes[index + 2] << 8) | bytes[index + 3];
      header = 4;
    } else if (length == 127 && index + 10 <= bytes.length) {
      length = 0;
      for (int offset = 2; offset < 10; offset++) {
        length = length * 256 + bytes[index + offset];
      }
      header = 10;
    }
    if (opcode == 0x8 && length >= 2 && index + header + 2 <= bytes.length) {
      return (bytes[index + header] << 8) | bytes[index + header + 1];
    }
    index += header + length;
  }
  return null;
}

final class RawPeer {
  RawPeer._(this.socket) {
    socket.listen(
      (RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final Uint8List? data = socket.read();
          if (data != null) {
            _bytes.addAll(data);
          }
        } else if (event == RawSocketEvent.readClosed) {
          readClosed = true;
        }
      },
      onError: (Object _) {
        reset = true;
      },
      cancelOnError: false,
    );
  }

  static Future<RawPeer> open(RelayHarness harness, SignedIn who) async {
    final Uri live = SyncRoutes.live.uri(harness.baseUrl);
    final RawPeer peer = RawPeer._(
      await RawSocket.connect(live.host, live.port),
    );
    await peer.send(latin1.encode(upgradeRequest(live, who)));
    expect(await eventually(() => peer._headLength != null), isTrue);
    expect(latin1.decode(peer._bytes), startsWith('HTTP/1.1 101'));
    return peer;
  }

  final RawSocket socket;
  final List<int> _bytes = <int>[];
  bool readClosed = false;
  bool reset = false;

  int? get _headLength {
    final int end = latin1.decode(_bytes).indexOf('\r\n\r\n');
    return end < 0 ? null : end + 4;
  }

  List<int> get received => _bytes.sublist(_headLength ?? _bytes.length);

  void pause() {
    socket.readEventsEnabled = false;
  }

  void resume() {
    socket.readEventsEnabled = true;
  }

  Future<void> send(List<int> bytes) async {
    int offset = 0;
    while (offset < bytes.length) {
      offset += socket.write(bytes, offset);
      if (offset < bytes.length) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }
  }

  bool poke() {
    if (!reset) {
      try {
        socket.write(frameHeader(first: 0x8a, length: 0));
      } on SocketException {
        reset = true;
      }
    }
    return reset;
  }
}

final class RawLive {
  RawLive._(this.socket) {
    socket.done.ignore();
    socket.listen(
      (Uint8List data) {
        if (upgraded.isCompleted) {
          return;
        }
        _head.addAll(data);
        final String text = latin1.decode(_head);
        final int end = text.indexOf('\r\n\r\n');
        if (end >= 0) {
          upgraded.complete(text.substring(0, end));
        }
      },
      onDone: _finish,
      onError: (Object _) => _finish(),
      cancelOnError: true,
    );
  }

  static Future<RawLive> open(RelayHarness harness, SignedIn who) async {
    final Uri live = SyncRoutes.live.uri(harness.baseUrl);
    final Socket socket = await Socket.connect(live.host, live.port);
    final RawLive raw = RawLive._(socket);
    socket.add(latin1.encode(upgradeRequest(live, who)));
    expect(await raw.upgraded.future, startsWith('HTTP/1.1 101'));
    return raw;
  }

  final Socket socket;
  final List<int> _head = <int>[];
  final Completer<String> upgraded = Completer<String>();
  final Completer<void> _closed = Completer<void>();

  Future<void> get closed => _closed.future;

  Future<void> send(List<int> bytes) async {
    if (_closed.isCompleted) {
      return;
    }
    socket.add(bytes);
    try {
      await socket.flush();
    } on SocketException {
      return;
    }
  }

  void _finish() {
    if (!_closed.isCompleted) {
      _closed.complete();
    }
    if (!upgraded.isCompleted) {
      upgraded.completeError(StateError('closed before the upgrade'));
    }
  }
}

void main() {
  late RelayHarness harness;

  setUp(() async {
    harness = await RelayHarness.start();
  });

  tearDown(() async {
    await harness.dispose();
  });

  int admin(List<String> arguments) => runAdminCommand(
    arguments,
    config: harness.config,
    out: StringBuffer(),
    err: StringBuffer(),
    clock: harness.clock,
  );

  Future<void> expectOpen(LiveClient client) async {
    client.send(const LivePing());
    expect(await client.next(), const LivePong());
  }

  Future<void> expectClosed(LiveClient client, int code) async {
    await client.closed;
    expect(client.closeCode, code);
  }

  test('a sweep closes the sockets of an account another process suspended or deleted', () async {
    final TestAccount account = await harness.enrol();
    final TestAccount other = await harness.enrol(note: 'Other journal');
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final SignedIn otherIn = await harness.signIn(other.firstDevice);
    final LiveClient macLive = await harness.openLive(mac.token);
    final LiveClient otherLive = await harness.openLive(otherIn.token);

    expect(admin(<String>['account', 'suspend', account.accountId]), exitOk);
    await harness.tick();

    await expectClosed(macLive, liveRevokedCode);
    await expectOpen(otherLive);

    expect(admin(<String>['account', 'delete', other.accountId]), exitOk);
    await harness.tick();

    await expectClosed(otherLive, liveRevokedCode);
    expect(harness.app.live.openCount, 0);
  });

  test('marking the relay restored closes every open socket', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final LiveClient live = await harness.openLive(mac.token);
    await expectOpen(live);

    expect(admin(<String>['mark-restored']), exitOk);
    await harness.tick();

    await expectClosed(live, liveRevokedCode);
  });

  test('a socket whose session expires is closed as revoked', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn mac = await harness.signIn(account.firstDevice);
    harness.advance(sessionLifetime - const Duration(seconds: 60));
    final LiveClient live = await harness.openLive(mac.token);
    await expectOpen(live);

    harness.advance(const Duration(seconds: 60));
    await harness.tick();

    await expectClosed(live, liveRevokedCode);
  });

  test(
    'a device keeps at most four sockets and the oldest gives way',
    () async {
      final TestAccount account = await harness.enrol();
      final TestDevice phone = harness.addDevice(account);
      final SignedIn mac = await harness.signIn(account.firstDevice);
      final SignedIn phoneIn = await harness.signIn(phone);
      final List<LiveClient> macSockets = <LiveClient>[];
      for (int index = 0; index < 4; index++) {
        macSockets.add(await harness.openLive(mac.token));
      }
      final LiveClient phoneLive = await harness.openLive(phoneIn.token);
      for (final LiveClient socket in <LiveClient>[...macSockets, phoneLive]) {
        await expectOpen(socket);
      }

      final LiveClient fifth = await harness.openLive(mac.token);

      await expectClosed(macSockets.first, replacedCode);
      for (final LiveClient socket in <LiveClient>[
        ...macSockets.skip(1),
        fifth,
        phoneLive,
      ]) {
        await expectOpen(socket);
      }
      expect(harness.app.live.openCount, 5);
    },
  );

  test('a frame over 4 KiB closes the socket with 1009', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final WebSocket socket = await WebSocket.connect(
      SyncRoutes.live.uri(harness.baseUrl).replace(scheme: 'ws').toString(),
      headers: <String, Object>{
        SyncHeaders.protocol: '$syncProtocolVersion',
        SyncHeaders.authorization: mac.session.authorization,
      },
    );
    final StreamIterator<dynamic> replies = StreamIterator<dynamic>(socket);
    addTearDown(replies.cancel);

    socket.add('x' * frameLimit);
    socket.add(jsonEncode(const LivePing().toJson()));
    expect(await replies.moveNext(), isTrue);
    expect(
      LiveMessage.fromJson(decodeJsonObject(replies.current as String)),
      const LivePong(),
    );

    socket.add('x' * (frameLimit + 1));

    expect(await replies.moveNext(), isFalse);
    expect(socket.closeCode, tooBigCode);
    expect(harness.app.live.openCount, 0);
  });

  test(
    'a live message over the limit is refused before it is buffered',
    () async {
      final TestAccount account = await harness.enrol();
      final SignedIn mac = await harness.signIn(account.firstDevice);
      final RawLive live = await RawLive.open(harness, mac);
      addTearDown(live.socket.destroy);
      final List<int> header = frameHeader(
        first: 0x81,
        length: 64 * 1024 * 1024,
      );

      await live.send(<int>[
        ...header,
        ...List<int>.filled(readLimit - header.length, 0x41),
      ]);

      await live.closed;
      expect(harness.app.live.openCount, 0);
    },
  );

  test('a fragmented live message over the limit is refused', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final RawLive live = await RawLive.open(harness, mac);
    addTearDown(live.socket.destroy);
    final List<int> fragments = <int>[
      for (int index = 0; index < 63; index++) ...<int>[
        ...frameHeader(first: index == 0 ? 0x01 : 0x00, length: 1024),
        ...List<int>.filled(1024, 0x41),
      ],
    ];
    expect(fragments.length, lessThan(readLimit));

    await live.send(fragments);

    await live.closed;
    expect(harness.app.live.openCount, 0);
  });
  test('a flood of pings closes the socket', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final RawPeer peer = await RawPeer.open(harness, mac);
    addTearDown(peer.socket.close);
    peer.pause();

    await peer.send(<int>[
      for (int ping = 0; ping < 200; ping++)
        ...frameHeader(first: 0x89, length: 0),
    ]);

    expect(await eventually(() => harness.app.live.openCount == 0), isTrue);
    peer.resume();
    expect(await eventually(() => peer.readClosed || peer.reset), isTrue);
    expect(closeCodeIn(peer.received), liveTooFastCode);
  }, timeout: socketTimeout);

  test('filler frames inside an unfinished message close the socket', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final RawPeer peer = await RawPeer.open(harness, mac);
    addTearDown(peer.socket.close);
    final List<int> oneByte = <int>[
      ...frameHeader(first: 0x00, length: 1),
      0x41,
    ];
    final List<int> filler = <int>[
      ...frameHeader(first: 0x01, length: 1),
      0x41,
    ];
    int sinceOneByte = 0;
    int fillers = 0;
    while (filler.length <= rawLimit + 4096) {
      if (sinceOneByte >= 4096) {
        filler.addAll(oneByte);
        sinceOneByte = 0;
      }
      final List<int> frame = frameHeader(
        first: fillers.isEven ? 0x00 : 0x8a,
        length: 0,
      );
      filler.addAll(frame);
      sinceOneByte += frame.length;
      fillers++;
    }
    expect(filler.length, greaterThan(rawLimit));

    await peer.send(filler);

    expect(await eventually(() => harness.app.live.openCount == 0), isTrue);
    expect(await eventually(() => peer.readClosed || peer.reset), isTrue);
    expect(closeCodeIn(peer.received), anyOf(liveTooFastCode, liveTooBigCode));
  }, timeout: socketTimeout);

  test('a socket that does not finish closing is destroyed', () async {
    final ManualTimers timers = ManualTimers();
    final RelayHarness relay = await RelayHarness.start(
      startTimer: timers.start,
    );
    addTearDown(relay.dispose);
    final TestAccount account = await relay.enrol();
    final SignedIn mac = await relay.signIn(account.firstDevice);
    final RawPeer peer = await RawPeer.open(relay, mac);
    addTearDown(peer.socket.close);

    relay.advance(liveIdleLimit);
    await relay.tick();

    expect(await eventually(() => peer.readClosed), isTrue);
    expect(closeCodeIn(peer.received), liveIdleCode);
    final List<ManualTimer> deadlines = timers.pending(liveCloseLimit);
    expect(deadlines, hasLength(1));
    expect(deadlines.single.duration, const Duration(seconds: 5));
    expect(relay.app.live.closingCount, 1);
    expect(peer.poke(), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(peer.poke(), isFalse);

    deadlines.single.fire();

    expect(
      await eventually(peer.poke, within: const Duration(seconds: 3)),
      isTrue,
    );
    expect(relay.app.live.closingCount, 0);
  }, timeout: socketTimeout);

  test('the live guard allows at most 60 frames in any 60 seconds', () {
    DateTime now = harnessStart;
    final List<int> pong = frameHeader(first: 0x8a, length: 0);
    final LiveFrameGuard burst = LiveFrameGuard(frameLimit, () => now);
    for (int frame = 1; frame <= 60; frame++) {
      expect(burst.admit(pong), isNull, reason: 'frame $frame');
    }
    expect(burst.admit(pong), LiveRefusal.tooFast);

    final LiveFrameGuard spread = LiveFrameGuard(frameLimit, () => now);
    for (int frame = 1; frame <= 30; frame++) {
      expect(spread.admit(pong), isNull, reason: 'first frame $frame');
    }
    now = harnessStart.add(liveFrameWindow - const Duration(seconds: 1));
    for (int frame = 1; frame <= 30; frame++) {
      expect(spread.admit(pong), isNull, reason: 'second frame $frame');
    }
    now = harnessStart.add(liveFrameWindow);
    for (int frame = 1; frame <= 30; frame++) {
      expect(spread.admit(pong), isNull, reason: 'third frame $frame');
    }
    expect(spread.admit(pong), LiveRefusal.tooFast);
  });

  test('the live guard closes after 16 KiB with no finished message', () {
    DateTime now = harnessStart;
    final List<int> pong = <int>[
      ...frameHeader(first: 0x8a, length: 125),
      ...List<int>.filled(125, 0x41),
    ];
    final List<int> finished = <int>[
      ...frameHeader(first: 0x81, length: 1),
      0x41,
    ];
    int frames = 0;
    LiveRefusal? send(LiveFrameGuard guard, List<int> frame) {
      if (frames == 60) {
        now = now.add(liveFrameWindow);
        frames = 0;
      }
      frames++;
      return guard.admit(frame);
    }

    final LiveFrameGuard idle = LiveFrameGuard(frameLimit, () => now);
    for (int frame = 1; frame <= 125; frame++) {
      expect(send(idle, pong), isNull, reason: 'pong $frame');
    }
    expect(125 * pong.length, lessThanOrEqualTo(rawLimit));
    expect(send(idle, pong), LiveRefusal.tooBig);

    final LiveFrameGuard talking = LiveFrameGuard(frameLimit, () => now);
    for (int frame = 1; frame <= 125; frame++) {
      expect(send(talking, pong), isNull, reason: 'first pong $frame');
    }
    expect(send(talking, finished), isNull);
    for (int frame = 1; frame <= 125; frame++) {
      expect(send(talking, pong), isNull, reason: 'second pong $frame');
    }
  });
}
