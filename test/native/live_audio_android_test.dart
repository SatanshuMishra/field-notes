import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _kotlinRoot = 'android/app/src/main/kotlin';
const String _kotlin = '$_kotlinRoot/dev/satanshumishra/field_notes';
const String _liveAudio = '$_kotlin/LiveAudioChannel.kt';
const String _mainActivity = '$_kotlin/MainActivity.kt';

String _read(String path) {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  return file.readAsStringSync();
}

String _block(String source, String opening) {
  final int start = source.indexOf(opening);
  expect(start, isNot(-1), reason: '$opening must exist');
  final int open = source.indexOf('{', start);
  expect(open, isNot(-1), reason: '$opening must open a block');
  int depth = 0;
  for (int index = open; index < source.length; index += 1) {
    if (source[index] == '{') {
      depth += 1;
    } else if (source[index] == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(start, index + 1);
      }
    }
  }
  fail('$opening never closes');
}

Map<String, String> _kotlinSources() {
  final List<File> files =
      Directory(_kotlinRoot)
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.kt'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  return <String, String>{
    for (final File file in files) file.path: file.readAsStringSync(),
  };
}

void main() {
  test('the Android runner registers live audio and drops audio clean', () {
    final Map<String, String> sources = _kotlinSources();
    expect(sources, isNotEmpty);

    for (final MapEntry<String, String> source in sources.entries) {
      expect(source.value, isNot(contains('decodeAudio')), reason: source.key);
      expect(source.value, isNot(contains('replaceAudio')), reason: source.key);
      expect(
        source.value,
        isNot(contains('field_notes/audio_clean')),
        reason: source.key,
      );
      expect(
        source.value,
        isNot(contains('AudioCleanChannel')),
        reason: source.key,
      );
    }
    expect(File('$_kotlin/AudioCleanChannel.kt').existsSync(), isFalse);

    final List<String> registering = sources.entries
        .where(
          (MapEntry<String, String> source) =>
              source.value.contains('"field_notes/live_audio"'),
        )
        .map((MapEntry<String, String> source) => source.key)
        .toList();
    expect(registering, <String>[_liveAudio]);

    final String channel = _read(_liveAudio);
    final String activity = _read(_mainActivity);

    final String engine = _block(
      activity,
      'override fun configureFlutterEngine(',
    );
    expect(
      engine,
      contains(
        'LiveAudioChannel().register(flutterEngine.dartExecutor.binaryMessenger)',
      ),
    );
    expect(
      engine,
      contains(
        'AudioPeaksChannel().register(flutterEngine.dartExecutor.binaryMessenger)',
      ),
    );

    expect(channel, contains('class LiveAudioChannel {'));
    expect(channel, contains('const val CHANNEL = "field_notes/live_audio"'));
    expect(channel, contains('const val OPEN_ENCODER = "openEncoder"'));
    expect(channel, contains('const val APPEND_PCM = "appendPcm"'));
    expect(channel, contains('const val CLOSE_ENCODER = "closeEncoder"'));
    expect(channel, contains('const val CANCEL_ENCODER = "cancelEncoder"'));
    expect(channel, contains('const val JOIN_AUDIO = "joinAudio"'));
    expect(channel, contains('const val ENCODE_FAILED = "encode-failed"'));
    expect(channel, contains('const val JOIN_FAILED = "join-failed"'));

    final String register = _block(
      channel,
      'fun register(messenger: BinaryMessenger)',
    );
    expect(
      register,
      contains('MethodChannel(messenger, CHANNEL).setMethodCallHandler'),
    );
    expect(register, contains('OPEN_ENCODER -> openEncoder(call, result)'));
    expect(register, contains('APPEND_PCM -> appendPcm(call, result)'));
    expect(register, contains('CLOSE_ENCODER -> closeEncoder(call, result)'));
    expect(register, contains('CANCEL_ENCODER -> cancelEncoder(call, result)'));
    expect(register, contains('JOIN_AUDIO -> joinAudio(call, result)'));
    expect(register, contains('else -> result.notImplemented()'));

    expect(
      channel,
      contains('private val main = Handler(Looper.getMainLooper())'),
    );

    final String openEncoder = _block(channel, 'private fun openEncoder(');
    expect(openEncoder, contains('text(call, "path")'));
    expect(openEncoder, contains('number(call, "sampleRate")'));
    expect(openEncoder, contains('number(call, "channels")'));
    expect(openEncoder, contains('number(call, "bitRate")'));
    expect(
      openEncoder,
      contains('Encoder(path, sampleRate, channels, bitRate)'),
    );
    expect(openEncoder, contains('encoder.executor.execute {'));
    expect(openEncoder, contains('encoder.open()'));
    expect(openEncoder, contains('result.success(id)'));
    expect(openEncoder, contains('main.post {'));
    expect(openEncoder, contains('result.error(ENCODE_FAILED,'));

    final String appendPcm = _block(channel, 'private fun appendPcm(');
    expect(appendPcm, contains('number(call, "id")'));
    expect(appendPcm, contains('arguments(call)["pcm"] as? ByteArray'));
    expect(appendPcm, contains('encoder.run(main, result) {'));
    expect(appendPcm, contains('encoder.append(pcm)'));

    final String closeEncoder = _block(channel, 'private fun closeEncoder(');
    expect(closeEncoder, contains('encoders.remove(id)'));
    expect(closeEncoder, contains('encoder.run(main, result) {'));
    expect(closeEncoder, contains('encoder.close()'));

    final String cancelEncoder = _block(channel, 'private fun cancelEncoder(');
    expect(cancelEncoder, contains('encoders.remove(id)'));
    expect(cancelEncoder, contains('encoder.run(main, result) {'));
    expect(cancelEncoder, contains('encoder.cancel()'));

    final String encoder = _block(channel, 'private class Encoder(');
    expect(
      encoder,
      contains(
        'val executor: ExecutorService = Executors.newSingleThreadExecutor()',
      ),
    );

    final String run = _block(encoder, 'fun run(');
    expect(run, contains('executor.execute {'));
    expect(run, contains('main.post { result.success(reply) }'));
    expect(run, contains('main.post { result.error(ENCODE_FAILED,'));

    final String open = _block(encoder, 'fun open()');
    expect(
      open,
      contains(
        'MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channels)',
      ),
    );
    expect(
      open,
      contains(
        'setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)',
      ),
    );
    expect(open, contains('setInteger(MediaFormat.KEY_BIT_RATE, bitRate)'));
    expect(
      open,
      contains(
        'MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)',
      ),
    );
    expect(
      open,
      contains(
        'aac.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)',
      ),
    );
    expect(
      open,
      contains('MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)'),
    );
    expect(open, contains('aac.start()'));

    final String append = _block(encoder, 'fun append(pcm: ByteArray)');
    expect(append, contains('aac.dequeueInputBuffer(TIMEOUT_US)'));
    expect(append, contains('input.put(pcm, offset, size)'));
    expect(
      append,
      contains(
        'aac.queueInputBuffer(inputIndex, 0, size, presentationTimeUs(), 0)',
      ),
    );
    expect(append, contains('framesQueued += size / frameBytes'));
    expect(append, contains('drain(aac, false)'));
    expect(
      encoder,
      contains(
        'private fun presentationTimeUs(): Long = framesQueued * MICROS_PER_SECOND / sampleRate',
      ),
    );

    final String drain = _block(encoder, 'private fun drain(');
    expect(drain, contains('aac.dequeueOutputBuffer(info,'));
    expect(drain, contains('MediaCodec.INFO_OUTPUT_FORMAT_CHANGED'));
    expect(drain, contains('track = writer.addTrack(aac.outputFormat)'));
    expect(drain, contains('writer.start()'));
    expect(drain, contains('muxer?.writeSampleData(track, output, info)'));
    expect(drain, contains('aac.releaseOutputBuffer(outputIndex, false)'));

    final String close = _block(encoder, 'fun close(): String');
    expect(close, contains('MediaCodec.BUFFER_FLAG_END_OF_STREAM'));
    expect(close, contains('drain(aac, true)'));
    expect(close, contains('muxer?.stop()'));
    expect(close, contains('release()'));
    expect(close, contains('return path'));

    final String cancel = _block(encoder, 'fun cancel()');
    expect(cancel, contains('release()'));
    expect(cancel, contains('File(path).delete()'));

    final String release = _block(encoder, 'private fun release()');
    expect(release, contains('started.release()'));
    expect(release, contains('writer.release()'));

    final String joinAudio = _block(channel, 'private fun joinAudio(');
    expect(joinAudio, contains('text(call, "video")'));
    expect(joinAudio, contains('text(call, "audio")'));
    expect(joinAudio, contains('text(call, "output")'));
    expect(
      joinAudio,
      contains('val executor = Executors.newSingleThreadExecutor()'),
    );
    expect(joinAudio, contains('executor.execute {'));
    expect(joinAudio, contains('Join(video, audio, output).write()'));
    expect(joinAudio, contains('File(output).delete()'));
    expect(joinAudio, contains('main.post { result.error(JOIN_FAILED,'));
    expect(joinAudio, contains('main.post { result.success(reply) }'));
    expect(joinAudio, contains('executor.shutdown()'));

    final String join = _block(channel, 'private class Join(');
    expect(join, contains('val picture = MediaExtractor()'));
    expect(join, contains('val sound = MediaExtractor()'));
    expect(join, contains('picture.setDataSource(video)'));
    expect(join, contains('sound.setDataSource(audio)'));
    expect(
      join,
      contains('val videoFormat = selectTrack(picture, VIDEO_MIME_PREFIX)'),
    );
    expect(
      join,
      contains('val audioFormat = selectTrack(sound, AUDIO_MIME_PREFIX)'),
    );
    expect(
      join,
      contains(
        'MediaMuxer(output, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)',
      ),
    );
    expect(join, contains('degrees?.let { writer.setOrientationHint(it) }'));
    expect(join, contains('writer.addTrack(videoFormat)'));
    expect(join, contains('writer.addTrack(audioFormat)'));
    expect(
      join.indexOf('setOrientationHint('),
      lessThan(join.indexOf('writer.start()')),
    );
    expect(join, contains('writer.stop()'));
    expect(join, contains('picture.release()'));
    expect(join, contains('sound.release()'));
    expect(join, isNot(contains('MediaCodec.create')));
    expect(join, isNot(contains('configure(')));
    expect(channel, contains('const val VIDEO_MIME_PREFIX = "video/"'));
    expect(channel, contains('const val AUDIO_MIME_PREFIX = "audio/"'));

    final String rotation = _block(join, 'private fun rotation(');
    expect(
      rotation,
      contains('val degrees = format.getInteger(MediaFormat.KEY_ROTATION)'),
    );
    expect(channel, contains('val MUXER_ROTATIONS = setOf(0, 90, 180, 270)'));

    final String copy = _block(channel, 'private class SampleCopy(');
    expect(copy, contains('extractor.readSampleData(buffer, 0)'));
    expect(
      copy,
      contains(
        'info.set(0, size, extractor.sampleTime, bufferFlags(extractor.sampleFlags))',
      ),
    );
    expect(copy, contains('muxer.writeSampleData(track, buffer, info)'));
    expect(copy, contains('extractor.advance()'));
    expect(copy, contains('MediaExtractor.SAMPLE_FLAG_SYNC'));
    expect(copy, contains('MediaCodec.BUFFER_FLAG_KEY_FRAME'));

    expect(channel, isNot(contains('createDecoderByType')));
    expect(channel, isNot(contains('PcmDecoder')));
  });
  test('a failed append reports the frames the encoder already took', () {
    final String channel = _read(_liveAudio);

    final String append = _block(channel, 'fun append(pcm: ByteArray)');
    expect(append, contains('val start = framesQueued'));
    expect(
      append,
      contains('throw AppendFailure(framesQueued - start, error)'),
    );
    expect(
      channel,
      contains('private class AppendFailure(val framesTaken: Long'),
    );

    final String run = _block(channel, 'fun run(main: Handler');
    expect(run, contains('(error as? AppendFailure)?.framesTaken'));
    expect(run, isNot(contains('ENCODE_FAILED_MESSAGE, null)')));
  });
}
