import AVFoundation
import FlutterMacOS

private let audioCleanChannelName = "field_notes/audio_clean"
private let cleanedSampleRate: Double = 48000
private let cleanedChannels = 1
private let wavHeaderBytes = 44

private enum AudioCleanFailure: Error, CustomStringConvertible {
  case unreadable(String)
  case unwritable(String)

  var description: String {
    switch self {
    case .unreadable(let reason):
      return reason
    case .unwritable(let reason):
      return reason
    }
  }
}

private final class AppendProgress {
  private let condition = NSCondition()
  private var remaining: Int
  private var failure: Error?

  init(inputs: Int) {
    self.remaining = inputs
  }

  func finish(_ error: Error?) {
    self.condition.lock()
    if self.failure == nil, let error = error {
      self.failure = error
    }
    self.remaining -= 1
    self.condition.broadcast()
    self.condition.unlock()
  }

  func wait(for writer: AVAssetWriter) -> Error? {
    self.condition.lock()
    defer { self.condition.unlock() }
    while self.remaining > 0 {
      if writer.status == .failed || writer.status == .cancelled {
        return self.failure ?? writer.error
          ?? AudioCleanFailure.unwritable("The writer stopped.")
      }
      _ = self.condition.wait(until: Date().addingTimeInterval(0.25))
    }
    return self.failure
  }
}

final class AudioCleanBridge {
  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: audioCleanChannelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "decodeAudio":
        guard let arguments = call.arguments as? [String: Any],
          let input = arguments["input"] as? String,
          let output = arguments["output"] as? String
        else {
          result(AudioCleanBridge.badArguments("An input and an output path are required"))
          return
        }
        AudioCleanBridge.work(output: output, result: result) {
          try AudioCleanBridge.decode(input: input, output: output)
        }
      case "replaceAudio":
        guard let arguments = call.arguments as? [String: Any],
          let input = arguments["input"] as? String,
          let audio = arguments["audio"] as? String,
          let output = arguments["output"] as? String,
          let bitRate = arguments["bitRate"] as? Int,
          bitRate > 0
        else {
          result(
            AudioCleanBridge.badArguments(
              "An input, an audio file, an output path and a bit rate are required"
            )
          )
          return
        }
        AudioCleanBridge.work(output: output, result: result) {
          try AudioCleanBridge.replace(
            input: input,
            audio: audio,
            output: output,
            bitRate: bitRate
          )
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func badArguments(_ message: String) -> FlutterError {
    return FlutterError(code: "bad_arguments", message: message, details: nil)
  }

  private static func work(
    output: String,
    result: @escaping FlutterResult,
    _ job: @escaping () throws -> Any
  ) {
    DispatchQueue.global(qos: .utility).async {
      let reply: Any
      do {
        reply = try job()
      } catch {
        try? FileManager.default.removeItem(atPath: output)
        reply = FlutterError(
          code: "clean-failed",
          message: "The take's sound could not be cleaned: \(error)",
          details: nil
        )
      }
      DispatchQueue.main.async {
        result(reply)
      }
    }
  }

  private static func decode(input: String, output: String) throws -> [String: Int] {
    let asset = AVURLAsset(url: URL(fileURLWithPath: input))
    guard let track = asset.tracks(withMediaType: .audio).first else {
      throw AudioCleanFailure.unreadable("The file has no sound track.")
    }
    guard let first = track.formatDescriptions.first,
      let stream = CMAudioFormatDescriptionGetStreamBasicDescription(
        first as! CMAudioFormatDescription
      )?.pointee
    else {
      throw AudioCleanFailure.unreadable("The sound track has no format.")
    }
    let sampleRate = Int(stream.mSampleRate.rounded())
    let channels = Int(stream.mChannelsPerFrame)
    guard sampleRate > 0, channels > 0 else {
      throw AudioCleanFailure.unreadable("The sound track has no samples.")
    }

    let reader = try AVAssetReader(asset: asset)
    let trackOutput = AVAssetReaderTrackOutput(
      track: track,
      outputSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsNonInterleaved: false,
        AVSampleRateKey: Double(sampleRate),
        AVNumberOfChannelsKey: channels,
      ]
    )
    trackOutput.alwaysCopiesSampleData = false
    guard reader.canAdd(trackOutput) else {
      throw AudioCleanFailure.unreadable("The sound track cannot be read as PCM.")
    }
    reader.add(trackOutput)
    guard reader.startReading() else {
      throw reader.error ?? AudioCleanFailure.unreadable("The sound track did not open.")
    }

    try? FileManager.default.removeItem(atPath: output)
    guard FileManager.default.createFile(atPath: output, contents: nil),
      let handle = FileHandle(forWritingAtPath: output)
    else {
      reader.cancelReading()
      throw AudioCleanFailure.unwritable("The decoded sound file could not be created.")
    }
    defer { try? handle.close() }
    try handle.write(
      contentsOf: AudioCleanBridge.wavHeader(
        sampleRate: sampleRate,
        channels: channels,
        dataBytes: 0
      )
    )
    var dataBytes = 0
    while let sample = trackOutput.copyNextSampleBuffer() {
      guard let block = CMSampleBufferGetDataBuffer(sample) else {
        continue
      }
      let length = CMBlockBufferGetDataLength(block)
      if length == 0 {
        continue
      }
      var bytes = Data(count: length)
      let status = bytes.withUnsafeMutableBytes { buffer -> OSStatus in
        guard let base = buffer.baseAddress else {
          return kCMBlockBufferBadPointerParameterErr
        }
        return CMBlockBufferCopyDataBytes(
          block,
          atOffset: 0,
          dataLength: length,
          destination: base
        )
      }
      guard status == kCMBlockBufferNoErr else {
        reader.cancelReading()
        throw AudioCleanFailure.unreadable("A block of sound could not be copied.")
      }
      try handle.write(contentsOf: bytes)
      dataBytes += length
    }
    guard reader.status == .completed else {
      throw reader.error ?? AudioCleanFailure.unreadable("The sound track did not finish.")
    }
    try handle.seek(toOffset: 0)
    try handle.write(
      contentsOf: AudioCleanBridge.wavHeader(
        sampleRate: sampleRate,
        channels: channels,
        dataBytes: dataBytes
      )
    )
    return [
      "sampleRate": sampleRate,
      "channels": channels,
      "frames": dataBytes / (channels * 2),
    ]
  }

  private static func replace(
    input: String,
    audio: String,
    output: String,
    bitRate: Int
  ) throws -> String {
    let outputURL = URL(fileURLWithPath: output)
    guard let fileType = AudioCleanBridge.fileType(for: outputURL) else {
      throw AudioCleanFailure.unwritable("The output has no supported file type.")
    }
    try? FileManager.default.removeItem(at: outputURL)
    let writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType)

    let source = AVURLAsset(url: URL(fileURLWithPath: input))
    var readers: [AVAssetReader] = []
    var pumps: [(AVAssetReaderTrackOutput, AVAssetWriterInput, String)] = []

    if let videoTrack = source.tracks(withMediaType: .video).first {
      let videoReader = try AVAssetReader(asset: source)
      let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
      videoOutput.alwaysCopiesSampleData = false
      guard videoReader.canAdd(videoOutput) else {
        throw AudioCleanFailure.unreadable("The video track cannot be read.")
      }
      videoReader.add(videoOutput)
      let hint = videoTrack.formatDescriptions.first.map { $0 as! CMFormatDescription }
      let videoInput = AVAssetWriterInput(
        mediaType: .video,
        outputSettings: nil,
        sourceFormatHint: hint
      )
      videoInput.transform = videoTrack.preferredTransform
      videoInput.expectsMediaDataInRealTime = false
      guard writer.canAdd(videoInput) else {
        throw AudioCleanFailure.unwritable("The video track cannot be written.")
      }
      writer.add(videoInput)
      readers.append(videoReader)
      pumps.append((videoOutput, videoInput, "field_notes.audio_clean.video"))
    }

    let cleaned = AVURLAsset(url: URL(fileURLWithPath: audio))
    guard let audioTrack = cleaned.tracks(withMediaType: .audio).first else {
      throw AudioCleanFailure.unreadable("The cleaned sound has no track.")
    }
    let audioReader = try AVAssetReader(asset: cleaned)
    let audioOutput = AVAssetReaderTrackOutput(
      track: audioTrack,
      outputSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsNonInterleaved: false,
      ]
    )
    audioOutput.alwaysCopiesSampleData = false
    guard audioReader.canAdd(audioOutput) else {
      throw AudioCleanFailure.unreadable("The cleaned sound cannot be read.")
    }
    audioReader.add(audioOutput)
    let audioInput = AVAssetWriterInput(
      mediaType: .audio,
      outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: cleanedSampleRate,
        AVNumberOfChannelsKey: cleanedChannels,
        AVEncoderBitRateKey: bitRate,
      ]
    )
    audioInput.expectsMediaDataInRealTime = false
    guard writer.canAdd(audioInput) else {
      throw AudioCleanFailure.unwritable("The sound track cannot be written.")
    }
    writer.add(audioInput)
    readers.append(audioReader)
    pumps.append((audioOutput, audioInput, "field_notes.audio_clean.audio"))

    guard writer.startWriting() else {
      throw writer.error ?? AudioCleanFailure.unwritable("The output did not open.")
    }
    writer.startSession(atSourceTime: .zero)
    for reader in readers {
      guard reader.startReading() else {
        writer.cancelWriting()
        readers.forEach { $0.cancelReading() }
        throw reader.error ?? AudioCleanFailure.unreadable("A track did not open.")
      }
    }

    let progress = AppendProgress(inputs: pumps.count)
    for (trackOutput, writerInput, label) in pumps {
      AudioCleanBridge.pump(trackOutput, into: writerInput, label: label, progress: progress)
    }
    if let failure = progress.wait(for: writer) {
      writer.cancelWriting()
      readers.forEach { $0.cancelReading() }
      throw failure
    }
    if let failed = readers.first(where: { $0.status == .failed }) {
      writer.cancelWriting()
      throw failed.error ?? AudioCleanFailure.unreadable("A track could not be read.")
    }

    let finished = DispatchSemaphore(value: 0)
    writer.finishWriting {
      finished.signal()
    }
    finished.wait()
    guard writer.status == .completed else {
      throw writer.error ?? AudioCleanFailure.unwritable("The output did not finish.")
    }
    return output
  }

  private static func pump(
    _ trackOutput: AVAssetReaderTrackOutput,
    into writerInput: AVAssetWriterInput,
    label: String,
    progress: AppendProgress
  ) {
    var done = false
    writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: label)) {
      while !done && writerInput.isReadyForMoreMediaData {
        guard let sample = trackOutput.copyNextSampleBuffer() else {
          done = true
          writerInput.markAsFinished()
          progress.finish(nil)
          return
        }
        if !writerInput.append(sample) {
          done = true
          writerInput.markAsFinished()
          progress.finish(AudioCleanFailure.unwritable("A sample could not be written."))
          return
        }
      }
    }
  }

  private static func fileType(for url: URL) -> AVFileType? {
    switch url.pathExtension.lowercased() {
    case "mp4":
      return .mp4
    case "m4a":
      return .m4a
    case "mov":
      return .mov
    default:
      return nil
    }
  }

  private static func wavHeader(sampleRate: Int, channels: Int, dataBytes: Int) -> Data {
    var header = Data(capacity: wavHeaderBytes)
    func append<T: FixedWidthInteger>(_ value: T) {
      withUnsafeBytes(of: value.littleEndian) { header.append(contentsOf: $0) }
    }
    header.append(contentsOf: Array("RIFF".utf8))
    append(UInt32(36 + dataBytes))
    header.append(contentsOf: Array("WAVE".utf8))
    header.append(contentsOf: Array("fmt ".utf8))
    append(UInt32(16))
    append(UInt16(1))
    append(UInt16(channels))
    append(UInt32(sampleRate))
    append(UInt32(sampleRate * channels * 2))
    append(UInt16(channels * 2))
    append(UInt16(16))
    header.append(contentsOf: Array("data".utf8))
    append(UInt32(dataBytes))
    return header
  }
}
