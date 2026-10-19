import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:field_notes/data/media/live_audio_channel.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_level.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/audio/natural_voice_chain.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:record/record.dart';

const int liveAudioSampleRate = 48000;
const int liveAudioChannels = 1;
const int liveAudioBitRate = 96000;

const int _bytesPerSample = 2;
const int _meterVolume = 100;
const String _flushRequest = 'flush';
const String _closeRequest = 'close';
const Duration _chainCloseWait = Duration(seconds: 1);
const int _mostSamplesHeldForTheEncoder = liveAudioSampleRate;
const int _mostSilenceSamplesAtOnce = liveAudioSampleRate;
const Duration _openWithin = Duration(seconds: 2);
const Duration _silentFor = Duration(seconds: 2);
const Duration _lostAfter = Duration(milliseconds: 500);
const Duration _gapLongerThan = Duration(milliseconds: 500);
const Duration _releaseWithin = Duration(seconds: 2);
const double _fullScale = 32768;
const double _digitalSilenceDbfs = -70;
const String _microphoneStopped = 'microphone stopped';
final double _silenceAmplitude =
    _fullScale * math.pow(10, _digitalSilenceDbfs / 20).toDouble();

abstract interface class RunningVoiceChain {
  int get delaySamples;

  Future<Uint8List> process(Uint8List pcm16);

  Future<Uint8List> flush();

  Future<void> close();
}

typedef VoiceChainRunner = Future<RunningVoiceChain> Function({
  required InputProfile profile,
  required int volume,
});

class LiveAudioTake {
  const LiveAudioTake({required this.path, required this.durationMs});

  final String path;
  final int durationMs;
}

class VoiceChainFailure implements Exception {
  const VoiceChainFailure(this.cause);

  final Object? cause;

  @override
  String toString() => 'VoiceChainFailure: $cause';
}

Future<RunningVoiceChain> runVoiceChainInline({
  required InputProfile profile,
  required int volume,
}) async =>
    _InlineVoiceChain(NaturalVoiceChain(profile: profile, volume: volume));

Future<RunningVoiceChain> runVoiceChainInIsolate({
  required InputProfile profile,
  required int volume,
}) => _IsolateVoiceChain.spawn(profile: profile, volume: volume);

class _InlineVoiceChain implements RunningVoiceChain {
  _InlineVoiceChain(this._chain);

  final NaturalVoiceChain _chain;

  @override
  int get delaySamples => _chain.delaySamples;

  @override
  Future<Uint8List> process(Uint8List pcm16) async => _chain.process(pcm16);

  @override
  Future<Uint8List> flush() async => _chain.flush();

  @override
  Future<void> close() async => _chain.dispose();
}

typedef _ChainStart = ({SendPort replies, InputProfile profile, int volume});

void _runChainIsolate(_ChainStart start) {
  final NaturalVoiceChain chain = NaturalVoiceChain(
    profile: start.profile,
    volume: start.volume,
  );
  final ReceivePort requests = ReceivePort();
  start.replies.send((requests: requests.sendPort, delay: chain.delaySamples));
  requests.listen((Object? request) {
    if (request == _closeRequest) {
      chain.dispose();
      requests.close();
      start.replies.send(_closeRequest);
      return;
    }
    try {
      final Uint8List output = request is Uint8List
          ? chain.process(request)
          : chain.flush();
      start.replies.send(TransferableTypedData.fromList(<TypedData>[output]));
    } catch (error) {
      start.replies.send(VoiceChainFailure(error.toString()));
    }
  });
}

class _IsolateVoiceChain implements RunningVoiceChain {
  _IsolateVoiceChain._(
    this._isolate,
    this._replies,
    this._requests,
    this.delaySamples,
    this._pending,
    this._closed,
  );

  static Future<RunningVoiceChain> spawn({
    required InputProfile profile,
    required int volume,
  }) async {
    final ReceivePort replies = ReceivePort();
    final Completer<({SendPort requests, int delay})> ready =
        Completer<({SendPort requests, int delay})>();
    final Queue<Completer<Uint8List>> pending = Queue<Completer<Uint8List>>();
    final Completer<void> closed = Completer<void>();
    replies.listen((Object? reply) {
      if (reply == _closeRequest) {
        if (!closed.isCompleted) {
          closed.complete();
        }
        return;
      }
      if (reply is ({SendPort requests, int delay})) {
        ready.complete(reply);
        return;
      }
      if (reply is TransferableTypedData && pending.isNotEmpty) {
        pending.removeFirst().complete(reply.materialize().asUint8List());
        return;
      }
      final VoiceChainFailure failure = reply is VoiceChainFailure
          ? reply
          : VoiceChainFailure(reply);
      if (!ready.isCompleted) {
        ready.completeError(failure);
      }
      while (pending.isNotEmpty) {
        pending.removeFirst().completeError(failure);
      }
    });
    final Isolate isolate;
    try {
      isolate = await Isolate.spawn<_ChainStart>(
        _runChainIsolate,
        (replies: replies.sendPort, profile: profile, volume: volume),
        onError: replies.sendPort,
        errorsAreFatal: true,
      );
    } catch (error) {
      replies.close();
      throw VoiceChainFailure(error);
    }
    try {
      final ({SendPort requests, int delay}) handshake = await ready.future;
      return _IsolateVoiceChain._(
        isolate,
        replies,
        handshake.requests,
        handshake.delay,
        pending,
        closed,
      );
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      replies.close();
      rethrow;
    }
  }

  final Isolate _isolate;
  final ReceivePort _replies;
  final SendPort _requests;
  final Queue<Completer<Uint8List>> _pending;
  final Completer<void> _closed;

  @override
  final int delaySamples;

  Future<Uint8List> _ask(Object request) {
    final Completer<Uint8List> reply = Completer<Uint8List>();
    _pending.add(reply);
    _requests.send(request);
    return reply.future;
  }

  @override
  Future<Uint8List> process(Uint8List pcm16) => _ask(pcm16);

  @override
  Future<Uint8List> flush() => _ask(_flushRequest);

  @override
  Future<void> close() async {
    _requests.send(_closeRequest);
    try {
      await _closed.future.timeout(_chainCloseWait);
    } on TimeoutException {
      _isolate.kill(priority: Isolate.immediate);
    }
    _isolate.kill();
    _replies.close();
    while (_pending.isNotEmpty) {
      _pending.removeFirst().completeError(const VoiceChainFailure('closed'));
    }
  }
}

RecordConfig liveAudioRecordConfig(AudioInput input) {
  final String? id = input.id;
  return RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: liveAudioSampleRate,
    numChannels: liveAudioChannels,
    device: id == null ? null : InputDevice(id: id, label: input.label),
    androidConfig: const AndroidRecordConfig(
      audioSource: AndroidAudioSource.voiceRecognition,
    ),
  );
}

class _ActiveTake {
  _ActiveTake({
    required this.recorder,
    required this.chain,
    required this.encoderId,
    required this.config,
    required int volume,
    required this.writing,
    required Duration now,
  }) : outputToSkip = chain.delaySamples,
       studio = NaturalVoiceChain(profile: InputProfile.studio, volume: volume),
       attemptAt = now,
       lastChunkAt = now,
       writingFrom = now,
       lastWrittenAt = now;

  AudioRecorder recorder;
  final RunningVoiceChain chain;
  final NaturalVoiceChain studio;
  final int encoderId;
  final RecordConfig config;
  final Completer<void> opened = Completer<void>();
  StreamSubscription<Uint8List>? chunks;
  Timer? watchdog;
  Future<void> tail = Future<void>.value();
  bool writing;
  bool paused = false;
  Duration pausedAt = Duration.zero;
  bool closing = false;
  bool chainBroken = false;
  bool encoderGivenUp = false;
  bool streamOpen = false;
  bool heardSinceAttempt = false;
  bool trimPending = false;
  int attempt = 0;
  Duration attemptAt;
  Duration lastChunkAt;
  Duration? quietSince;
  Duration writingFrom;
  Duration lastWrittenAt;
  Uint8List untaken = Uint8List(0);
  Uint8List carriedByte = Uint8List(0);
  int outputToSkip;
  int samplesHeard = 0;
  int samplesSent = 0;
  int samplesWritten = 0;

  Uint8List wholeSamplesOf(Uint8List chunk) {
    final Uint8List joined = _joined(carriedByte, chunk);
    final int whole = joined.length - joined.length % _bytesPerSample;
    carriedByte = Uint8List.fromList(Uint8List.sublistView(joined, whole));
    return Uint8List.sublistView(joined, 0, whole);
  }
}

Uint8List _joined(Uint8List head, Uint8List tail) => head.isEmpty
    ? tail
    : (Uint8List(head.length + tail.length)
        ..setAll(0, head)
        ..setAll(head.length, tail));

int _samplesIn(Duration span) =>
    span.inMicroseconds * liveAudioSampleRate ~/ Duration.microsecondsPerSecond;

int _samplesOf(Uint8List pcm) => pcm.lengthInBytes ~/ _bytesPerSample;

bool _isDigitalSilence(Uint8List pcm) {
  final ByteData samples = ByteData.sublistView(pcm);
  for (int offset = 0; offset < pcm.lengthInBytes; offset += _bytesPerSample) {
    if (samples.getInt16(offset, Endian.little).abs() >= _silenceAmplitude) {
      return false;
    }
  }
  return true;
}

bool _saysMicrophoneStopped(Object error) =>
    '$error'.contains(_microphoneStopped);

Duration Function() _stopwatchClock() {
  final Stopwatch stopwatch = clock.stopwatch()..start();
  return () => stopwatch.elapsed;
}

class LiveAudioCapture {
  LiveAudioCapture({
    this._recorderFactory = AudioRecorder.new,
    this._encoder = const LiveEncoder(),
    this._chainRunner = runVoiceChainInIsolate,
    Duration Function()? clock,
  }) : _clock = clock ?? _stopwatchClock();

  final AudioRecorderFactory _recorderFactory;
  final LiveEncoder _encoder;
  final VoiceChainRunner _chainRunner;
  final Duration Function() _clock;
  final StreamController<double> _levels = StreamController<double>.broadcast();
  late final Stream<double> _levelStream = _levels.stream;
  final StreamController<MicrophoneHearing> _hearing =
      StreamController<MicrophoneHearing>.broadcast();
  late final Stream<MicrophoneHearing> _hearingStream = _hearing.stream;
  MicrophoneHearing _hearingNow = MicrophoneHearing.opening;
  AudioRecorder? _recorder;
  _ActiveTake? _take;
  int _generation = 0;

  AudioRecorder get _microphone => _recorder ??= _recorderFactory();

  Stream<double> get level => _levelStream;

  Stream<MicrophoneHearing> get hearing => _hearingStream;

  MicrophoneHearing get hearingNow => _hearingNow;

  bool get running => _take != null;

  Duration get written => _durationOf(_take?.samplesWritten ?? 0);

  static Duration _durationOf(int samples) => Duration(
    microseconds:
        samples * Duration.microsecondsPerSecond ~/ liveAudioSampleRate,
  );

  Future<bool> hasPermission() => _microphone.hasPermission();

  void _hear(MicrophoneHearing next) {
    if (next == _hearingNow) {
      return;
    }
    _hearingNow = next;
    if (!_hearing.isClosed) {
      _hearing.add(next);
    }
  }

  Future<void> start({
    required AudioInput input,
    required InputProfile profile,
    required int volume,
    required String path,
    bool armed = false,
  }) async {
    final int generation = ++_generation;
    final AudioRecorder recorder = _microphone;
    final RunningVoiceChain chain = await _chainRunner(
      profile: profile,
      volume: volume,
    );
    final int encoderId;
    try {
      encoderId = await _encoder.open(
        path: path,
        sampleRate: liveAudioSampleRate,
        channels: liveAudioChannels,
        bitRate: liveAudioBitRate,
      );
    } catch (_) {
      await chain.close();
      rethrow;
    }
    if (generation != _generation) {
      await _quietly(() => _encoder.cancel(encoderId));
      await chain.close();
      return;
    }
    final _ActiveTake take = _ActiveTake(
      recorder: recorder,
      chain: chain,
      encoderId: encoderId,
      config: liveAudioRecordConfig(input),
      volume: volume,
      writing: !armed,
      now: _clock(),
    );
    _take = take;
    _hear(MicrophoneHearing.opening);
    _watch(take);
    unawaited(_open(take, recorder, take.attempt));
    try {
      await take.opened.future;
    } catch (_) {
      _close(take);
      if (identical(_take, take)) {
        _take = null;
      }
      await _quietly(() => _encoder.cancel(encoderId));
      await chain.close();
      rethrow;
    }
  }

  Future<void> _open(
    _ActiveTake take,
    AudioRecorder recorder,
    int attempt,
  ) async {
    final Stream<Uint8List> chunks;
    try {
      chunks = await recorder.startStream(take.config);
    } catch (error, stackTrace) {
      if (attempt == take.attempt && !take.opened.isCompleted) {
        take.opened.completeError(error, stackTrace);
        return;
      }
      debugPrint('Live audio microphone reopen failed: $error\n$stackTrace');
      return;
    }
    if (attempt != take.attempt || take.closing) {
      return;
    }
    take.streamOpen = true;
    _settle(take);
    take.chunks = chunks.listen(
      (Uint8List chunk) => _receive(take, attempt, chunk),
      onError: (Object error, StackTrace stackTrace) =>
          _failed(take, attempt, error, stackTrace),
    );
    if (take.paused) {
      unawaited(_quietly(recorder.pause));
    }
  }

  void _settle(_ActiveTake take) {
    if (take.opened.isCompleted) {
      return;
    }
    if (take.writing) {
      take.lastWrittenAt = _clock();
    }
    take.opened.complete();
  }

  void _close(_ActiveTake take) {
    take.closing = true;
    take.watchdog?.cancel();
    if (!take.opened.isCompleted) {
      take.opened.complete();
    }
  }

  void _watch(_ActiveTake take) {
    take.watchdog?.cancel();
    if (take.closing || take.paused) {
      return;
    }
    final Duration wait = _dueAt(take) - _clock();
    take.watchdog = Timer(
      wait.isNegative ? Duration.zero : wait,
      () => _check(take),
    );
  }

  Duration _dueAt(_ActiveTake take) {
    if (take.heardSinceAttempt) {
      return take.lastChunkAt + _lostAfter;
    }
    return take.attemptAt +
        (_hearingNow == MicrophoneHearing.lost ? _lostAfter : _openWithin);
  }

  void _check(_ActiveTake take) {
    if (take.closing || take.paused) {
      return;
    }
    if (_clock() < _dueAt(take)) {
      _watch(take);
      return;
    }
    if (!take.heardSinceAttempt) {
      if (_hearingNow != MicrophoneHearing.lost) {
        _hear(MicrophoneHearing.cannotHear);
      }
      _settle(take);
    } else if (_hearingNow == MicrophoneHearing.hearing) {
      _hear(MicrophoneHearing.lost);
    }
    _reopen(take);
  }

  void _reopen(_ActiveTake take) {
    final AudioRecorder dropped = take.recorder;
    final StreamSubscription<Uint8List>? listening = take.chunks;
    take
      ..attempt += 1
      ..chunks = null
      ..streamOpen = false
      ..heardSinceAttempt = false
      ..quietSince = null
      ..carriedByte = Uint8List(0)
      ..attemptAt = _clock();
    unawaited(_quietly(() async => listening?.cancel()));
    unawaited(_quietly(dropped.cancel));
    unawaited(_quietly(dropped.dispose));
    final AudioRecorder fresh = _recorderFactory();
    take.recorder = fresh;
    _recorder = fresh;
    unawaited(_open(take, fresh, take.attempt));
    _watch(take);
  }

  void _failed(
    _ActiveTake take,
    int attempt,
    Object error,
    StackTrace stackTrace,
  ) {
    if (attempt != take.attempt) {
      return;
    }
    if (!_saysMicrophoneStopped(error) || take.closing || take.paused) {
      debugPrint(
        'Live audio microphone error, still listening: $error\n$stackTrace',
      );
      return;
    }
    debugPrint('Live audio microphone stopped, reopening: $error');
    if (_hearingNow == MicrophoneHearing.hearing) {
      _hear(MicrophoneHearing.lost);
    }
    _reopen(take);
  }

  void beginWriting() {
    final _ActiveTake? take = _take;
    if (take == null || take.writing) {
      return;
    }
    final Duration now = _clock();
    take
      ..writing = true
      ..trimPending = true
      ..writingFrom = now
      ..lastWrittenAt = now;
  }

  Future<void> pause() async {
    final _ActiveTake? take = _take;
    if (take == null) {
      return;
    }
    if (!take.paused) {
      take.pausedAt = _clock();
    }
    take.paused = true;
    take.watchdog?.cancel();
    if (take.streamOpen) {
      await take.recorder.pause();
    }
  }

  Future<void> resume() async {
    final _ActiveTake? take = _take;
    if (take == null) {
      return;
    }
    if (take.streamOpen) {
      await take.recorder.resume();
    }
    final Duration now = _clock();
    take
      ..lastChunkAt = now
      ..lastWrittenAt = now
      ..paused = false;
    if (!take.heardSinceAttempt) {
      take.attemptAt = now;
    }
    _watch(take);
  }

  void _receive(_ActiveTake take, int attempt, Uint8List chunk) {
    if (attempt != take.attempt) {
      return;
    }
    final Uint8List whole = take.wholeSamplesOf(chunk);
    if (take.paused || whole.isEmpty) {
      return;
    }
    final Duration now = _clock();
    final bool firstOfAttempt = !take.heardSinceAttempt;
    take
      ..lastChunkAt = now
      ..heardSinceAttempt = true;
    if (firstOfAttempt) {
      _watch(take);
    }
    _hearChunk(take, whole, now);
    if (!take.writing) {
      _queue(take, whole, writing: false);
      return;
    }
    final bool firstSinceWritingBegan = take.trimPending;
    final Uint8List kept = _afterWritingBegan(take, whole, now);
    if (kept.isEmpty) {
      return;
    }
    final Duration gap =
        now - _durationOf(_samplesOf(kept)) - take.lastWrittenAt;
    final bool chunksStopped = firstSinceWritingBegan
        ? gap > _gapLongerThan
        : now - take.lastWrittenAt > _gapLongerThan;
    if (chunksStopped) {
      _queueSilence(take, gap);
    }
    _queue(take, kept, writing: true);
    take.lastWrittenAt = now;
  }

  void _hearChunk(_ActiveTake take, Uint8List pcm, Duration now) {
    if (!_isDigitalSilence(pcm)) {
      take.quietSince = null;
      _hear(MicrophoneHearing.hearing);
      return;
    }
    final Duration quietSince = take.quietSince ??=
        now - _durationOf(_samplesOf(pcm));
    _hear(
      now - quietSince >= _silentFor
          ? MicrophoneHearing.cannotHear
          : MicrophoneHearing.hearing,
    );
  }

  Uint8List _afterWritingBegan(_ActiveTake take, Uint8List pcm, Duration now) {
    if (!take.trimPending) {
      return pcm;
    }
    take.trimPending = false;
    final int samples = _samplesOf(pcm);
    final int kept = _samplesIn(now - take.writingFrom).clamp(0, samples);
    if (kept == samples) {
      return pcm;
    }
    final int splitAt = (samples - kept) * _bytesPerSample;
    _queue(take, Uint8List.sublistView(pcm, 0, splitAt), writing: false);
    return Uint8List.sublistView(pcm, splitAt);
  }

  void _queueSilence(_ActiveTake take, Duration span) {
    for (
      int left = _samplesIn(span);
      left > 0;
      left -= _mostSilenceSamplesAtOnce
    ) {
      final int samples = left < _mostSilenceSamplesAtOnce
          ? left
          : _mostSilenceSamplesAtOnce;
      _queue(
        take,
        Uint8List(samples * _bytesPerSample),
        writing: true,
        heard: false,
      );
    }
  }

  void _queue(
    _ActiveTake take,
    Uint8List pcm, {
    required bool writing,
    bool heard = true,
  }) {
    take.tail = take.tail.then((_) => _process(take, pcm, writing, heard));
  }

  Future<void> _process(
    _ActiveTake take,
    Uint8List chunk,
    bool writing,
    bool heard,
  ) async {
    final Uint8List processed = await _cleaned(take, chunk, writing);
    if (writing) {
      take.samplesHeard += chunk.lengthInBytes ~/ _bytesPerSample;
    }
    final double? level = heard ? inputLevelOf(processed, _meterVolume) : null;
    if (level != null && !_levels.isClosed) {
      _levels.add(level);
    }
    await _append(take, processed);
  }

  Future<Uint8List> _cleaned(
    _ActiveTake take,
    Uint8List chunk,
    bool writing,
  ) async {
    if (take.chainBroken) {
      return writing ? take.studio.process(chunk) : Uint8List(0);
    }
    try {
      if (!writing) {
        take.outputToSkip += chunk.lengthInBytes ~/ _bytesPerSample;
      }
      return await take.chain.process(chunk);
    } catch (error, stackTrace) {
      debugPrint(
        'Voice chain failed, writing the input at its volume: '
        '$error\n$stackTrace',
      );
      return _afterChainBroke(take, chunk, writing);
    }
  }

  Uint8List _afterChainBroke(_ActiveTake take, Uint8List chunk, bool writing) {
    take.chainBroken = true;
    take.outputToSkip = 0;
    if (!writing) {
      return Uint8List(0);
    }
    final int lostToTheChain = take.samplesHeard - take.samplesSent;
    final Uint8List input = take.studio.process(chunk);
    if (lostToTheChain <= 0) {
      return input;
    }
    return Uint8List(lostToTheChain * _bytesPerSample + input.length)
      ..setAll(lostToTheChain * _bytesPerSample, input);
  }

  Future<void> _append(_ActiveTake take, Uint8List processed) async {
    final int samples = processed.lengthInBytes ~/ _bytesPerSample;
    final int skipped = take.outputToSkip < samples
        ? take.outputToSkip
        : samples;
    take.outputToSkip -= skipped;
    if (skipped == samples) {
      return _send(take, Uint8List(0));
    }
    final Uint8List kept = Uint8List.sublistView(
      processed,
      skipped * _bytesPerSample,
      samples * _bytesPerSample,
    );
    take.samplesSent += samples - skipped;
    await _send(take, kept);
  }

  Future<void> _send(_ActiveTake take, Uint8List kept) async {
    if (take.encoderGivenUp) {
      return;
    }
    final Uint8List batch = _joined(take.untaken, kept);
    if (batch.isEmpty) {
      return;
    }
    final int count = batch.lengthInBytes ~/ _bytesPerSample;
    try {
      await _encoder.append(take.encoderId, batch);
      take.samplesWritten += count;
      take.untaken = Uint8List(0);
    } catch (error, stackTrace) {
      final int taken = error is LiveAudioException
          ? error.framesTaken.clamp(0, count)
          : 0;
      take.samplesWritten += taken;
      take.untaken = Uint8List.fromList(
        Uint8List.sublistView(batch, taken * _bytesPerSample),
      );
      take.encoderGivenUp =
          take.untaken.lengthInBytes ~/ _bytesPerSample >
          _mostSamplesHeldForTheEncoder;
      debugPrint(
        'Live audio append failed, ${count - taken} samples held: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _appendRest(_ActiveTake take) async {
    if (take.chainBroken) {
      return;
    }
    final Uint8List rest;
    try {
      rest = await take.chain.flush();
    } catch (error, stackTrace) {
      debugPrint('Voice chain flush failed: $error\n$stackTrace');
      return;
    }
    await _append(take, rest);
  }

  Future<LiveAudioTake> stop() async {
    final _ActiveTake? take = _take;
    if (take == null) {
      throw StateError('No live audio take is running.');
    }
    final Duration keptAt = take.paused ? take.pausedAt : _clock();
    _close(take);
    try {
      await _release(take, take.recorder.stop);
      await _quietly(() async => take.chunks?.cancel());
      await take.tail;
      if (take.writing && keptAt - take.lastWrittenAt > _gapLongerThan) {
        _queueSilence(take, keptAt - take.lastWrittenAt);
        await take.tail;
      }
      await _appendRest(take);
      await _send(take, Uint8List(0));
      return LiveAudioTake(
        path: await _closed(take),
        durationMs: _durationOf(take.samplesWritten).inMilliseconds,
      );
    } finally {
      await _quietly(take.chain.close);
      if (identical(_take, take)) {
        _take = null;
      }
    }
  }

  Future<void> _release(
    _ActiveTake take,
    Future<Object?> Function() call,
  ) async {
    if (take.streamOpen && await _finishedInTime(call)) {
      return;
    }
    final AudioRecorder stuck = take.recorder;
    if (identical(_recorder, stuck)) {
      _recorder = null;
    }
    unawaited(_quietly(stuck.cancel));
    unawaited(_quietly(stuck.dispose));
  }

  static Future<bool> _finishedInTime(Future<Object?> Function() call) async {
    try {
      await call().timeout(_releaseWithin);
    } on TimeoutException {
      return false;
    } catch (_) {
      return true;
    }
    return true;
  }

  Future<String> _closed(_ActiveTake take) async {
    try {
      return await _encoder.close(take.encoderId);
    } catch (_) {
      await _discardAfterFailedClose(take);
      rethrow;
    }
  }

  Future<void> _discardAfterFailedClose(_ActiveTake take) =>
      _quietly(() => _encoder.cancel(take.encoderId));

  Future<void> cancel() async {
    _generation += 1;
    final _ActiveTake? take = _take;
    if (take == null) {
      await _quietly(() async => _recorder?.cancel());
      return;
    }
    _take = null;
    _close(take);
    take.paused = true;
    await _release(take, take.recorder.cancel);
    await _quietly(() async => take.chunks?.cancel());
    await _quietly(() => take.tail);
    await _quietly(() => _encoder.cancel(take.encoderId));
    await _quietly(take.chain.close);
  }

  Future<void> dispose() async {
    await cancel();
    await _levels.close();
    await _hearing.close();
    await _quietly(() async => _recorder?.dispose());
  }

  static Future<void> _quietly(Future<Object?> Function() call) async {
    try {
      await call();
    } catch (_) {
      return;
    }
  }
}
