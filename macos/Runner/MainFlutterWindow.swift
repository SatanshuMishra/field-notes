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

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.contentMinSize = NSSize(
      width: minimumContentWidth,
      height: minimumContentHeight
    )
    self.setFrame(self.frameAtLeastMinimum(windowFrame), display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
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
