import Cocoa
import FlutterMacOS
import Sparkle

private let updaterChannelName = "field_notes/updater"
private let updaterEventChannelName = "field_notes/updater/events"
private let updaterInstallMethod = "install"
private let updaterPublicKeyName = "SUPublicEDKey"
private let restartReplyDelay: TimeInterval = 0.6

final class SparkleUpdaterBridge: NSObject, FlutterStreamHandler {
  private let channel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?
  private var updater: SPUUpdater?
  private var userDriver: SparkleUserDriver?

  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: updaterChannelName,
      binaryMessenger: messenger
    )
    self.eventChannel = FlutterEventChannel(
      name: updaterEventChannelName,
      binaryMessenger: messenger
    )
    super.init()
    self.channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.eventChannel.setStreamHandler(self)
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case updaterInstallMethod:
      guard let arguments = call.arguments as? [String: Any],
        let version = arguments["version"] as? String,
        !version.isEmpty
      else {
        result(
          FlutterError(
            code: "bad-arguments",
            message: "install expects a version string under \"version\"",
            details: nil
          )
        )
        return
      }
      self.install(version: version, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func install(version: String, result: @escaping FlutterResult) {
    guard SparkleUpdaterBridge.hasPublicKey() else {
      result(
        FlutterError(
          code: "unavailable",
          message: "This build carries no update key.",
          details: nil
        )
      )
      return
    }
    guard let updater = self.startedUpdater(), let driver = self.userDriver else {
      result(
        FlutterError(
          code: "unavailable",
          message: "The updater could not start.",
          details: nil
        )
      )
      return
    }
    driver.expect(version: version)
    updater.checkForUpdates()
    result(nil)
  }

  private func startedUpdater() -> SPUUpdater? {
    if let updater = self.updater {
      return updater
    }
    let driver = SparkleUserDriver { [weak self] event in
      self?.eventSink?(event)
    }
    let updater = SPUUpdater(
      hostBundle: Bundle.main,
      applicationBundle: Bundle.main,
      userDriver: driver,
      delegate: nil
    )
    do {
      try updater.start()
    } catch {
      return nil
    }
    self.userDriver = driver
    self.updater = updater
    return updater
  }

  private static func hasPublicKey() -> Bool {
    let key = Bundle.main.object(forInfoDictionaryKey: updaterPublicKeyName) as? String ?? ""
    return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

final class SparkleUserDriver: NSObject, SPUUserDriver {
  private let send: ([String: Any]) -> Void
  private var expectedVersion: String?
  private var expectedLength: UInt64 = 0
  private var receivedLength: UInt64 = 0

  init(send: @escaping ([String: Any]) -> Void) {
    self.send = send
    super.init()
  }

  func expect(version: String) {
    self.expectedVersion = version
    self.expectedLength = 0
    self.receivedLength = 0
  }

  func show(
    _ request: SPUUpdatePermissionRequest,
    reply: @escaping (SUUpdatePermissionResponse) -> Void
  ) {
    reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
  }

  func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
  }

  func showUpdateFound(
    with appcastItem: SUAppcastItem,
    state: SPUUserUpdateState,
    reply: @escaping (SPUUserUpdateChoice) -> Void
  ) {
    let offered = appcastItem.displayVersionString
    guard let expected = self.expectedVersion, offered == expected else {
      self.send(["event": "mismatch", "version": offered])
      reply(.dismiss)
      return
    }
    self.send(["event": "found"])
    reply(.install)
  }

  func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
  }

  func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {
  }

  func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
    self.send(["event": "notFound"])
    acknowledgement()
  }

  func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
    self.send(["event": "error", "message": error.localizedDescription])
    acknowledgement()
  }

  func showDownloadInitiated(cancellation: @escaping () -> Void) {
  }

  func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
    self.expectedLength = expectedContentLength
    self.receivedLength = 0
    self.send([
      "event": "progress",
      "received": NSNumber(value: 0),
      "total": NSNumber(value: expectedContentLength),
    ])
  }

  func showDownloadDidReceiveData(ofLength length: UInt64) {
    self.receivedLength += length
    self.send([
      "event": "progress",
      "received": NSNumber(value: self.receivedLength),
      "total": NSNumber(value: self.expectedLength),
    ])
  }

  func showDownloadDidStartExtractingUpdate() {
    self.send(["event": "verifying"])
  }

  func showExtractionReceivedProgress(_ progress: Double) {
    self.send(["event": "verifying"])
  }

  func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
    self.send(["event": "restarting"])
    DispatchQueue.main.asyncAfter(deadline: .now() + restartReplyDelay) {
      reply(.install)
    }
  }

  func showInstallingUpdate(
    withApplicationTerminated applicationTerminated: Bool,
    retryTerminatingApplication: @escaping () -> Void
  ) {
    self.send(["event": "installing"])
  }

  func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
    acknowledgement()
  }

  func dismissUpdateInstallation() {
    self.send(["event": "dismissed"])
  }
}
