import Cocoa
import FlutterMacOS

private let sidebarWidth: CGFloat = 216
private let todayRailWidth: CGFloat = 266
private let seamWidth: CGFloat = 1
private let todayPanePadding: CGFloat = 24
private let entryCardPadding: CGFloat = 15
private let noteBodyFontSize: CGFloat = 16
private let minimumReadingColumnEm: CGFloat = 19.4

private let minimumContentWidth: CGFloat =
  sidebarWidth + seamWidth
  + todayPanePadding + entryCardPadding
  + minimumReadingColumnEm * noteBodyFontSize
  + entryCardPadding + todayPanePadding
  + seamWidth + todayRailWidth
private let minimumContentHeight: CGFloat = 600
private let openingWindowWidth: CGFloat = 1200
private let openingWindowHeight: CGFloat = 800

private let titleBarHeight: CGFloat = 42
private let windowButtonsLeading: CGFloat = 16
private let windowChannelName = "field_notes/window"
private let notificationSettingsChannelName = "field_notes/notification_settings"
private let notificationSettingsURLPrefix =
  "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id="

class MainFlutterWindow: NSWindow {
  private var spellCheckBridge: SpellCheckBridge?
  private var imagePasteboardBridge: ImagePasteboardBridge?
  private var fileDropBridge: FileDropBridge?
  private var appearanceObservation: NSKeyValueObservation?
  private var windowButtonPitch: CGFloat = 0
  private var isLayingOutWindowButtons = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.contentMinSize = NSSize(
      width: minimumContentWidth,
      height: minimumContentHeight
    )
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.setFrame(self.openingFrame(), display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    self.registerWindowChannel(flutterViewController.engine.binaryMessenger)
    self.registerNotificationSettingsChannel(flutterViewController.engine.binaryMessenger)
    self.spellCheckBridge = SpellCheckBridge(messenger: flutterViewController.engine.binaryMessenger)
    self.imagePasteboardBridge = ImagePasteboardBridge(messenger: flutterViewController.engine.binaryMessenger)
    self.fileDropBridge = FileDropBridge(messenger: flutterViewController.engine.binaryMessenger, view: flutterViewController.view)
    self.observeWindowButtonLayout()

    super.awakeFromNib()
    self.layoutWindowButtons()
  }

  private func registerWindowChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: windowChannelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "startDrag":
        self?.startDrag()
        result(nil)
      case "titlebarDoubleClick":
        self?.performTitlebarDoubleClick()
        result(nil)
      case "setAppearance":
        NSApp.appearance = MainFlutterWindow.appearance(named: call.arguments as? String)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerNotificationSettingsChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: notificationSettingsChannelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "open":
        result(MainFlutterWindow.openNotificationSettings())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func openNotificationSettings() -> Any? {
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
    guard let url = URL(string: notificationSettingsURLPrefix + bundleIdentifier),
      NSWorkspace.shared.open(url)
    else {
      return FlutterError(
        code: "unavailable",
        message: "System Settings did not open.",
        details: nil
      )
    }
    return nil
  }

  private static func appearance(named id: String?) -> NSAppearance? {
    switch id {
    case "dark":
      return NSAppearance(named: .darkAqua)
    case "light":
      return NSAppearance(named: .aqua)
    default:
      return nil
    }
  }

  private func startDrag() {
    guard let event = NSApp.currentEvent,
      event.type == .leftMouseDown || event.type == .leftMouseDragged
    else {
      return
    }
    self.performDrag(with: event)
  }

  private func performTitlebarDoubleClick() {
    switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
    case "Minimize":
      self.performMiniaturize(nil)
    case "None":
      return
    default:
      self.performZoom(nil)
    }
  }

  private func observeWindowButtonLayout() {
    let names: [NSNotification.Name] = [
      NSWindow.didResizeNotification,
      NSWindow.didExitFullScreenNotification,
      NSWindow.didBecomeKeyNotification,
      NSWindow.didResignKeyNotification,
    ]
    for name in names {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(self.layoutWindowButtons),
        name: name,
        object: self
      )
    }
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.titlebarFrameDidChange(_:)),
      name: NSView.frameDidChangeNotification,
      object: nil
    )
    self.appearanceObservation = self.observe(\.effectiveAppearance) { window, _ in
      DispatchQueue.main.async {
        window.layoutWindowButtons()
      }
    }
  }

  @objc private func titlebarFrameDidChange(_ notification: Notification) {
    guard let view = notification.object as? NSView,
      view.window === self,
      let close = self.standardWindowButton(.closeButton),
      let miniaturize = self.standardWindowButton(.miniaturizeButton),
      let zoom = self.standardWindowButton(.zoomButton)
    else {
      return
    }
    let titlebarViews: [NSView?] = [
      close.superview?.superview,
      close.superview,
      close,
      miniaturize,
      zoom,
    ]
    guard titlebarViews.contains(where: { $0 === view }) else {
      return
    }
    self.layoutWindowButtons()
  }

  @objc private func layoutWindowButtons() {
    guard !self.isLayingOutWindowButtons,
      !self.styleMask.contains(.fullScreen),
      let close = self.standardWindowButton(.closeButton),
      let miniaturize = self.standardWindowButton(.miniaturizeButton),
      let zoom = self.standardWindowButton(.zoomButton),
      let container = close.superview?.superview
    else {
      return
    }
    let spacing = miniaturize.frame.minX - close.frame.minX
    if spacing > 0, spacing == zoom.frame.minX - miniaturize.frame.minX {
      self.windowButtonPitch = spacing
    }
    let pitch = self.windowButtonPitch > 0 ? self.windowButtonPitch : spacing
    guard pitch > 0 else {
      return
    }
    self.isLayingOutWindowButtons = true
    defer {
      self.isLayingOutWindowButtons = false
    }
    container.frame = NSRect(
      x: container.frame.minX,
      y: self.frame.height - titleBarHeight,
      width: container.frame.width,
      height: titleBarHeight
    )
    let buttonY = (titleBarHeight - close.frame.height) / 2
    for (index, button) in [close, miniaturize, zoom].enumerated() {
      button.setFrameOrigin(
        NSPoint(x: windowButtonsLeading + CGFloat(index) * pitch, y: buttonY)
      )
    }
  }

  private func openingFrame() -> NSRect {
    let minimumFrame = self.frameRect(
      forContentRect: NSRect(origin: .zero, size: self.contentMinSize)
    )
    let visible = (self.screen ?? NSScreen.main)?.visibleFrame
      ?? NSRect(x: 0, y: 0, width: openingWindowWidth, height: openingWindowHeight)
    let width = max(min(openingWindowWidth, visible.width), minimumFrame.width)
    let height = max(min(openingWindowHeight, visible.height), minimumFrame.height)
    return NSRect(
      x: visible.midX - width / 2,
      y: visible.midY - height / 2,
      width: width,
      height: height
    )
  }
}
