import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _runner = 'windows/runner';

String _source(String name) {
  final File file = File('$_runner/$name');
  expect(file.existsSync(), isTrue, reason: '$_runner/$name is missing');
  return file.readAsStringSync();
}

String _function(String source, String signature) {
  final int start = source.indexOf(signature);
  expect(start, isNot(-1), reason: '$signature must exist');
  final int end = source.indexOf('\n}\n', start);
  expect(end, isNot(-1), reason: '$signature must end');
  return source.substring(start, end);
}

String _flat(String source) => source.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  test('the Windows runner joins segments without re-encoding', () {
    final String bridge = _source('video_join_bridge.cpp');
    final String header = _source('video_join_bridge.h');
    final String window = _source('flutter_window.cpp');
    final String windowHeader = _source('flutter_window.h');
    final String cmake = _source('CMakeLists.txt');
    final String flat = _flat(bridge);

    expect(cmake, contains('"video_join_bridge.cpp"'));

    expect(
      bridge,
      contains('kVideoJoinChannelName[] = "field_notes/video_join"'),
    );
    expect(bridge, contains('kJoinMethod[] = "join"'));
    expect(bridge, contains('kSegmentsArgument[] = "segments"'));
    expect(bridge, contains('kOutputArgument[] = "output"'));
    expect(
      header,
      contains(
        'VideoJoinBridge(flutter::BinaryMessenger* messenger, HWND window);',
      ),
    );
    expect(header, contains('bool IsJoinedMessage(UINT message) const;'));
    expect(header, contains('void CompleteJoin(LPARAM job);'));
    expect(windowHeader, contains('#include "video_join_bridge.h"'));
    expect(
      windowHeader,
      contains('std::unique_ptr<VideoJoinBridge> video_join_bridge_;'),
    );
    expect(
      _flat(window),
      contains(
        'video_join_bridge_ = std::make_unique<VideoJoinBridge>(messenger, GetHandle());',
      ),
    );
    expect(window, contains('video_join_bridge_ = nullptr;'));
    final String handler = _function(window, 'FlutterWindow::MessageHandler(');
    expect(
      _flat(handler),
      contains(
        'if (video_join_bridge_ && video_join_bridge_->IsJoinedMessage(message)) '
        '{ video_join_bridge_->CompleteJoin(lparam); return 0; }',
      ),
    );

    final String readable = _flat(
      _function(bridge, 'std::vector<Segment> ReadableSegments('),
    );
    expect(
      readable,
      contains(
        'FAILED(::MFCreateSourceReaderFromURL(path.c_str(), nullptr, &reader))) '
        '{ continue; }',
      ),
    );
    expect(
      readable,
      contains('if (!duration.has_value() || *duration <= 0) { continue; }'),
    );
    final String duration = _flat(
      _function(bridge, 'std::optional<LONGLONG> SegmentDuration('),
    );
    expect(
      duration,
      contains(
        'GetPresentationAttribute(kMediaSource, MF_PD_DURATION, &value)',
      ),
    );

    expect(flat, contains('::MFCreateSinkWriterFromURL(output.c_str()'));
    expect(
      flat,
      contains(
        'first->GetNativeMediaType(stream.source_index, 0, &native)) || '
        'FAILED(writer->AddStream(native.Get(), &stream.writer_index))',
      ),
    );
    expect(bridge, isNot(contains('SetInputMediaType')));
    expect(bridge, isNot(contains('MFVideoFormat_H264')));
    expect(bridge, isNot(contains('MFAudioFormat_AAC')));
    expect(
      flat,
      contains(
        'return major_type == MFMediaType_Video || major_type == MFMediaType_Audio;',
      ),
    );
    expect(flat, contains('ReadSample(kAnyStream, 0, &stream_index, &flags,'));
    expect(flat, contains('FAILED(sample->SetSampleTime(time + offset))'));
    expect(
      flat,
      contains(
        'FAILED(writer->WriteSample(stream->writer_index, sample.Get()))',
      ),
    );
    expect(flat, contains('offset += segment.duration;'));
    expect(flat, contains('FAILED(writer->Finalize())'));

    expect(bridge, contains('kJoinFailedCode[] = "join-failed"'));
    expect(
      flat,
      contains(
        'if (segments.empty()) { return std::string(kNoSegmentMessage); }',
      ),
    );
    expect(
      flat,
      contains(
        'return std::string(missing ? kMissingStreamMessage : kJoinFailedMessage);',
      ),
    );
    final String complete = _flat(
      _function(bridge, 'void VideoJoinBridge::CompleteJoin('),
    );
    expect(
      complete,
      contains('finished->result->Error(kJoinFailedCode, *finished->failure);'),
    );
    expect(
      complete,
      contains(
        'finished->result->Success(flutter::EncodableValue(finished->output_utf8));',
      ),
    );
    expect(bridge, contains('kBadArgumentsCode[] = "bad_arguments"'));
    expect(
      flat,
      contains('::CreateThread(nullptr, 0, JoinOffThread, job, 0, nullptr)'),
    );
    expect(flat, contains('::PostMessage(job->window, job->message, 0,'));
  });
}
