import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:field_notes/data/media/live_audio_channel.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_level.dart';
import 'package:field_notes/features/capture/audio/natural_voice_chain.dart';
import 'package:record/record.dart';

const int liveAudioSampleRate = 48000;
const int liveAudioChannels = 1;
const int liveAudioBitRate = 96000;

const int _bytesPerSample = 2;
const int _meterVolume = 100;
const String _flushRequest = 'flush';
const String _closeRequest = 'close';
const Duration _chainCloseWait = Duration(seconds: 1);

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
    required this.writing,
  }) : outputToSkip = chain.delaySamples;

  final AudioRecorder recorder;
  final RunningVoiceChain chain;
  final int encoderId;
  StreamSubscription<Uint8List>? chunks;
  Future<void> tail = Future<void>.value();
  bool writing;
  bool paused = false;
  int outputToSkip;
  int samplesWritten = 0;
  Object? failure;
}

class LiveAudioCapture {
  LiveAudioCapture({
    this._recorderFactory = AudioRecorder.new,
    this._encoder = const LiveEncoder(),
    this._chainRunner = runVoiceChainInIsolate,
  });

  final AudioRecorderFactory _recorderFactory;
  final LiveEncoder _encoder;
  final VoiceChainRunner _chainRunner;
  final StreamController<double> _levels = StreamController<double>.broadcast();
  late final Stream<double> _levelStream = _levels.stream;
  AudioRecorder? _recorder;
  _ActiveTake? _take;
  int _generation = 0;

  AudioRecorder get _microphone => _recorder ??= _recorderFactory();

  Stream<double> get level => _levelStream;

  bool get running => _take != null;

  Duration get written => _durationOf(_take?.samplesWritten ?? 0);

  static Duration _durationOf(int samples) => Duration(
    microseconds:
        samples * Duration.microsecondsPerSecond ~/ liveAudioSampleRate,
  );

  Future<bool> hasPermission() => _microphone.hasPermission();

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
      writing: !armed,
    );
    _take = take;
    try {
      final Stream<Uint8List> chunks = await recorder.startStream(
        liveAudioRecordConfig(input),
      );
      take.chunks = chunks.listen(
        (Uint8List chunk) => _receive(take, chunk),
        onError: (Object error) => take.failure ??= error,
      );
    } catch (_) {
      if (identical(_take, take)) {
        _take = null;
      }
      await _quietly(() => _encoder.cancel(encoderId));
      await chain.close();
      rethrow;
    }
  }

  void beginWriting() {
    _take?.writing = true;
  }

  Future<void> pause() async {
    final _ActiveTake? take = _take;
    if (take == null) {
      return;
    }
    take.paused = true;
    await take.recorder.pause();
  }

  Future<void> resume() async {
    final _ActiveTake? take = _take;
    if (take == null) {
      return;
    }
    await take.recorder.resume();
    take.paused = false;
  }

  void _receive(_ActiveTake take, Uint8List chunk) {
    if (take.paused || chunk.isEmpty) {
      return;
    }
    final bool writing = take.writing;
    take.tail = take.tail.then((_) => _process(take, chunk, writing));
  }

  Future<void> _process(_ActiveTake take, Uint8List chunk, bool writing) async {
    if (take.failure != null) {
      return;
    }
    try {
      if (!writing) {
        take.outputToSkip += chunk.lengthInBytes ~/ _bytesPerSample;
      }
      final Uint8List processed = await take.chain.process(chunk);
      final double? level = inputLevelOf(processed, _meterVolume);
      if (level != null && !_levels.isClosed) {
        _levels.add(level);
      }
      await _append(take, processed);
    } catch (error) {
      take.failure ??= error;
    }
  }

  Future<void> _append(_ActiveTake take, Uint8List processed) async {
    final int samples = processed.lengthInBytes ~/ _bytesPerSample;
    final int skipped = take.outputToSkip < samples
        ? take.outputToSkip
        : samples;
    take.outputToSkip -= skipped;
    if (skipped == samples) {
      return;
    }
    final Uint8List kept = Uint8List.sublistView(
      processed,
      skipped * _bytesPerSample,
      samples * _bytesPerSample,
    );
    await _encoder.append(take.encoderId, kept);
    take.samplesWritten += samples - skipped;
  }

  Future<LiveAudioTake> stop() async {
    final _ActiveTake? take = _take;
    if (take == null) {
      throw StateError('No live audio take is running.');
    }
    try {
      await take.recorder.stop();
      await take.chunks?.cancel();
      await take.tail;
      final Object? failure = take.failure;
      if (failure != null) {
        throw failure;
      }
      await _append(take, await take.chain.flush());
      final String path = await _encoder.close(take.encoderId);
      return LiveAudioTake(
        path: path,
        durationMs: _durationOf(take.samplesWritten).inMilliseconds,
      );
    } catch (_) {
      await _quietly(() => _encoder.cancel(take.encoderId));
      rethrow;
    } finally {
      await _quietly(take.chain.close);
      if (identical(_take, take)) {
        _take = null;
      }
    }
  }

  Future<void> cancel() async {
    _generation += 1;
    final _ActiveTake? take = _take;
    if (take == null) {
      await _quietly(() async => _recorder?.cancel());
      return;
    }
    _take = null;
    take.paused = true;
    await _quietly(take.recorder.cancel);
    await _quietly(() async => take.chunks?.cancel());
    await _quietly(() => take.tail);
    await _quietly(() => _encoder.cancel(take.encoderId));
    await _quietly(take.chain.close);
  }

  Future<void> dispose() async {
    await cancel();
    await _levels.close();
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
