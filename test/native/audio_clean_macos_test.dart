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

void main() {
  test('the macOS runner answers the audio clean channel', () {
    final String bridge = _read('macos/Runner/AudioCleanBridge.swift');
    final String window = _read('macos/Runner/MainFlutterWindow.swift');
    final String project = _read('macos/Runner.xcodeproj/project.pbxproj');

    final RegExpMatch? reference = RegExp(
      r'^\s*([0-9A-F]{24})[^\n]*= \{isa = PBXFileReference; '
      r'lastKnownFileType = sourcecode\.swift; path = AudioCleanBridge\.swift; '
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
    final String sources = _section(project, 'PBXSourcesBuildPhase');
    final String runnerSources = _block(
      sources,
      '33CC10E92044A3C60003C045 /* Sources */ = {',
    );
    expect(runnerSources, contains('MainFlutterWindow.swift in Sources'));
    expect(runnerSources, contains(buildId));

    final int peaks = window.indexOf(
      'self.registerAudioPeaksChannel(flutterViewController.engine.binaryMessenger)',
    );
    final int clean = window.indexOf(
      'AudioCleanBridge.register(flutterViewController.engine.binaryMessenger)',
    );
    expect(peaks, isNot(-1));
    expect(clean, greaterThan(peaks));
    expect(window.substring(peaks, clean).split('\n'), hasLength(2));

    expect(
      bridge,
      contains('private let audioCleanChannelName = "field_notes/audio_clean"'),
    );
    expect(bridge, contains('final class AudioCleanBridge {'));
    final String register = _block(
      bridge,
      'static func register(_ messenger: FlutterBinaryMessenger)',
    );
    expect(register, contains('name: audioCleanChannelName'));
    expect(register, contains('case "decodeAudio":'));
    expect(register, contains('case "replaceAudio":'));
    expect(register, contains('AudioCleanBridge.badArguments('));
    expect(register, contains('result(FlutterMethodNotImplemented)'));
    expect(bridge, contains('code: "bad_arguments"'));

    final String work = _block(bridge, 'private static func work(');
    expect(work, contains('DispatchQueue.global(qos: .utility).async {'));
    expect(work, contains('DispatchQueue.main.async {'));
    expect(work, contains('code: "clean-failed"'));
    expect(
      work,
      contains('try? FileManager.default.removeItem(atPath: output)'),
    );

    final String decode = _block(
      bridge,
      'private static func decode(input: String, output: String)',
    );
    expect(decode, contains('AVURLAsset(url: URL(fileURLWithPath: input))'));
    expect(decode, contains('asset.tracks(withMediaType: .audio).first'));
    expect(decode, contains('AVAssetReaderTrackOutput('));
    expect(decode, contains('AVFormatIDKey: kAudioFormatLinearPCM'));
    expect(decode, contains('AVLinearPCMBitDepthKey: 16'));
    expect(decode, contains('AVLinearPCMIsBigEndianKey: false'));
    expect(decode, contains('AVLinearPCMIsFloatKey: false'));
    expect(decode, contains('AVLinearPCMIsNonInterleaved: false'));
    expect(decode, contains('AVSampleRateKey: Double(sampleRate)'));
    expect(decode, contains('AVNumberOfChannelsKey: channels'));
    expect(decode, contains('"sampleRate": sampleRate'));
    expect(decode, contains('"channels": channels'));
    expect(decode, contains('"frames": dataBytes / (channels * 2)'));

    final String replace = _block(bridge, 'private static func replace(');
    expect(
      replace,
      contains(
        'let writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType)',
      ),
    );
    final String video = _block(
      replace,
      'if let videoTrack = source.tracks(withMediaType: .video).first',
    );
    expect(
      video,
      contains(
        'AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)',
      ),
    );
    expect(
      RegExp(
        r'AVAssetWriterInput\(\s*mediaType: \.video,\s*outputSettings: nil,'
        r'\s*sourceFormatHint: hint\s*\)',
      ).hasMatch(video),
      isTrue,
    );
    expect(
      video,
      contains('videoInput.transform = videoTrack.preferredTransform'),
    );
    expect(video, contains('writer.add(videoInput)'));
    expect('writer.add(videoInput)'.allMatches(bridge), hasLength(1));
    expect(
      replace.indexOf('writer.add(audioInput)'),
      greaterThan(replace.indexOf(video) + video.length),
    );
    expect(replace, contains('AVFormatIDKey: kAudioFormatMPEG4AAC'));
    expect(replace, contains('AVSampleRateKey: cleanedSampleRate'));
    expect(replace, contains('AVNumberOfChannelsKey: cleanedChannels'));
    expect(replace, contains('AVEncoderBitRateKey: bitRate'));
    expect(bridge, contains('private let cleanedSampleRate: Double = 48000'));
    expect(bridge, contains('private let cleanedChannels = 1'));
    expect(replace, contains('writer.finishWriting {'));
    expect(replace, contains('return output'));

    final String types = _block(
      bridge,
      'private static func fileType(for url: URL) -> AVFileType?',
    );
    expect(types, contains('case "mp4":\n      return .mp4'));
    expect(types, contains('case "m4a":\n      return .m4a'));
    expect(types, contains('case "mov":\n      return .mov'));
  });
}
