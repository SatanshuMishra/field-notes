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

Map<String, String> _runnerSources() {
  final List<File> files =
      Directory(_runner)
          .listSync()
          .whereType<File>()
          .where(
            (File file) =>
                file.path.endsWith('.cpp') ||
                file.path.endsWith('.h') ||
                file.path.endsWith('CMakeLists.txt'),
          )
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  return <String, String>{
    for (final File file in files) file.path: file.readAsStringSync(),
  };
}

void main() {
  test('the Windows runner registers live audio and drops audio clean', () {
    final Map<String, String> sources = _runnerSources();
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
        isNot(contains('AudioCleanBridge')),
        reason: source.key,
      );
      expect(
        source.value,
        isNot(contains('audio_clean_bridge')),
        reason: source.key,
      );
    }
    expect(File('$_runner/audio_clean_bridge.cpp').existsSync(), isFalse);
    expect(File('$_runner/audio_clean_bridge.h').existsSync(), isFalse);

    final List<String> registering = sources.entries
        .where(
          (MapEntry<String, String> source) =>
              source.value.contains('"field_notes/live_audio"'),
        )
        .map((MapEntry<String, String> source) => source.key)
        .toList();
    expect(registering, <String>['$_runner/live_audio_bridge.cpp']);

    final String bridge = _source('live_audio_bridge.cpp');
    final String header = _source('live_audio_bridge.h');
    final String window = _source('flutter_window.cpp');
    final String windowHeader = _source('flutter_window.h');
    final String cmake = _source('CMakeLists.txt');

    final int executable = cmake.indexOf('add_executable(');
    expect(executable, isNot(-1));
    final String executableSources = cmake.substring(
      executable,
      cmake.indexOf(')', executable),
    );
    expect(executableSources, contains('"live_audio_bridge.cpp"'));
    expect(executableSources, contains('"audio_pcm_reader.cpp"'));
    expect(executableSources, contains('"audio_peaks_bridge.cpp"'));
    expect(executableSources, contains('"video_join_bridge.cpp"'));

    expect(header, contains('class LiveAudioBridge {'));
    expect(
      header,
      contains(
        'LiveAudioBridge(flutter::BinaryMessenger* messenger, HWND window);',
      ),
    );
    expect(header, contains('bool IsRepliedMessage(UINT message) const;'));
    expect(header, contains('void CompleteReply(LPARAM reply);'));
    expect(windowHeader, contains('#include "live_audio_bridge.h"'));
    expect(
      windowHeader,
      contains('std::unique_ptr<LiveAudioBridge> live_audio_bridge_;'),
    );
    expect(
      _flat(_block(window, 'bool FlutterWindow::OnCreate()')),
      contains(
        'live_audio_bridge_ = std::make_unique<LiveAudioBridge>(messenger, GetHandle());',
      ),
    );
    expect(
      _block(window, 'void FlutterWindow::OnDestroy()'),
      contains('live_audio_bridge_ = nullptr;'),
    );
    expect(
      _flat(_block(window, 'FlutterWindow::MessageHandler(')),
      contains(
        'if (live_audio_bridge_ && live_audio_bridge_->IsRepliedMessage(message)) '
        '{ live_audio_bridge_->CompleteReply(lparam); return 0; }',
      ),
    );

    expect(
      bridge,
      contains('kLiveAudioChannelName[] = "field_notes/live_audio"'),
    );
    expect(bridge, contains('kOpenEncoderMethod[] = "openEncoder"'));
    expect(bridge, contains('kAppendPcmMethod[] = "appendPcm"'));
    expect(bridge, contains('kCloseEncoderMethod[] = "closeEncoder"'));
    expect(bridge, contains('kCancelEncoderMethod[] = "cancelEncoder"'));
    expect(bridge, contains('kJoinAudioMethod[] = "joinAudio"'));
    expect(bridge, contains('kPathArgument[] = "path"'));
    expect(bridge, contains('kSampleRateArgument[] = "sampleRate"'));
    expect(bridge, contains('kChannelsArgument[] = "channels"'));
    expect(bridge, contains('kBitRateArgument[] = "bitRate"'));
    expect(bridge, contains('kIdArgument[] = "id"'));
    expect(bridge, contains('kPcmArgument[] = "pcm"'));
    expect(bridge, contains('kVideoArgument[] = "video"'));
    expect(bridge, contains('kAudioArgument[] = "audio"'));
    expect(bridge, contains('kOutputArgument[] = "output"'));
    expect(bridge, contains('kEncodeFailedCode[] = "encode-failed"'));
    expect(bridge, contains('kJoinFailedCode[] = "join-failed"'));
    expect(bridge, contains('IMFSinkWriter'));

    final String handle = _flat(
      _block(bridge, 'void LiveAudioBridge::Handle('),
    );
    expect(
      handle,
      contains(
        'if (method == kOpenEncoderMethod) '
        '{ OpenEncoder(arguments, std::move(result)); return; }',
      ),
    );
    expect(
      handle,
      contains(
        'if (method == kAppendPcmMethod) '
        '{ AppendPcm(arguments, std::move(result)); return; }',
      ),
    );
    expect(
      handle,
      contains(
        'if (method == kCloseEncoderMethod) '
        '{ CloseEncoder(arguments, std::move(result)); return; }',
      ),
    );
    expect(
      handle,
      contains(
        'if (method == kCancelEncoderMethod) '
        '{ CancelEncoder(arguments, std::move(result)); return; }',
      ),
    );
    expect(
      handle,
      contains(
        'if (method == kJoinAudioMethod) '
        '{ JoinAudio(arguments, std::move(result)); return; }',
      ),
    );
    expect(handle, contains('result->NotImplemented();'));

    final String aac = _flat(_block(bridge, 'ComPtr<IMFMediaType> AacType('));
    expect(
      aac,
      contains('FAILED(type->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_AAC))'),
    );
    expect(
      aac,
      contains(
        'FAILED(type->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, settings.sample_rate))',
      ),
    );
    expect(
      aac,
      contains(
        'FAILED(type->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, settings.channels))',
      ),
    );
    expect(
      aac,
      contains(
        'FAILED(type->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND, settings.bit_rate / kBitsPerByte))',
      ),
    );
    expect(bridge, contains('constexpr UINT32 kBitsPerByte = 8;'));
    final String pcm = _flat(_block(bridge, 'ComPtr<IMFMediaType> PcmType('));
    expect(
      pcm,
      contains('FAILED(type->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM))'),
    );
    expect(
      pcm,
      contains(
        'FAILED(type->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, kPcmBits))',
      ),
    );
    expect(bridge, contains('constexpr UINT32 kPcmBits = 16;'));

    final String open = _flat(_block(bridge, 'bool Open()'));
    expect(
      open,
      contains(
        'FAILED(::MFCreateSinkWriterFromURL(settings_.path.c_str(), nullptr, '
        'container.Get(), &writer))',
      ),
    );
    expect(open, contains('FAILED(writer->AddStream(aac.Get(), &stream))'));
    expect(
      open,
      contains('FAILED(writer->SetInputMediaType(stream, pcm.Get(), nullptr))'),
    );
    expect(open, contains('FAILED(writer->BeginWriting())'));

    final String append = _flat(
      _block(bridge, 'bool Append(const std::vector<uint8_t>& pcm)'),
    );
    expect(append, contains('FAILED(sample->SetSampleTime(time))'));
    expect(
      append,
      contains('FAILED(sample->SetSampleDuration(TimeAtFrame(end) - time))'),
    );
    expect(
      append,
      contains('FAILED(writer_->WriteSample(stream_, sample.Get()))'),
    );
    expect(append, contains('frames_ = end;'));
    expect(
      _flat(_block(bridge, 'LONGLONG TimeAtFrame(uint64_t frame) const')),
      contains(
        'return static_cast<LONGLONG>(frame * kTicksPerSecond / settings_.sample_rate);',
      ),
    );
    expect(bridge, contains('constexpr uint64_t kTicksPerSecond = 10000000;'));

    expect(
      _flat(_block(bridge, 'bool Close()')),
      contains(
        'if (writer_.Get() == nullptr || FAILED(writer_->Finalize())) '
        '{ Cancel(); return false; }',
      ),
    );
    final String cancel = _block(bridge, 'void Cancel()');
    expect(cancel, contains('Abandon();'));
    expect(cancel, contains('::DeleteFileW(settings_.path.c_str());'));

    final String openEncoder = _flat(
      _block(bridge, 'void LiveAudioBridge::OpenEncoder('),
    );
    expect(openEncoder, contains('const int id = next_encoder_id_++;'));
    expect(openEncoder, contains('encoders_.emplace(id, worker);'));
    expect(
      openEncoder,
      contains('if (!encoder.Open()) { return std::nullopt; }'),
    );
    expect(openEncoder, contains('return flutter::EncodableValue(id);'));
    expect(
      _flat(_block(bridge, 'void LiveAudioBridge::AppendPcm(')),
      contains('if (!encoder.Append(bytes)) { return std::nullopt; }'),
    );
    final String closeEncoder = _flat(
      _block(bridge, 'void LiveAudioBridge::CloseEncoder('),
    );
    expect(
      closeEncoder,
      contains('if (!encoder.Close()) { return std::nullopt; }'),
    );
    expect(
      closeEncoder,
      contains('return flutter::EncodableValue(encoder.path_utf8());'),
    );
    expect(closeEncoder, contains('worker->Finish();'));
    final String cancelEncoder = _flat(
      _block(bridge, 'void LiveAudioBridge::CancelEncoder('),
    );
    expect(cancelEncoder, contains('encoder.Cancel();'));
    expect(cancelEncoder, contains('worker->Finish();'));

    final String encodeThread = _flat(
      _block(bridge, 'DWORD WINAPI EncodeOffThread('),
    );
    expect(
      encodeThread,
      contains('SUCCEEDED(::CoInitializeEx(nullptr, COINIT_MULTITHREADED))'),
    );
    expect(
      encodeThread,
      contains('SUCCEEDED(::MFStartup(MF_VERSION, MFSTARTUP_LITE))'),
    );
    expect(encodeThread, contains('(*held)->Run(media);'));
    expect(
      _flat(bridge),
      contains('::CreateThread(nullptr, 0, EncodeOffThread, held, 0, nullptr)'),
    );
    final String run = _flat(_block(bridge, 'void Run(bool ready)'));
    expect(run, contains('value = task->work(encoder_);'));
    expect(run, contains('kEncodeFailedCode, kEncodeFailedMessage,'));
    expect(
      _flat(_block(bridge, 'void PostReply(')),
      contains(
        '::PostMessage(window, message, 0, reinterpret_cast<LPARAM>(reply))',
      ),
    );

    final String join = _flat(_block(bridge, 'bool JoinTracks('));
    expect(
      join,
      contains(
        'FAILED(::MFCreateSourceReaderFromURL(job.video.c_str(), nullptr, '
        '&picture_source))',
      ),
    );
    expect(
      join,
      contains(
        'FAILED(::MFCreateSourceReaderFromURL(job.audio.c_str(), nullptr, '
        '&sound_source))',
      ),
    );
    expect(
      join,
      contains('SelectNativeStream(picture_source.Get(), kFirstVideoStream);'),
    );
    expect(
      join,
      contains('SelectNativeStream(sound_source.Get(), kFirstAudioStream);'),
    );
    expect(join, contains('RotationKeptType(picture_type.Get());'));
    expect(
      join,
      contains(
        'FAILED(::MFCreateSinkWriterFromURL(job.output.c_str(), nullptr, '
        'container.Get(), &writer))',
      ),
    );
    expect(
      join,
      contains(
        'FAILED(writer->AddStream(written_picture.Get(), &picture_stream))',
      ),
    );
    expect(
      join,
      contains('FAILED(writer->AddStream(sound_type.Get(), &sound_stream))'),
    );
    expect(
      join,
      contains(
        '!CopyInterleaved(picture, sound) || FAILED(writer->Finalize())',
      ),
    );
    expect(join, isNot(contains('SetInputMediaType')));
    expect(_count(bridge, 'SetInputMediaType('), 1);
    expect(bridge, isNot(contains('MFTEnumEx')));

    final String native = _flat(
      _block(bridge, 'ComPtr<IMFMediaType> SelectNativeStream('),
    );
    expect(
      native,
      contains('FAILED(reader->GetNativeMediaType(stream, 0, &native))'),
    );
    expect(
      native,
      contains(
        'FAILED(reader->SetCurrentMediaType(stream, nullptr, native.Get()))',
      ),
    );
    final String rotation = _flat(
      _block(bridge, 'ComPtr<IMFMediaType> RotationKeptType('),
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
    expect(
      _flat(_block(bridge, 'bool CopyInterleaved(')),
      contains('picture.PendingTime() <= sound.PendingTime()'),
    );

    final String joinThread = _flat(
      _block(bridge, 'DWORD WINAPI JoinOffThread('),
    );
    expect(
      joinThread,
      contains('SUCCEEDED(::CoInitializeEx(nullptr, COINIT_MULTITHREADED))'),
    );
    expect(joinThread, contains('joined = JoinTracks(*job);'));
    expect(
      joinThread,
      contains('if (!joined) { ::DeleteFileW(job->output.c_str()); }'),
    );
    expect(joinThread, contains('kJoinFailedCode, kJoinFailedMessage,'));
    expect(
      _flat(_block(bridge, 'void LiveAudioBridge::JoinAudio(')),
      contains('::CreateThread(nullptr, 0, JoinOffThread, job, 0, nullptr)'),
    );

    final String complete = _flat(
      _block(bridge, 'void LiveAudioBridge::CompleteReply('),
    );
    expect(complete, contains('ForgetEncoder(*finished->failed_open);'));
    expect(
      complete,
      contains('finished->result->Error(finished->code, finished->message);'),
    );
    expect(complete, contains('finished->result->Success(*finished->value);'));
  });
}
