import FlutterMacOS

public class StateStreamHandler: NSObject, FlutterStreamHandler {
  private var m_eventSink: FlutterEventSink?
  private let m_lock = NSLock()

  var eventSink: FlutterEventSink? { m_lock.withLock { m_eventSink } }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    m_lock.withLock { m_eventSink = events }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    m_lock.withLock { m_eventSink = nil }
    return nil
  }
}

public class RecordStreamHandler: NSObject, FlutterStreamHandler {
  private var m_eventSink: FlutterEventSink?
  private let m_lock = NSLock()

  var eventSink: FlutterEventSink? { m_lock.withLock { m_eventSink } }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    m_lock.withLock { m_eventSink = events }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    m_lock.withLock { m_eventSink = nil }
    return nil
  }
}

struct CapturedAudio {
  let firstFrame: Int64
  let frames: Int
  let capturedAtNs: Int64
}

typealias CapturedAudioReport = (CapturedAudio) -> ()

class CapturedAudioReporter {
  static let channelName = "com.llfbandit.record/streamClock"

  private let m_channel: FlutterMethodChannel
  private let m_recorderId: String

  init(channel: FlutterMethodChannel, recorderId: String) {
    m_channel = channel
    m_recorderId = recorderId
  }

  func report(_ captured: CapturedAudio) {
    let arguments: [String: Any] = [
      "recorderId": m_recorderId,
      "firstFrame": captured.firstFrame,
      "frames": captured.frames,
      "capturedAtNs": captured.capturedAtNs,
    ]
    DispatchQueue.main.async { self.m_channel.invokeMethod("captured", arguments: arguments) }
  }
}
