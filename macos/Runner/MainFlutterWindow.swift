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

private let titleBarHeight: CGFloat = 42
private let windowButtonsLeading: CGFloat = 16
private let windowChannelName = "field_notes/window"

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.contentMinSize = NSSize(
      width: minimumContentWidth,
      height: minimumContentHeight
    )
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.setFrame(self.frameAtLeastMinimum(windowFrame), display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    self.registerWindowChannel(flutterViewController.engine.binaryMessenger)
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
      default:
        result(FlutterMethodNotImplemented)
      }
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
  }

  @objc private func layoutWindowButtons() {
    guard !self.styleMask.contains(.fullScreen),
      let close = self.standardWindowButton(.closeButton),
      let miniaturize = self.standardWindowButton(.miniaturizeButton),
      let zoom = self.standardWindowButton(.zoomButton),
      let container = close.superview?.superview
    else {
      return
    }
    let pitch = miniaturize.frame.minX - close.frame.minX
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

  private func frameAtLeastMinimum(_ frame: NSRect) -> NSRect {
    let minimumFrame = self.frameRect(
      forContentRect: NSRect(origin: frame.origin, size: self.contentMinSize)
    )
    return NSRect(
      x: frame.origin.x,
      y: frame.origin.y,
      width: max(frame.width, minimumFrame.width),
      height: max(frame.height, minimumFrame.height)
    )
  }
}
