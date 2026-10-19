import AVFoundation
import FlutterMacOS
import Cocoa

public class RecordMacOsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let binaryMessenger = registrar.messenger
    let methodChannel = FlutterMethodChannel(name: "com.llfbandit.record/messages", binaryMessenger: binaryMessenger)
    let instance = RecordMacOsPlugin(binaryMessenger: binaryMessenger)
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
  }

  private struct RecorderEntry {
    let recorder: Recorder
    let queue: DispatchQueue
  }

  private static let streamStartTimeout = DispatchTimeInterval.seconds(2)

  private var m_binaryMessenger: FlutterBinaryMessenger
  private let m_registryQueue = DispatchQueue(label: "com.record.pluginQueue", qos: .userInitiated)
  private var m_recorders = [String: RecorderEntry]()

  init(binaryMessenger: FlutterBinaryMessenger) {
    self.m_binaryMessenger = binaryMessenger
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    dispose()
  }

  func dispose() {
    let entries = m_registryQueue.sync { () -> [RecorderEntry] in
      let all = Array(m_recorders.values)
      m_recorders = [:]
      return all
    }
    for entry in entries {
      entry.queue.async { entry.recorder.dispose() }
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "record", message: "Failed to parse call.arguments from Flutter.", details: nil))
      return
    }
    guard let recorderId = args["recorderId"] as? String else {
      result(FlutterError(code: "record", message: "Call missing mandatory parameter recorderId.", details: nil))
      return
    }

    if call.method == "hasPermission" {
      handleHasPermission(args: args, result: result)
      return
    }

    if call.method == "create" {
      handleCreate(recorderId: recorderId, result: result)
      return
    }

    if call.method == "startStream" {
      let reply = BoundedStartReply(result: result)
      DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + RecordMacOsPlugin.streamStartTimeout) {
        reply.expire()
      }
      withRecorder(recorderId: recorderId, result: reply.send) { recorder in
        self.handleStartStream(recorder: recorder, args: args, reply: reply)
      }
      return
    }

    withRecorder(recorderId: recorderId, result: result) { recorder in
      switch call.method {
      case "start":        self.handleStart(recorder: recorder, args: args, result: result)
      case "stop":         self.handleStop(recorder: recorder, result: result)
      case "cancel":       self.handleCancel(recorder: recorder, result: result)
      case "pause":        self.handlePause(recorder: recorder, result: result)
      case "resume":       self.handleResume(recorder: recorder, result: result)
      case "isPaused":     self.run(result: result) { recorder.isPaused() }
      case "isRecording":  self.run(result: result) { recorder.isRecording() }
      case "getAmplitude": self.run(result: result) { recorder.getAmplitude() }
      case "isEncoderSupported": self.handleIsEncoderSupported(recorder: recorder, args: args, result: result)
      case "listInputDevices":   self.handleListInputDevices(recorder: recorder, result: result)
      case "dispose":            self.handleDispose(recorderId: recorderId, recorder: recorder, result: result)
      default: DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
      }
    }
  }

  private func handleCreate(recorderId: String, result: @escaping FlutterResult) {
    let stateEventChannel = FlutterEventChannel(name: "com.llfbandit.record/events/\(recorderId)", binaryMessenger: m_binaryMessenger)
    let stateEventHandler = StateStreamHandler()
    stateEventChannel.setStreamHandler(stateEventHandler)

    let recordEventChannel = FlutterEventChannel(name: "com.llfbandit.record/eventsRecord/\(recorderId)", binaryMessenger: m_binaryMessenger)
    let recordEventHandler = RecordStreamHandler()
    recordEventChannel.setStreamHandler(recordEventHandler)

    let configChangedChannel = FlutterMethodChannel(name: "com.llfbandit.record/configChanged/\(recorderId)", binaryMessenger: m_binaryMessenger)
    let queue = DispatchQueue(label: "com.record.recorderQueue.\(recorderId)", qos: .userInitiated)
    let recorder = Recorder(queue: queue, stateEventHandler: stateEventHandler, recordEventHandler: recordEventHandler, configChangedChannel: configChangedChannel)
    let entry = RecorderEntry(recorder: recorder, queue: queue)

    let replaced = m_registryQueue.sync { () -> RecorderEntry? in
      let previous = m_recorders[recorderId]
      m_recorders[recorderId] = entry
      return previous
    }
    if let replaced {
      replaced.queue.async { replaced.recorder.dispose() }
    }
    DispatchQueue.main.async { result(nil) }
  }

  private func handleStart(recorder: Recorder, args: [String: Any], result: @escaping FlutterResult) {
    guard let path = args["path"] as? String else {
      DispatchQueue.main.async { result(FlutterError(code: "record", message: "Call missing mandatory parameter path.", details: nil)) }
      return
    }
    run(result: result) { try recorder.start(config: try RecordConfig.fromMap(args), path: path) }
  }

  private func handleStartStream(recorder: Recorder, args: [String: Any], reply: BoundedStartReply) {
    run(result: reply.send) {
      try recorder.startStream(config: try RecordConfig.fromMap(args), keepStart: reply.keep)
    }
  }

  private func handleStop(recorder: Recorder, result: @escaping FlutterResult) {
    let path = recorder.stop()
    DispatchQueue.main.async { result(path) }
  }

  private func handleCancel(recorder: Recorder, result: @escaping FlutterResult) {
    run(result: result) { try recorder.cancel() }
  }

  private func handlePause(recorder: Recorder, result: @escaping FlutterResult) {
    recorder.pause()
    DispatchQueue.main.async { result(nil) }
  }

  private func handleResume(recorder: Recorder, result: @escaping FlutterResult) {
    run(result: result) { try recorder.resume() }
  }

  private func handleHasPermission(args: [String: Any], result: @escaping FlutterResult) {
    let request = args["request"] as? Bool ?? true
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      result(true)
    case .notDetermined:
      if request {
        AVCaptureDevice.requestAccess(for: .audio) { allowed in
          DispatchQueue.main.async { result(allowed) }
        }
      } else {
        result(false)
      }
    default:
      result(false)
    }
  }

  private func handleIsEncoderSupported(recorder: Recorder, args: [String: Any], result: @escaping FlutterResult) {
    guard let encoder = args["encoder"] as? String else {
      DispatchQueue.main.async { result(FlutterError(code: "record", message: "Call missing mandatory parameter encoder.", details: nil)) }
      return
    }
    run(result: result) { recorder.isEncoderSupported(encoder) }
  }

  private func handleListInputDevices(recorder: Recorder, result: @escaping FlutterResult) {
    run(result: result) { try recorder.listInputDevices().map { $0.toMap() } }
  }

  private func handleDispose(recorderId: String, recorder: Recorder, result: @escaping FlutterResult) {
    m_registryQueue.sync {
      if m_recorders[recorderId]?.recorder === recorder {
        m_recorders.removeValue(forKey: recorderId)
      }
    }
    recorder.dispose()
    DispatchQueue.main.async { result(nil) }
  }

  private func withRecorder(
    recorderId: String,
    result: @escaping FlutterResult,
    _ block: @escaping (Recorder) -> ()
  ) {
    guard let entry = m_registryQueue.sync(execute: { m_recorders[recorderId] }) else {
      DispatchQueue.main.async {
        result(FlutterError(code: "record", message: "Recorder has not yet been created or has already been disposed.", details: nil))
      }
      return
    }
    entry.queue.async { block(entry.recorder) }
  }

  private func run<T>(result: @escaping FlutterResult, _ block: () throws -> T) {
    do {
      let value = try block()
      DispatchQueue.main.async {
        if T.self == Void.self { result(nil) } else { result(value) }
      }
    } catch let RecorderError.error(message, details) {
      DispatchQueue.main.async { result(FlutterError(code: "record", message: message, details: details)) }
    } catch {
      DispatchQueue.main.async { result(FlutterError(code: "record", message: error.localizedDescription, details: nil)) }
    }
  }
}

final class BoundedStartReply {
  private enum Phase {
    case waiting
    case kept
    case replied
    case expired
  }

  private let m_lock = NSLock()
  private let m_result: FlutterResult
  private var m_phase = Phase.waiting

  init(result: @escaping FlutterResult) {
    m_result = result
  }

  func keep() -> Bool {
    m_lock.withLock { () -> Bool in
      if m_phase == .waiting { m_phase = .kept }
      return m_phase == .kept
    }
  }

  func send(_ value: Any?) {
    let deliver = m_lock.withLock { () -> Bool in
      guard m_phase == .waiting || m_phase == .kept else { return false }
      m_phase = .replied
      return true
    }
    if deliver { m_result(value) }
  }

  func expire() {
    let deliver = m_lock.withLock { () -> Bool in
      guard m_phase == .waiting else { return false }
      m_phase = .expired
      return true
    }
    guard deliver else { return }
    let result = m_result
    DispatchQueue.main.async {
      result(FlutterError(code: "record", message: RecorderStreamDelegate.startTimedOutMessage, details: nil))
    }
  }
}
