import AVFoundation
import Foundation
import FlutterMacOS

class RecorderStreamDelegate: NSObject, AudioRecordingStreamDelegate {
  var config: RecordConfig?

  private static let maxRestartAttempts = 5
  private static let restartDelay = DispatchTimeInterval.milliseconds(300)
  private static let stoppedMessage = "microphone stopped"
  static let startTimedOutMessage = "microphone start timed out"

  private var m_audioEngine: AVAudioEngine?
  private var m_processor: AudioStreamProcessor?
  private var m_recordEventHandler: RecordStreamHandler?
  private var m_configChangeObserver: NSObjectProtocol?
  private var m_restartPending = false
  private var m_rebuildOnResume = false
  private var m_isPaused = false
  private let m_lock = NSLock()
  private let m_bus = 0
  private let m_queue: DispatchQueue
  private let m_keepStart: () -> Bool
  private var m_onRecord: () -> ()
  private var m_onPause:  () -> ()
  private var m_onStop:   () -> ()

  init(
    queue: DispatchQueue,
    keepStart: @escaping () -> Bool = { true },
    onRecord: @escaping () -> (),
    onPause:  @escaping () -> (),
    onStop:   @escaping () -> ()
  ) {
    m_queue = queue
    m_keepStart = keepStart
    m_onRecord = onRecord
    m_onPause  = onPause
    m_onStop   = onStop
  }

  func start(config: RecordConfig, recordEventHandler: RecordStreamHandler) throws {
    let engine = AVAudioEngine()

    try selectInputDevice(config: config, engine: engine, required: false)

    try setVoiceProcessing(echoCancel: config.echoCancel, autoGain: config.autoGain, audioEngine: engine)

    let srcFormat = engine.inputNode.inputFormat(forBus: 0)
    let processor = try AudioStreamProcessor(config: config, srcFormat: srcFormat)

    installTap(engine: engine, config: config, format: srcFormat, recordEventHandler: recordEventHandler)

    engine.prepare()
    do {
      try engine.start()
    } catch {
      engine.inputNode.removeTap(onBus: m_bus)
      processor.dispose()
      throw error
    }

    guard m_keepStart() else {
      engine.inputNode.removeTap(onBus: m_bus)
      engine.stop()
      processor.dispose()
      throw RecorderError.error(message: RecorderStreamDelegate.startTimedOutMessage, details: nil)
    }

    m_audioEngine = engine
    m_recordEventHandler = recordEventHandler
    m_lock.withLock { m_processor = processor }
    self.config = config
    observeConfigurationChange(engine: engine)
    m_onRecord()
  }

  @discardableResult
  func stop() -> String? {
    if let observer = m_configChangeObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    m_configChangeObserver = nil
    m_restartPending = false
    m_rebuildOnResume = false

    if let engine = m_audioEngine {
      do { try setVoiceProcessing(echoCancel: false, autoGain: false, audioEngine: engine) } catch {}
      engine.inputNode.removeTap(onBus: m_bus)
      engine.stop()
    }
    m_audioEngine = nil
    m_recordEventHandler = nil

    m_lock.withLock {
      m_isPaused = false
      m_processor?.dispose()
      m_processor = nil
    }

    config = nil
    m_onStop()
    return nil
  }

  func pause() {
    m_lock.withLock { m_isPaused = true }
    m_audioEngine?.pause()
    m_onPause()
  }

  func resume() throws {
    if m_rebuildOnResume, let engine = m_audioEngine, let config, let recordEventHandler = m_recordEventHandler {
      try rebuild(engine: engine, config: config, recordEventHandler: recordEventHandler)
      m_rebuildOnResume = false
    } else {
      try m_audioEngine?.start()
    }
    m_lock.withLock { m_isPaused = false }
    m_onRecord()
  }

  func cancel() throws { _ = stop() }

  func getAmplitude() -> Float {
    m_lock.withLock { m_processor?.getAmplitude() ?? -160.0 }
  }

  func dispose() { _ = stop() }

  private func selectInputDevice(config: RecordConfig, engine: AVAudioEngine, required: Bool) throws {
    guard let deviceId = config.device?.id else { return }
    guard let inputDeviceId = getAudioDeviceIDFromUID(uid: deviceId) else {
      guard required else { return }
      throw RecorderError.error(
        message: "Failed to start recording",
        details: "Input device not found: \(deviceId)"
      )
    }
    do {
      try engine.inputNode.auAudioUnit.setDeviceID(inputDeviceId)
    } catch {
      throw RecorderError.error(
        message: "Failed to start recording",
        details: "Setting input device: \(deviceId) \(error)"
      )
    }
  }

  private func installTap(
    engine: AVAudioEngine,
    config: RecordConfig,
    format: AVAudioFormat,
    recordEventHandler: RecordStreamHandler
  ) {
    engine.inputNode.installTap(
      onBus: m_bus,
      bufferSize: AVAudioFrameCount(config.streamBufferSize ?? 1024),
      format: format
    ) { [weak self] buffer, _ in
      self?.handleTap(buffer: buffer, recordEventHandler: recordEventHandler)
    }
  }

  private func observeConfigurationChange(engine: AVAudioEngine) {
    m_configChangeObserver = NotificationCenter.default.addObserver(
      forName: .AVAudioEngineConfigurationChange,
      object: engine,
      queue: nil
    ) { [weak self, weak engine] _ in
      guard let self, let engine else { return }
      self.m_queue.async { self.scheduleRestart(engine: engine) }
    }
  }

  private func scheduleRestart(engine: AVAudioEngine) {
    guard m_audioEngine === engine, !m_restartPending else { return }
    m_restartPending = true
    restart(engine: engine, attempt: 1)
  }

  private func restart(engine: AVAudioEngine, attempt: Int) {
    guard m_audioEngine === engine,
          let config,
          let recordEventHandler = m_recordEventHandler else { return }

    if m_lock.withLock({ m_isPaused }) {
      m_rebuildOnResume = true
      m_restartPending = false
      return
    }

    if engine.isRunning {
      m_restartPending = false
      return
    }

    do {
      try rebuild(engine: engine, config: config, recordEventHandler: recordEventHandler)
      m_restartPending = false
    } catch {
      guard attempt < RecorderStreamDelegate.maxRestartAttempts else {
        reportStopped(recordEventHandler: recordEventHandler)
        stop()
        return
      }
      m_queue.asyncAfter(deadline: .now() + RecorderStreamDelegate.restartDelay) { [weak self] in
        self?.restart(engine: engine, attempt: attempt + 1)
      }
    }
  }

  private func rebuild(
    engine: AVAudioEngine,
    config: RecordConfig,
    recordEventHandler: RecordStreamHandler
  ) throws {
    engine.inputNode.removeTap(onBus: m_bus)
    engine.stop()

    try selectInputDevice(config: config, engine: engine, required: true)
    try setVoiceProcessing(echoCancel: config.echoCancel, autoGain: config.autoGain, audioEngine: engine)

    let srcFormat = engine.inputNode.inputFormat(forBus: 0)
    guard srcFormat.sampleRate > 0, srcFormat.channelCount > 0 else {
      throw RecorderError.error(
        message: RecorderStreamDelegate.stoppedMessage,
        details: "Input has no format."
      )
    }
    let processor = try AudioStreamProcessor(config: config, srcFormat: srcFormat)

    installTap(engine: engine, config: config, format: srcFormat, recordEventHandler: recordEventHandler)

    engine.prepare()
    do {
      try engine.start()
    } catch {
      engine.inputNode.removeTap(onBus: m_bus)
      processor.dispose()
      throw error
    }

    let replaced = m_lock.withLock { () -> AudioStreamProcessor? in
      let previous = m_processor
      m_processor = processor
      return previous
    }
    replaced?.dispose()
  }

  private func reportStopped(recordEventHandler: RecordStreamHandler) {
    guard let sink = recordEventHandler.eventSink else { return }
    let error = FlutterError(code: "record", message: RecorderStreamDelegate.stoppedMessage, details: nil)
    DispatchQueue.main.async { sink(error) }
  }

  private func handleTap(buffer: AVAudioPCMBuffer, recordEventHandler: RecordStreamHandler) {
    let processor = m_lock.withLock { m_isPaused ? nil : m_processor }

    guard let processor else { return }

    guard let dataList = processor.process(buffer: buffer) else {
      let failed = m_lock.withLock { () -> AudioStreamProcessor? in
        guard m_processor === processor else { return nil }
        m_processor = nil
        return processor
      }
      guard let failed else { return }
      m_queue.async {
        failed.dispose()
        self.reportStopped(recordEventHandler: recordEventHandler)
        self.stop()
      }
      return
    }

    guard let sink = recordEventHandler.eventSink else { return }
    for data in dataList {
      DispatchQueue.main.async { sink(FlutterStandardTypedData(bytes: data)) }
    }
  }

  private func setVoiceProcessing(echoCancel: Bool, autoGain: Bool, audioEngine: AVAudioEngine) throws {
    do {
      try audioEngine.inputNode.setVoiceProcessingEnabled(echoCancel)
      audioEngine.inputNode.isVoiceProcessingAGCEnabled = autoGain
    } catch {
      throw RecorderError.error(
        message: "Failed to setup voice processing",
        details: "Echo cancel error: \(error)"
      )
    }
  }
}
