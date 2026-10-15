import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _runner = 'windows/runner';

String _source(String name) {
  final File file = File('$_runner/$name');
  expect(file.existsSync(), isTrue, reason: '$_runner/$name is missing');
  return file.readAsStringSync();
}

String _block(String source, String signature) {
  final int start = source.indexOf(signature);
  expect(start, isNot(-1), reason: '$signature must exist');
  final int open = source.indexOf('{', start + signature.length - 1);
  expect(open, isNot(-1), reason: '$signature must open a block');
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
  fail('$signature never closes');
}

String _flat(String source) => source.replaceAll(RegExp(r'\s+'), ' ');

int _count(String source, String text) => text.allMatches(source).length;

void main() {
  test('the Windows runner answers the audio clean channel', () {
    final String bridge = _source('audio_clean_bridge.cpp');
    final String header = _source('audio_clean_bridge.h');
    final String reader = _source('audio_pcm_reader.cpp');
    final String readerHeader = _source('audio_pcm_reader.h');
    final String peaks = _source('audio_peaks_bridge.cpp');
    final String window = _source('flutter_window.cpp');
    final String windowHeader = _source('flutter_window.h');
    final String cmake = _source('CMakeLists.txt');
    final String flat = _flat(bridge);

    final int executable = cmake.indexOf('add_executable(');
    expect(executable, isNot(-1));
    final String sources = cmake.substring(
      executable,
      cmake.indexOf(')', executable),
    );
    expect(sources, contains('"audio_clean_bridge.cpp"'));
    expect(sources, contains('"audio_pcm_reader.cpp"'));
    expect(sources, contains('"audio_peaks_bridge.cpp"'));

    expect(
      bridge,
      contains('kAudioCleanChannelName[] = "field_notes/audio_clean"'),
    );
    expect(bridge, contains('kDecodeAudioMethod[] = "decodeAudio"'));
    expect(bridge, contains('kReplaceAudioMethod[] = "replaceAudio"'));
    expect(bridge, contains('kInputArgument[] = "input"'));
    expect(bridge, contains('kAudioArgument[] = "audio"'));
    expect(bridge, contains('kOutputArgument[] = "output"'));
    expect(bridge, contains('kBitRateArgument[] = "bitRate"'));
    expect(
      header,
      contains(
        'AudioCleanBridge(flutter::BinaryMessenger* messenger, HWND window);',
      ),
    );
    expect(header, contains('bool IsCleanedMessage(UINT message) const;'));
    expect(header, contains('void CompleteClean(LPARAM job);'));
    expect(windowHeader, contains('#include "audio_clean_bridge.h"'));
    expect(
      windowHeader,
      contains('std::unique_ptr<AudioCleanBridge> audio_clean_bridge_;'),
    );
    expect(
      _flat(window),
      contains(
        'audio_clean_bridge_ = std::make_unique<AudioCleanBridge>(messenger, GetHandle());',
      ),
    );
    expect(window, contains('audio_clean_bridge_ = nullptr;'));
    expect(
      _flat(_block(window, 'FlutterWindow::MessageHandler(')),
      contains(
        'if (audio_clean_bridge_ && audio_clean_bridge_->IsCleanedMessage(message)) '
        '{ audio_clean_bridge_->CompleteClean(lparam); return 0; }',
      ),
    );

    final String handle = _flat(
      _block(bridge, 'void AudioCleanBridge::Handle('),
    );
    expect(handle, contains('if (call.method_name() == kDecodeAudioMethod) {'));
    expect(
      handle,
      contains('if (call.method_name() == kReplaceAudioMethod) {'),
    );
    expect(
      handle,
      contains('result->Error(kBadArgumentsCode, kDecodeBadArgumentsMessage);'),
    );
    expect(
      handle,
      contains(
        'result->Error(kBadArgumentsCode, kReplaceBadArgumentsMessage);',
      ),
    );
    expect(handle, contains('!bit_rate.has_value() || *bit_rate <= 0'));
    expect(handle, contains('result->NotImplemented();'));
    expect(bridge, contains('kBadArgumentsCode[] = "bad_arguments"'));

    expect(
      readerHeader,
      contains('enum class PcmEncoding { kFloat32, kInt16 };'),
    );
    expect(
      _flat(readerHeader),
      contains(
        'using PcmCallback = std::function<bool(const PcmFormat& format, '
        'const BYTE* data, DWORD length)>;',
      ),
    );
    final String readPcm = _flat(_block(reader, 'bool ReadPcm('));
    expect(
      readPcm,
      contains(
        'FAILED(::MFCreateSourceReaderFromURL(path.c_str(), nullptr, &reader))',
      ),
    );
    expect(
      readPcm,
      contains(
        'FAILED(requested->SetGUID(MF_MT_SUBTYPE, SubtypeFor(encoding)))',
      ),
    );
    expect(
      readPcm,
      contains(
        'reader->ReadSample(kAudioStream, 0, nullptr, &flags, nullptr, &sample)',
      ),
    );
    expect(
      readPcm,
      contains('(flags & MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED) != 0'),
    );
    expect(readPcm, contains('!HandBuffer(sample.Get(), *format, callback)'));
    expect(
      _flat(_block(reader, 'bool HandBuffer(')),
      contains('const bool handled = callback(format, data, length);'),
    );
    expect(
      _flat(_block(reader, 'GUID SubtypeFor(PcmEncoding encoding)')),
      contains(
        'return encoding == PcmEncoding::kFloat32 ? MFAudioFormat_Float : MFAudioFormat_PCM;',
      ),
    );
    expect(_count(reader, 'ReadSample('), 1);

    expect(peaks, contains('#include "audio_pcm_reader.h"'));
    expect(
      _flat(_block(peaks, 'std::optional<std::vector<double>> WindowRms(')),
      contains('ReadPcm( path, PcmEncoding::kFloat32,'),
    );
    expect(peaks, isNot(contains('MFCreateSourceReaderFromURL')));
    expect(peaks, isNot(contains('ReadSample')));
    expect(peaks, isNot(contains('SetCurrentMediaType')));
    expect(peaks, isNot(contains('ConvertToContiguousBuffer')));

    expect(bridge, contains('#include "audio_pcm_reader.h"'));
    final String decode = _flat(
      _block(bridge, 'std::optional<flutter::EncodableValue> DecodeAudio('),
    );
    expect(decode, contains('WavWriter wav(output);'));
    expect(decode, contains('ReadPcm( input, PcmEncoding::kInt16,'));
    expect(decode, contains('return wav.Add(format, data, length);'));
    expect(decode, contains('return wav.Finish();'));
    expect(bridge, isNot(contains('ConvertToContiguousBuffer')));
    expect(_count(bridge, 'ReadSample('), 1);
    expect(
      flat,
      contains('reader_->ReadSample(kVideoStream, 0, nullptr, &flags,'),
    );
    final String wavHeader = _flat(_block(bridge, 'std::string WavHeader('));
    expect(wavHeader, contains('header.append("RIFF");'));
    expect(wavHeader, contains('header.append("WAVEfmt ");'));
    expect(wavHeader, contains('PutLittleEndian(header, kWavPcmFormat, 2);'));
    expect(wavHeader, contains('PutLittleEndian(header, kPcmBits, 2);'));
    expect(wavHeader, contains('header.append("data");'));
    expect(bridge, contains('constexpr UINT32 kPcmBits = 16;'));
    expect(bridge, contains('constexpr uint32_t kWavPcmFormat = 1;'));
    final String finish = _flat(
      _block(bridge, 'std::optional<flutter::EncodableValue> Finish()'),
    );
    expect(finish, contains('flutter::EncodableValue(kSampleRateKey)'));
    expect(finish, contains('flutter::EncodableValue(kChannelsKey)'));
    expect(finish, contains('flutter::EncodableValue(kFramesKey)'));
    expect(bridge, contains('kSampleRateKey[] = "sampleRate"'));
    expect(bridge, contains('kChannelsKey[] = "channels"'));
    expect(bridge, contains('kFramesKey[] = "frames"'));

    final String replace = _block(
      bridge,
      'std::optional<flutter::EncodableValue> ReplaceAudio(',
    );
    final String flatReplace = _flat(replace);
    expect(
      flatReplace,
      contains(
        'FAILED(::MFCreateSinkWriterFromURL(job.output.c_str(), nullptr, nullptr, &writer))',
      ),
    );
    expect(
      flatReplace,
      contains(
        'const HRESULT video_found = source->GetNativeMediaType(kVideoStream, 0, &native_video);',
      ),
    );
    expect(
      flatReplace,
      contains(
        'if (FAILED(video_found) && video_found != MF_E_INVALIDSTREAMNUMBER) '
        '{ return std::nullopt; }',
      ),
    );
    final String withVideo = _block(replace, 'if (SUCCEEDED(video_found)) {');
    final String flatVideo = _flat(withVideo);
    expect(
      flatVideo,
      contains(
        'const ComPtr<IMFMediaType> written = WrittenVideoType(native_video.Get());',
      ),
    );
    expect(
      flatVideo,
      contains('FAILED(source->SetStreamSelection(kVideoStream, TRUE))'),
    );
    expect(
      flatVideo,
      contains('FAILED(writer->AddStream(written.Get(), &video_index))'),
    );
    expect(
      flatVideo,
      contains('video.emplace(source.Get(), writer.Get(), video_index);'),
    );
    expect(withVideo, isNot(contains('SetInputMediaType')));
    final int afterVideo = replace.indexOf(withVideo) + withVideo.length;
    expect(
      replace.indexOf('writer->AddStream(aac.Get(), &audio_index)'),
      greaterThan(afterVideo),
    );
    expect(_count(bridge, 'SetInputMediaType('), 1);
    expect(
      flatReplace,
      contains(
        'FAILED(writer->SetInputMediaType(audio_index, pcm.Get(), nullptr))',
      ),
    );
    expect(flatReplace, contains('FAILED(writer->BeginWriting())'));
    expect(flatReplace, contains('ReadPcm( job.audio, PcmEncoding::kInt16,'));
    expect(flatReplace, contains('(video.has_value() && !video->WriteRest())'));
    expect(flatReplace, contains('FAILED(writer->Finalize())'));
    expect(
      flatReplace,
      contains('return flutter::EncodableValue(job.output_utf8);'),
    );

    final String rotation = _flat(
      _block(bridge, 'ComPtr<IMFMediaType> WrittenVideoType('),
    );
    expect(rotation, contains('FAILED(native->CopyAllItems(written.Get()))'));
    expect(
      rotation,
      contains(
        'if (SUCCEEDED(native->GetUINT32(MF_MT_VIDEO_ROTATION, &rotation)) && '
        'FAILED(written->SetUINT32(MF_MT_VIDEO_ROTATION, rotation))) '
        '{ return nullptr; }',
      ),
    );

    final String encoder = _flat(
      _block(bridge, 'ComPtr<IMFMediaType> NearestAacType('),
    );
    expect(
      encoder,
      contains(
        'MFT_REGISTER_TYPE_INFO output_info = {MFMediaType_Audio, MFAudioFormat_AAC};',
      ),
    );
    expect(
      encoder,
      contains(
        '::MFTEnumEx(MFT_CATEGORY_AUDIO_ENCODER, flags, nullptr, &output_info, '
        '&activates, &count)',
      ),
    );
    expect(
      encoder,
      contains('activates[0]->ActivateObject(IID_PPV_ARGS(&encoder))'),
    );
    expect(
      encoder,
      contains(
        'nearest = NearestOfferedType(encoder.Get(), bytes_per_second);',
      ),
    );
    expect(encoder, contains('::CoTaskMemFree(activates);'));
    final String offered = _flat(
      _block(bridge, 'ComPtr<IMFMediaType> NearestOfferedType('),
    );
    expect(
      offered,
      contains(
        'if (FAILED(encoder->GetOutputAvailableType(0, index, &offered))) '
        '{ break; }',
      ),
    );
    expect(
      offered,
      contains(
        'FAILED(offered->GetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND, &average))',
      ),
    );
    expect(
      offered,
      contains(
        'sample_rate != kCleanedSampleRate || channels != kCleanedChannels) '
        '{ continue; }',
      ),
    );
    expect(
      offered,
      contains(
        'const uint64_t distance = average > bytes_per_second '
        '? average - bytes_per_second : bytes_per_second - average;',
      ),
    );
    expect(
      offered,
      contains(
        'if (distance < nearest_distance) { nearest = offered; '
        'nearest_distance = distance; }',
      ),
    );
    expect(offered, contains('if (nearest.Get() == nullptr ||'));
    expect(bridge, contains('constexpr UINT32 kCleanedSampleRate = 48000;'));
    expect(bridge, contains('constexpr UINT32 kCleanedChannels = 1;'));
    expect(bridge, contains('constexpr UINT32 kBitsPerByte = 8;'));
    expect(
      flatReplace,
      contains(
        'NearestAacType(static_cast<UINT32>(job.bit_rate) / kBitsPerByte);',
      ),
    );
    expect(
      flatReplace,
      contains('if (aac.Get() == nullptr || pcm.Get() == nullptr ||'),
    );

    final String offThread = _flat(
      _block(bridge, 'DWORD WINAPI CleanOffThread('),
    );
    expect(
      offThread,
      contains('SUCCEEDED(::CoInitializeEx(nullptr, COINIT_MULTITHREADED))'),
    );
    expect(
      offThread,
      contains('SUCCEEDED(::MFStartup(MF_VERSION, MFSTARTUP_LITE))'),
    );
    expect(
      offThread,
      contains(
        'if (!job->reply.has_value()) { ::DeleteFileW(job->output.c_str()); }',
      ),
    );
    expect(offThread, contains('::PostMessage(job->window, job->message, 0,'));
    expect(
      flat,
      contains('::CreateThread(nullptr, 0, CleanOffThread, job, 0, nullptr)'),
    );
    expect(bridge, contains('kCleanFailedCode[] = "clean-failed"'));
    final String complete = _flat(
      _block(bridge, 'void AudioCleanBridge::CompleteClean('),
    );
    expect(
      complete,
      contains(
        'finished->result->Error(kCleanFailedCode, kCleanFailedMessage);',
      ),
    );
    expect(complete, contains('finished->result->Success(*finished->reply);'));
  });
}
