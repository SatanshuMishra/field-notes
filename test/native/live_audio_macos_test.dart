import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

String _block(String source, String signature) {
  final int start = source.indexOf(signature);
  expect(start, isNot(-1), reason: 'no $signature');
  final int open = source.indexOf('{', start);
  int depth = 0;
  for (int index = open; index < source.length; index += 1) {
    if (source[index] == '{') {
      depth += 1;
    } else if (source[index] == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(open, index + 1);
      }
    }
  }
  fail('$signature has no closing brace');
}

String _section(String project, String name) {
  final int start = project.indexOf('/* Begin $name section */');
  final int end = project.indexOf('/* End $name section */');
  expect(start, isNot(-1), reason: 'no $name section');
  expect(end, greaterThan(start));
  return project.substring(start, end);
}

Map<String, String> _runnerSwiftSources() {
  final List<File> files =
      Directory('macos/Runner')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.swift'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  return <String, String>{
    for (final File file in files) file.path: file.readAsStringSync(),
  };
}

void main() {
  test('the macOS runner registers live audio and drops audio clean', () {
    final Map<String, String> sources = _runnerSwiftSources();
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
    }
    expect(File('macos/Runner/AudioCleanBridge.swift').existsSync(), isFalse);

    final List<String> registering = sources.entries
        .where(
          (MapEntry<String, String> source) =>
              source.value.contains('"field_notes/live_audio"'),
        )
        .map((MapEntry<String, String> source) => source.key)
        .toList();
    expect(registering, <String>['macos/Runner/LiveAudioBridge.swift']);

    final String bridge = _read('macos/Runner/LiveAudioBridge.swift');
    final String window = _read('macos/Runner/MainFlutterWindow.swift');
    final String project = _read('macos/Runner.xcodeproj/project.pbxproj');

    expect(
      bridge,
      contains('private let liveAudioChannelName = "field_notes/live_audio"'),
    );
    expect(bridge, contains('private let encodeFailedCode = "encode-failed"'));
    expect(bridge, contains('private let joinFailedCode = "join-failed"'));
    expect(bridge, contains('final class LiveAudioBridge {'));

    final String init = _block(
      bridge,
      'init(messenger: FlutterBinaryMessenger)',
    );
    expect(init, contains('FlutterMethodChannel('));
    expect(init, contains('name: liveAudioChannelName'));
    expect(init, contains('setMethodCallHandler'));

    final String handle = _block(
      bridge,
      'private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)',
    );
    expect(handle, contains('case "openEncoder":'));
    expect(handle, contains('case "appendPcm":'));
    expect(handle, contains('case "closeEncoder":'));
    expect(handle, contains('case "cancelEncoder":'));
    expect(handle, contains('case "joinAudio":'));
    expect(handle, contains('result(FlutterMethodNotImplemented)'));

    final String openEncoder = _block(
      bridge,
      'private func openEncoder(_ arguments: [String: Any], result: @escaping FlutterResult)',
    );
    expect(openEncoder, contains('arguments["path"] as? String'));
    expect(openEncoder, contains('arguments["sampleRate"] as? Int'));
    expect(openEncoder, contains('arguments["channels"] as? Int'));
    expect(openEncoder, contains('arguments["bitRate"] as? Int'));
    expect(openEncoder, contains('reply = id'));
    expect(openEncoder, contains('encoder.queue.async'));
    expect(openEncoder, contains('DispatchQueue.main.async {'));
    expect(openEncoder, contains('encodeFailedCode'));

    final String open = _block(bridge, 'func open() throws');
    expect(
      open,
      contains(
        'let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)',
      ),
    );
    expect(open, contains('AVFormatIDKey: kAudioFormatMPEG4AAC'));
    expect(open, contains('AVSampleRateKey: Double(self.sampleRate)'));
    expect(open, contains('AVNumberOfChannelsKey: self.channels'));
    expect(open, contains('AVEncoderBitRateKey: self.bitRate'));
    expect(open, contains('input.expectsMediaDataInRealTime = true'));
    expect(open, contains('writer.add(input)'));
    expect(open, contains('writer.startWriting()'));
    expect(open, contains('writer.startSession(atSourceTime: .zero)'));

    final String format = _block(
      bridge,
      'private func pcmFormat() throws -> CMAudioFormatDescription',
    );
    expect(format, contains('mFormatID: kAudioFormatLinearPCM'));
    expect(
      format,
      contains(
        'mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked',
      ),
    );
    expect(format, isNot(contains('kAudioFormatFlagIsBigEndian')));
    expect(format, isNot(contains('kAudioFormatFlagIsNonInterleaved')));
    expect(format, contains('mBitsPerChannel: pcmBitsPerSample'));
    expect(bridge, contains('private let pcmBitsPerSample: UInt32 = 16'));
    expect(format, contains('CMAudioFormatDescriptionCreate('));

    final String sample = _block(
      bridge,
      'private func sampleBuffer(_ bytes: Data, frames: Int) throws -> CMSampleBuffer',
    );
    expect(sample, contains('CMBlockBufferCreateWithMemoryBlock('));
    expect(
      sample,
      contains('CMAudioSampleBufferCreateReadyWithPacketDescriptions('),
    );
    expect(sample, contains('value: self.framesAppended'));
    expect(sample, contains('timescale: CMTimeScale(self.sampleRate)'));

    final String append = _block(bridge, 'func append(_ pcm: Data) throws');
    expect(append, contains('while !input.isReadyForMoreMediaData {'));
    expect(append, contains('guard input.append(sample) else {'));
    expect(append, contains('self.framesAppended += Int64(frames)'));

    final String appendPcm = _block(
      bridge,
      'private func appendPcm(_ arguments: [String: Any], result: @escaping FlutterResult)',
    );
    expect(appendPcm, contains('arguments["id"] as? Int'));
    expect(
      appendPcm,
      contains('arguments["pcm"] as? FlutterStandardTypedData'),
    );
    expect(appendPcm, contains('on: encoder.queue'));
    expect(appendPcm, contains('try encoder.append(bytes)'));

    final String close = _block(bridge, 'func close() throws -> String');
    expect(close, contains('input.markAsFinished()'));
    expect(close, contains('writer.finishWriting {'));
    expect(close, contains('return self.path'));

    final String cancel = _block(bridge, 'func cancel()');
    expect(cancel, contains('writer.cancelWriting()'));
    expect(
      cancel,
      contains('FileManager.default.removeItem(atPath: self.path)'),
    );

    final String closeEncoder = _block(
      bridge,
      'private func closeEncoder(_ arguments: [String: Any], result: @escaping FlutterResult)',
    );
    expect(closeEncoder, contains('try encoder.close()'));
    expect(closeEncoder, contains('on: encoder.queue'));
    final String cancelEncoder = _block(
      bridge,
      'private func cancelEncoder(_ arguments: [String: Any], result: @escaping FlutterResult)',
    );
    expect(cancelEncoder, contains('encoder.cancel()'));
    expect(cancelEncoder, contains('on: encoder.queue'));

    expect(
      bridge,
      contains(
        'self.queue = DispatchQueue(label: "field_notes.live_audio.encoder.\\(id)")',
      ),
    );

    final String run = _block(bridge, 'private static func run(');
    expect(run, contains('queue.async {'));
    expect(run, contains('DispatchQueue.main.async {'));
    expect(run, contains('LiveAudioBridge.flutterError(code, error)'));
    expect(
      _block(
        bridge,
        'private static func flutterError(_ code: String, _ error: Error) -> FlutterError',
      ),
      contains('FlutterError(code: code'),
    );

    final String joinAudio = _block(
      bridge,
      'private func joinAudio(_ arguments: [String: Any], result: @escaping FlutterResult)',
    );
    expect(joinAudio, contains('arguments["video"] as? String'));
    expect(joinAudio, contains('arguments["audio"] as? String'));
    expect(joinAudio, contains('arguments["output"] as? String'));
    expect(
      joinAudio,
      contains('DispatchQueue(label: "field_notes.live_audio.join.'),
    );
    expect(joinAudio, contains('code: joinFailedCode'));

    final String copy = _block(
      bridge,
      'private static func copyTracks(video: String, audio: String, to outputURL: URL) throws',
    );
    expect(
      copy,
      contains(
        'let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)',
      ),
    );
    expect(copy, contains('pictureAsset.tracks(withMediaType: .video).first'));
    expect(copy, contains('soundAsset.tracks(withMediaType: .audio).first'));
    expect(
      copy,
      contains(
        'AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)',
      ),
    );
    expect(
      copy,
      contains(
        'AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)',
      ),
    );
    expect(
      RegExp(
        r'AVAssetWriterInput\(\s*mediaType: \.video,\s*outputSettings: nil,'
        r'\s*sourceFormatHint: LiveAudioBridge\.formatHint\(of: videoTrack\)\s*\)',
      ).hasMatch(copy),
      isTrue,
    );
    expect(
      RegExp(
        r'AVAssetWriterInput\(\s*mediaType: \.audio,\s*outputSettings: nil,'
        r'\s*sourceFormatHint: LiveAudioBridge\.formatHint\(of: audioTrack\)\s*\)',
      ).hasMatch(copy),
      isTrue,
    );
    expect(
      copy,
      contains('videoInput.transform = videoTrack.preferredTransform'),
    );
    expect(copy, isNot(contains('kAudioFormatMPEG4AAC')));
    expect(copy, contains('writer.finishWriting {'));

    final String pump = _block(bridge, 'private static func pump(');
    expect(pump, contains('trackOutput.copyNextSampleBuffer()'));
    expect(pump, contains('writerInput.append(sample)'));
    expect(pump, contains('writerInput.markAsFinished()'));

    final int peaks = window.indexOf(
      'self.registerAudioPeaksChannel(flutterViewController.engine.binaryMessenger)',
    );
    final int live = window.indexOf(
      'self.liveAudioBridge = LiveAudioBridge(messenger: flutterViewController.engine.binaryMessenger)',
    );
    expect(peaks, isNot(-1));
    expect(live, greaterThan(peaks));
    expect(window.substring(peaks, live).split('\n'), hasLength(2));
    expect(window, contains('private var liveAudioBridge: LiveAudioBridge?'));

    expect(project, isNot(contains('AudioCleanBridge')));
    final RegExpMatch? reference = RegExp(
      r'^\s*([0-9A-F]{24})[^\n]*= \{isa = PBXFileReference; '
      r'lastKnownFileType = sourcecode\.swift; path = LiveAudioBridge\.swift; '
      r'sourceTree = "<group>"; \};$',
      multiLine: true,
    ).firstMatch(_section(project, 'PBXFileReference'));
    expect(reference, isNotNull);
    final String fileId = reference!.group(1)!;
    final RegExpMatch? build = RegExp(
      '^\\s*([0-9A-F]{24})[^\\n]*= \\{isa = PBXBuildFile; '
      'fileRef = $fileId[^\\n]*\\};\$',
      multiLine: true,
    ).firstMatch(_section(project, 'PBXBuildFile'));
    expect(build, isNotNull);
    final String buildId = build!.group(1)!;
    expect(
      RegExp(r'[0-9A-F]{24}')
          .allMatches(project)
          .where((RegExpMatch match) => match.group(0) == fileId),
      hasLength(3),
    );
    final String runnerGroup = _block(
      project,
      '33FAB671232836740065AC1E /* Runner */ = {',
    );
    expect(runnerGroup, contains(fileId));
    final String runnerSources = _block(
      _section(project, 'PBXSourcesBuildPhase'),
      '33CC10E92044A3C60003C045 /* Sources */ = {',
    );
    expect(runnerSources, contains('MainFlutterWindow.swift in Sources'));
    expect(runnerSources, contains(buildId));
  });
}
