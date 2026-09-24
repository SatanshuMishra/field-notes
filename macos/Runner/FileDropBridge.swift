import Cocoa
import FlutterMacOS

private let fileDropChannelName = "field_notes/file_drop"
private let fileURLReadingOptions: [NSPasteboard.ReadingOptionKey: Any] = [
  .urlReadingFileURLsOnly: true
]

final class FileDropBridge {
  private let channel: FlutterMethodChannel
  private let view: NSView
  private let targetView: FileDropTargetView

  init(messenger: FlutterBinaryMessenger, view: NSView) {
    self.channel = FlutterMethodChannel(
      name: fileDropChannelName,
      binaryMessenger: messenger
    )
    self.view = view
    self.targetView = FileDropTargetView(channel: self.channel, frame: view.bounds)
    self.targetView.autoresizingMask = [.width, .height]
    self.targetView.setAccessibilityElement(false)
    self.targetView.registerForDraggedTypes([.fileURL])
    view.addSubview(self.targetView)
  }
}

final class FileDropTargetView: NSView {
  private let channel: FlutterMethodChannel

  init(channel: FlutterMethodChannel, frame: NSRect) {
    self.channel = channel
    super.init(frame: frame)
  }

  required init?(coder: NSCoder) {
    return nil
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    return nil
  }

  override func wantsPeriodicDraggingUpdates() -> Bool {
    return false
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    return self.hover(sender)
  }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    return self.hover(sender)
  }

  override func draggingExited(_ sender: NSDraggingInfo?) {
    self.channel.invokeMethod("leave", arguments: nil)
  }

  override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
    return self.holdsFileURLs(sender)
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let urls =
      sender.draggingPasteboard.readObjects(
        forClasses: [NSURL.self],
        options: fileURLReadingOptions
      ) as? [URL] ?? []
    let paths = urls.map { $0.path }
    let position = self.flutterPosition(sender)
    self.channel.invokeMethod(
      "drop",
      arguments: ["x": position.x, "y": position.y, "paths": paths]
    )
    return !paths.isEmpty
  }

  private func hover(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard self.holdsFileURLs(sender) else {
      return []
    }
    let position = self.flutterPosition(sender)
    self.channel.invokeMethod("hover", arguments: ["x": position.x, "y": position.y])
    return .copy
  }

  private func holdsFileURLs(_ sender: NSDraggingInfo) -> Bool {
    return sender.draggingPasteboard.canReadObject(
      forClasses: [NSURL.self],
      options: fileURLReadingOptions
    )
  }

  private func flutterPosition(_ sender: NSDraggingInfo) -> (x: Double, y: Double) {
    let point = self.convert(sender.draggingLocation, from: nil)
    return (x: Double(point.x), y: Double(self.bounds.height - point.y))
  }
}
