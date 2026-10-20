import AVFoundation
import FlutterMacOS

private let liveAudioChannelName = "field_notes/live_audio"
private let encodeFailedCode = "encode-failed"
private let joinFailedCode = "join-failed"
private let pcmBytesPerSample = 2
private let pcmBitsPerSample: UInt32 = 16
private let inputReadinessPollSeconds = 0.002
private let joinStatusPollSeconds = 0.25

private enum LiveAudioFailure: Error, CustomStringConvertible {
  case badArguments(String)
  case unknownEncoder(Int)
  case unreadable(String)
  case unwritable(String)

  var description: String {
    switch self {
    case .badArguments(let reason):
      return reason
    case .unknownEncoder(let id):
      return "No live encoder has the id \(id)."
    case .unreadable(let reason):
      return reason
    case .unwritable(let reason):
      return reason
    }
  }
}

private final class LiveAudioEncoder {
  let queue: DispatchQueue
  private let path: String
  private let sampleRate: Int
  private let channels: Int
  private let bitRate: Int
  private let bytesPerFrame: Int
  private var writer: AVAssetWriter?
  private var input: AVAssetWriterInput?
  private var format: CMAudioFormatDescription?
  private var framesAppended: Int64 = 0
  private var pending = Data()

  init(id: Int, path: String, sampleRate: Int, channels: Int, bitRate: Int) {
    self.queue = DispatchQueue(label: "field_notes.live_audio.encoder.\(id)")
    self.path = path
    self.sampleRate = sampleRate
    self.channels = channels
    self.bitRate = bitRate
    self.bytesPerFrame = channels * pcmBytesPerSample
  }

  func open() throws {
    let url = URL(fileURLWithPath: self.path)
    try? FileManager.default.removeItem(at: url)
    let format = try self.pcmFormat()
    let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
    let input = AVAssetWriterInput(
      mediaType: .audio,
      outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: Double(self.sampleRate),
        AVNumberOfChannelsKey: self.channels,
        AVEncoderBitRateKey: self.bitRate,
      ],
      sourceFormatHint: format
    )
    input.expectsMediaDataInRealTime = true
    guard writer.canAdd(input) else {
      throw LiveAudioFailure.unwritable("The AAC track cannot be written.")
    }
    writer.add(input)
    guard writer.startWriting() else {
      throw writer.error ?? LiveAudioFailure.unwritable("The sound file did not open.")
    }
    writer.startSession(atSourceTime: .zero)
    self.format = format
    self.writer = writer
    self.input = input
  }

  func append(_ pcm: Data) throws {
    guard let writer = self.writer, let input = self.input else {
      throw LiveAudioFailure.unwritable("The encoder is not open.")
    }
    var joined = Data(capacity: self.pending.count + pcm.count)
    joined.append(self.pending)
    joined.append(pcm)
    let frames = joined.count / self.bytesPerFrame
    let wholeBytes = frames * self.bytesPerFrame
    self.pending = joined.subdata(in: wholeBytes..<joined.count)
    guard frames > 0 else {
      return
    }
    let sample = try self.sampleBuffer(joined.subdata(in: 0..<wholeBytes), frames: frames)
    while !input.isReadyForMoreMediaData {
      guard writer.status == .writing else {
        throw writer.error ?? LiveAudioFailure.unwritable("The writer stopped.")
      }
      Thread.sleep(forTimeInterval: inputReadinessPollSeconds)
    }
    guard input.append(sample) else {
      throw writer.error ?? LiveAudioFailure.unwritable("A chunk of sound could not be written.")
    }
    self.framesAppended += Int64(frames)
  }

  func close() throws -> String {
    guard let writer = self.writer, let input = self.input, writer.status == .writing else {
      throw self.writer?.error ?? LiveAudioFailure.unwritable("The encoder is not writing.")
    }
    input.markAsFinished()
    let finished = DispatchSemaphore(value: 0)
    writer.finishWriting {
      finished.signal()
    }
    finished.wait()
    guard writer.status == .completed else {
      throw writer.error ?? LiveAudioFailure.unwritable("The sound file did not finish.")
    }
    return self.path
  }

  func cancel() {
    if let writer = self.writer, writer.status == .writing {
      writer.cancelWriting()
    }
    try? FileManager.default.removeItem(atPath: self.path)
  }

  private func pcmFormat() throws -> CMAudioFormatDescription {
    var description = AudioStreamBasicDescription(
      mSampleRate: Double(self.sampleRate),
      mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
      mBytesPerPacket: UInt32(self.bytesPerFrame),
      mFramesPerPacket: 1,
      mBytesPerFrame: UInt32(self.bytesPerFrame),
      mChannelsPerFrame: UInt32(self.channels),
      mBitsPerChannel: pcmBitsPerSample,
      mReserved: 0
    )
    var format: CMAudioFormatDescription?
    let status = CMAudioFormatDescriptionCreate(
      allocator: kCFAllocatorDefault,
      asbd: &description,
      layoutSize: 0,
      layout: nil,
      magicCookieSize: 0,
      magicCookie: nil,
      extensions: nil,
      formatDescriptionOut: &format
    )
    guard status == noErr, let format = format else {
      throw LiveAudioFailure.unwritable("The PCM format could not be described.")
    }
    return format
  }

  private func sampleBuffer(_ bytes: Data, frames: Int) throws -> CMSampleBuffer {
    guard let format = self.format else {
      throw LiveAudioFailure.unwritable("The encoder is not open.")
    }
    var block: CMBlockBuffer?
    let blockStatus = CMBlockBufferCreateWithMemoryBlock(
      allocator: kCFAllocatorDefault,
      memoryBlock: nil,
      blockLength: bytes.count,
      blockAllocator: kCFAllocatorDefault,
      customBlockSource: nil,
      offsetToData: 0,
      dataLength: bytes.count,
      flags: kCMBlockBufferAssureMemoryNowFlag,
      blockBufferOut: &block
    )
    guard blockStatus == kCMBlockBufferNoErr, let block = block else {
      throw LiveAudioFailure.unwritable("A sound block could not be allocated.")
    }
    let copyStatus = bytes.withUnsafeBytes { raw -> OSStatus in
      guard let base = raw.baseAddress else {
        return kCMBlockBufferBadPointerParameterErr
      }
      return CMBlockBufferReplaceDataBytes(
        with: base,
        blockBuffer: block,
        offsetIntoDestination: 0,
        dataLength: bytes.count
      )
    }
    guard copyStatus == kCMBlockBufferNoErr else {
      throw LiveAudioFailure.unwritable("A sound block could not be filled.")
    }
    var sample: CMSampleBuffer?
    let sampleStatus = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
      allocator: kCFAllocatorDefault,
      dataBuffer: block,
      formatDescription: format,
      sampleCount: frames,
      presentationTimeStamp: CMTime(
        value: self.framesAppended,
        timescale: CMTimeScale(self.sampleRate)
      ),
      packetDescriptions: nil,
      sampleBufferOut: &sample
    )
    guard sampleStatus == noErr, let sample = sample else {
      throw LiveAudioFailure.unwritable("A sound sample could not be made.")
    }
    return sample
  }
}

private final class JoinProgress {
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
          ?? LiveAudioFailure.unwritable("The writer stopped.")
      }
      _ = self.condition.wait(until: Date().addingTimeInterval(joinStatusPollSeconds))
    }
    return self.failure
  }
}

final class LiveAudioBridge {
  private let channel: FlutterMethodChannel
  private var encoders: [Int: LiveAudioEncoder] = [:]
  private var nextEncoderId = 1

  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: liveAudioChannelName,
      binaryMessenger: messenger
    )
    self.channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "openEncoder":
      self.openEncoder(arguments, result: result)
    case "appendPcm":
      self.appendPcm(arguments, result: result)
    case "closeEncoder":
      self.closeEncoder(arguments, result: result)
    case "cancelEncoder":
      self.cancelEncoder(arguments, result: result)
    case "joinAudio":
      self.joinAudio(arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func openEncoder(_ arguments: [String: Any], result: @escaping FlutterResult) {
    guard let path = arguments["path"] as? String,
      let sampleRate = arguments["sampleRate"] as? Int,
      let channels = arguments["channels"] as? Int,
      let bitRate = arguments["bitRate"] as? Int,
      sampleRate > 0, channels > 0, bitRate > 0
    else {
      result(
        LiveAudioBridge.flutterError(
          encodeFailedCode,
          LiveAudioFailure.badArguments(
            "A path, a sample rate, a channel count and a bit rate are required."
          )
        )
      )
      return
    }
    let id = self.nextEncoderId
    self.nextEncoderId += 1
    let encoder = LiveAudioEncoder(
      id: id,
      path: path,
      sampleRate: sampleRate,
      channels: channels,
      bitRate: bitRate
    )
    self.encoders[id] = encoder
    encoder.queue.async { [weak self] in
      let reply: Any
      do {
        try encoder.open()
        reply = id
      } catch {
        encoder.cancel()
        reply = LiveAudioBridge.flutterError(encodeFailedCode, error)
      }
      DispatchQueue.main.async {
        if reply is FlutterError {
          self?.encoders.removeValue(forKey: id)
        }
        result(reply)
      }
    }
  }

  private func appendPcm(_ arguments: [String: Any], result: @escaping FlutterResult) {
    guard let id = arguments["id"] as? Int,
      let pcm = arguments["pcm"] as? FlutterStandardTypedData
    else {
      result(
        LiveAudioBridge.flutterError(
          encodeFailedCode,
          LiveAudioFailure.badArguments("An encoder id and PCM bytes are required.")
        )
      )
      return
    }
    guard let encoder = self.encoders[id] else {
      result(LiveAudioBridge.flutterError(encodeFailedCode, LiveAudioFailure.unknownEncoder(id)))
      return
    }
    let bytes = pcm.data
    LiveAudioBridge.run(on: encoder.queue, code: encodeFailedCode, result: result) {
      try encoder.append(bytes)
      return nil
    }
  }

  private func closeEncoder(_ arguments: [String: Any], result: @escaping FlutterResult) {
    guard let id = arguments["id"] as? Int else {
      result(
        LiveAudioBridge.flutterError(
          encodeFailedCode,
          LiveAudioFailure.badArguments("An encoder id is required.")
        )
      )
      return
    }
    guard let encoder = self.encoders.removeValue(forKey: id) else {
      result(LiveAudioBridge.flutterError(encodeFailedCode, LiveAudioFailure.unknownEncoder(id)))
      return
    }
    LiveAudioBridge.run(on: encoder.queue, code: encodeFailedCode, result: result) {
      try encoder.close()
    }
  }

  private func cancelEncoder(_ arguments: [String: Any], result: @escaping FlutterResult) {
    guard let id = arguments["id"] as? Int else {
      result(
        LiveAudioBridge.flutterError(
          encodeFailedCode,
          LiveAudioFailure.badArguments("An encoder id is required.")
        )
      )
      return
    }
    guard let encoder = self.encoders.removeValue(forKey: id) else {
      result(nil)
      return
    }
    LiveAudioBridge.run(on: encoder.queue, code: encodeFailedCode, result: result) {
      encoder.cancel()
      return nil
    }
  }

  private func joinAudio(_ arguments: [String: Any], result: @escaping FlutterResult) {
    guard let video = arguments["video"] as? String,
      let audio = arguments["audio"] as? String,
      let output = arguments["output"] as? String
    else {
      result(
        LiveAudioBridge.flutterError(
          joinFailedCode,
          LiveAudioFailure.badArguments("A video, an audio file and an output path are required.")
        )
      )
      return
    }
    let queue = DispatchQueue(label: "field_notes.live_audio.join.\(UUID().uuidString)")
    LiveAudioBridge.run(on: queue, code: joinFailedCode, result: result) {
      try LiveAudioBridge.join(video: video, audio: audio, output: output)
    }
  }

  private static func run(
    on queue: DispatchQueue,
    code: String,
    result: @escaping FlutterResult,
    _ job: @escaping () throws -> Any?
  ) {
    queue.async {
      let reply: Any?
      do {
        reply = try job()
      } catch {
        reply = LiveAudioBridge.flutterError(code, error)
      }
      DispatchQueue.main.async {
        result(reply)
      }
    }
  }

  private static func flutterError(_ code: String, _ error: Error) -> FlutterError {
    return FlutterError(code: code, message: "\(error)", details: nil)
  }

  private static func join(video: String, audio: String, output: String) throws -> String {
    let outputURL = URL(fileURLWithPath: output)
    try? FileManager.default.removeItem(at: outputURL)
    do {
      try LiveAudioBridge.copyTracks(video: video, audio: audio, to: outputURL)
      return output
    } catch {
      try? FileManager.default.removeItem(at: outputURL)
      throw error
    }
  }

  private static func copyTracks(video: String, audio: String, to outputURL: URL) throws {
    let pictureAsset = AVURLAsset(url: URL(fileURLWithPath: video))
    let soundAsset = AVURLAsset(url: URL(fileURLWithPath: audio))
    guard let videoTrack = pictureAsset.tracks(withMediaType: .video).first else {
      throw LiveAudioFailure.unreadable("The video file has no picture track.")
    }
    guard let audioTrack = soundAsset.tracks(withMediaType: .audio).first else {
      throw LiveAudioFailure.unreadable("The audio file has no sound track.")
    }

    let pictureReader = try AVAssetReader(asset: pictureAsset)
    let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
    videoOutput.alwaysCopiesSampleData = false
    guard pictureReader.canAdd(videoOutput) else {
      throw LiveAudioFailure.unreadable("The picture track cannot be read.")
    }
    pictureReader.add(videoOutput)

    let pictureRange = videoTrack.timeRange
    let trimsSound = pictureRange.duration.isNumeric && pictureRange.duration > .zero
    let soundReader = try AVAssetReader(asset: soundAsset)
    if trimsSound {
      soundReader.timeRange = CMTimeRange(start: .zero, duration: pictureRange.duration)
    }
    let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
    audioOutput.alwaysCopiesSampleData = false
    guard soundReader.canAdd(audioOutput) else {
      throw LiveAudioFailure.unreadable("The sound track cannot be read.")
    }
    soundReader.add(audioOutput)

    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    let videoInput = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: nil,
      sourceFormatHint: LiveAudioBridge.formatHint(of: videoTrack)
    )
    videoInput.transform = videoTrack.preferredTransform
    videoInput.expectsMediaDataInRealTime = false
    let audioInput = AVAssetWriterInput(
      mediaType: .audio,
      outputSettings: nil,
      sourceFormatHint: LiveAudioBridge.formatHint(of: audioTrack)
    )
    audioInput.expectsMediaDataInRealTime = false
    for input in [videoInput, audioInput] {
      guard writer.canAdd(input) else {
        throw LiveAudioFailure.unwritable("A track cannot be written to the joined file.")
      }
      writer.add(input)
    }

    guard writer.startWriting() else {
      throw writer.error ?? LiveAudioFailure.unwritable("The joined file did not open.")
    }
    writer.startSession(atSourceTime: .zero)
    let readers = [pictureReader, soundReader]
    for reader in readers {
      guard reader.startReading() else {
        LiveAudioBridge.abandon(writer, readers: readers)
        throw reader.error ?? LiveAudioFailure.unreadable("A track did not open.")
      }
    }

    let progress = JoinProgress(inputs: 2)
    LiveAudioBridge.pump(
      videoOutput,
      into: videoInput,
      label: "field_notes.live_audio.join.video",
      progress: progress
    )
    LiveAudioBridge.pump(
      audioOutput,
      into: audioInput,
      label: "field_notes.live_audio.join.audio",
      progress: progress
    )
    if let failure = progress.wait(for: writer) {
      LiveAudioBridge.abandon(writer, readers: readers)
      throw failure
    }
    if let failed = readers.first(where: { $0.status == .failed }) {
      LiveAudioBridge.abandon(writer, readers: readers)
      throw failed.error ?? LiveAudioFailure.unreadable("A track could not be read.")
    }

    if trimsSound {
      writer.endSession(atSourceTime: pictureRange.end)
    }
    let finished = DispatchSemaphore(value: 0)
    writer.finishWriting {
      finished.signal()
    }
    finished.wait()
    guard writer.status == .completed else {
      throw writer.error ?? LiveAudioFailure.unwritable("The joined file did not finish.")
    }
  }

  private static func formatHint(of track: AVAssetTrack) -> CMFormatDescription? {
    return (track.formatDescriptions as? [CMFormatDescription])?.first
  }

  private static func abandon(_ writer: AVAssetWriter, readers: [AVAssetReader]) {
    readers.forEach { $0.cancelReading() }
    if writer.status == .writing {
      writer.cancelWriting()
    }
  }

  private static func pump(
    _ trackOutput: AVAssetReaderTrackOutput,
    into writerInput: AVAssetWriterInput,
    label: String,
    progress: JoinProgress
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
          progress.finish(LiveAudioFailure.unwritable("A sample could not be copied."))
          return
        }
      }
    }
  }
}
