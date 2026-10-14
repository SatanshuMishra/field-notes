import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _kotlin =
    'android/app/src/main/kotlin/dev/satanshumishra/field_notes';
const String _audioClean = '$_kotlin/AudioCleanChannel.kt';
const String _pcmDecoder = '$_kotlin/PcmDecoder.kt';
const String _audioPeaks = '$_kotlin/AudioPeaksChannel.kt';
const String _mainActivity = '$_kotlin/MainActivity.kt';

String _source(String path) {
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

int _count(String source, String text) => text.allMatches(source).length;

void main() {
  test('the Android runner answers the audio clean channel', () {
    final String clean = _source(_audioClean);
    final String decoder = _source(_pcmDecoder);
    final String peaks = _source(_audioPeaks);
    final String activity = _source(_mainActivity);

    final String engine = _block(
      activity,
      'override fun configureFlutterEngine(',
    );
    expect(
      engine,
      contains(
        'AudioCleanChannel().register(flutterEngine.dartExecutor.binaryMessenger)',
      ),
      reason: 'MainActivity must register AudioCleanChannel',
    );
    expect(
      engine,
      contains(
        'AudioPeaksChannel().register(flutterEngine.dartExecutor.binaryMessenger)',
      ),
    );

    expect(clean, contains('const val CHANNEL = "field_notes/audio_clean"'));
    expect(clean, contains('const val DECODE_AUDIO = "decodeAudio"'));
    expect(clean, contains('const val REPLACE_AUDIO = "replaceAudio"'));
    expect(clean, contains('const val BAD_ARGUMENTS = "bad_arguments"'));
    expect(clean, contains('const val CLEAN_FAILED = "clean-failed"'));

    final String register = _block(
      clean,
      'fun register(messenger: BinaryMessenger)',
    );
    expect(
      register,
      contains('MethodChannel(messenger, CHANNEL).setMethodCallHandler'),
    );
    expect(register, contains('DECODE_AUDIO ->'));
    expect(register, contains('REPLACE_AUDIO ->'));
    expect(
      register,
      contains('answer(result, output) { decodeAudio(input, output) }'),
    );
    expect(
      register,
      contains(
        'answer(result, output) { replaceAudio(input, audio, output, bitRate) }',
      ),
    );
    expect(
      RegExp(r'result\.error\(\s*BAD_ARGUMENTS,').allMatches(register).length,
      2,
      reason: 'each method must reply bad_arguments for bad arguments',
    );

    expect(
      clean,
      contains('private val worker = Executors.newSingleThreadExecutor()'),
    );
    expect(
      clean,
      contains('private val main = Handler(Looper.getMainLooper())'),
    );
    final String answer = _block(clean, 'private fun answer(');
    expect(answer, contains('worker.execute {'));
    expect(answer, contains('main.post { result.success(reply) }'));
    expect(
      answer,
      matches(
        RegExp(
          r'catch \(error: Exception\) \{\s*failed\(result, output, error\)',
        ),
      ),
    );
    final String failed = _block(clean, 'private fun failed(');
    expect(failed, contains('File(output).delete()'));
    expect(failed, contains('main.post { result.error(CLEAN_FAILED,'));

    final String decodeAudio = _block(clean, 'private fun decodeAudio(');
    expect(decodeAudio, contains('PcmDecoder(input).decode(wav::add)'));
    final String wavWriter = _block(clean, 'private class WavWriter(');
    expect(wavWriter, contains('ByteOrder.LITTLE_ENDIAN'));
    expect(
      wavWriter,
      contains(
        'mapOf("sampleRate" to sampleRate, "channels" to channels, "frames" to samples / channels)',
      ),
    );
    expect(clean, contains('const val BITS_PER_SAMPLE = 16'));

    final String replaceAudio = _block(clean, 'private fun replaceAudio(');
    expect(
      replaceAudio,
      contains(
        'MediaMuxer(output, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)',
      ),
    );
    expect(
      replaceAudio,
      contains(
        'MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)',
      ),
    );
    expect(
      replaceAudio,
      contains(
        'aac.configure(aacFormat(bitRate), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)',
      ),
    );
    expect(replaceAudio, contains('return output'));
    expect(_count(clean, 'createEncoderByType('), 1);
    final String aacFormat = _block(clean, 'private fun aacFormat(');
    expect(
      aacFormat,
      contains(
        'MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, AAC_SAMPLE_RATE, AAC_CHANNELS)',
      ),
    );
    expect(
      aacFormat,
      contains(
        'setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)',
      ),
    );
    expect(
      aacFormat,
      contains('setInteger(MediaFormat.KEY_BIT_RATE, bitRate)'),
    );
    expect(clean, contains('const val AAC_SAMPLE_RATE = 48000'));
    expect(clean, contains('const val AAC_CHANNELS = 1'));

    final String rotation = _block(
      clean,
      'private fun rotation(format: MediaFormat): Int?',
    );
    expect(
      rotation,
      matches(
        RegExp(
          r'if \(!format\.containsKey\(MediaFormat\.KEY_ROTATION\)\) \{\s*return null\s*\}',
        ),
      ),
    );
    expect(
      rotation,
      contains('val degrees = format.getInteger(MediaFormat.KEY_ROTATION)'),
    );
    expect(
      rotation,
      matches(RegExp(r'if \(degrees !in MUXER_ROTATIONS\) \{\s*throw ')),
    );
    expect(rotation, contains('return degrees'));
    expect(clean, contains('val MUXER_ROTATIONS = setOf(0, 90, 180, 270)'));

    final String videoTrack = _block(
      clean,
      'private fun videoTrack(extractor: MediaExtractor): MediaFormat?',
    );
    expect(videoTrack, contains('startsWith(VIDEO_MIME_PREFIX)'));
    expect(videoTrack, contains('?: return null'));
    expect(videoTrack, contains('extractor.selectTrack(track)'));
    expect(clean, contains('const val VIDEO_MIME_PREFIX = "video/"'));
    expect(replaceAudio, contains('val video = videoTrack(extractor)'));
    expect(
      replaceAudio,
      contains('val degrees = video?.let { format -> rotation(format) }'),
    );
    expect(
      replaceAudio.indexOf('rotation(format)'),
      lessThan(replaceAudio.indexOf('MediaMuxer(output')),
      reason: 'an unusual rotation must fail before the output is written',
    );
    final String videoCopy = _block(
      replaceAudio,
      'val copy = video?.let { format ->',
    );
    expect(
      videoCopy,
      contains('degrees?.let { writer.setOrientationHint(it) }'),
    );
    expect(videoCopy, contains('writer.addTrack(format)'));
    expect(
      _count(clean, 'addTrack('),
      2,
      reason: 'only the video track, when there is one, and the audio track',
    );
    expect(_count(clean, 'setOrientationHint('), 1);
    expect(_count(clean, '.start()'), 2);
    expect(replaceAudio, contains('aac.start()'));
    expect(
      replaceAudio.indexOf('setOrientationHint('),
      lessThan(
        replaceAudio.indexOf('encode(aac, wav.channel, pcm, writer, copy)'),
      ),
    );
    final String encode = _block(clean, 'private fun encode(');
    expect(
      encode,
      contains('audioTrack = muxer.addTrack(encoder.outputFormat)'),
    );
    expect(encode, contains('muxer.start()'));
    expect(encode, contains('muxer.writeSampleData(audioTrack, output, info)'));
    final String copy = _block(clean, 'private class VideoCopy(');
    expect(copy, contains('extractor.readSampleData(buffer, 0)'));
    expect(copy, contains('muxer.writeSampleData(track, buffer, info)'));

    expect(decoder, contains('class PcmDecoder(private val path: String)'));
    final String decode = _block(
      decoder,
      'fun decode(receiver: (ByteBuffer, MediaFormat) -> Unit)',
    );
    expect(decode, contains('MediaExtractor()'));
    expect(decode, contains('MediaCodec.createDecoderByType(mime)'));
    final String drain = _block(decoder, 'private fun drain(');
    expect(drain, contains('codec.dequeueInputBuffer(TIMEOUT_US)'));
    expect(drain, contains('extractor.readSampleData(input, 0)'));
    expect(drain, contains('codec.dequeueOutputBuffer(info, TIMEOUT_US)'));
    expect(drain, contains('outputFormat = codec.outputFormat'));
    expect(
      drain,
      contains(
        'receiver(output.slice().order(ByteOrder.nativeOrder()), outputFormat)',
      ),
    );

    expect(
      _block(peaks, 'private fun windowRms('),
      contains('PcmDecoder(path).decode(windows::add)'),
    );
    for (final String loop in <String>[
      'dequeueInputBuffer',
      'dequeueOutputBuffer',
      'createDecoderByType',
      'MediaExtractor',
      'MediaCodec',
    ]) {
      expect(
        peaks,
        isNot(contains(loop)),
        reason: 'AudioPeaksChannel must decode through PcmDecoder',
      );
    }
    expect(_count(clean, 'PcmDecoder('), 1);
    expect(
      clean,
      isNot(contains('createDecoderByType')),
      reason: 'AudioCleanChannel must decode through PcmDecoder',
    );
  });
}
