import AppKit
import CoreGraphics
import Foundation

let usageText = """
usage: drag_files drag fromX fromY toX toY [--hover ms] <path>...
coordinates are global screen points with the origin at the top left
"""

func fail() -> Never {
    FileHandle.standardError.write(Data((usageText + "\n").utf8))
    exit(2)
}

func number(_ text: String) -> Double {
    guard let value = Double(text), value.isFinite else { fail() }
    return value
}

struct Request {
    let from: CGPoint
    let to: CGPoint
    let hoverMilliseconds: Int
    let urls: [URL]
}

func parse(_ arguments: [String]) -> Request {
    guard arguments.count >= 6, arguments[0] == "drag" else { fail() }
    let from = CGPoint(x: number(arguments[1]), y: number(arguments[2]))
    let to = CGPoint(x: number(arguments[3]), y: number(arguments[4]))
    var rest = Array(arguments.dropFirst(5))
    var hover = 400
    if rest.first == "--hover" {
        guard rest.count >= 2, let value = Int(rest[1]), value >= 0 else { fail() }
        hover = value
        rest = Array(rest.dropFirst(2))
    }
    guard !rest.isEmpty else { fail() }
    let urls = rest.map { path -> URL in
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &directory), !directory.boolValue else {
            fail()
        }
        return URL(fileURLWithPath: path).standardizedFileURL
    }
    return Request(from: from, to: to, hoverMilliseconds: hover, urls: urls)
}

let request = parse(Array(CommandLine.arguments.dropFirst()))
let eventSource = CGEventSource(stateID: .hidSystemState)

func postMouse(_ type: CGEventType, _ point: CGPoint) {
    CGEvent(mouseEventSource: eventSource, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?
        .post(tap: .cghidEventTap)
}

func moveAndRelease() {
    let steps = 24
    for step in 1...steps {
        let fraction = Double(step) / Double(steps)
        let point = CGPoint(
            x: request.from.x + (request.to.x - request.from.x) * fraction,
            y: request.from.y + (request.to.y - request.from.y) * fraction
        )
        postMouse(.leftMouseDragged, point)
        usleep(16_000)
    }
    usleep(useconds_t(request.hoverMilliseconds * 1000))
    postMouse(.leftMouseUp, request.to)
}

final class DragView: NSView, NSDraggingSource {
    private var started = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard !started else { return }
        started = true
        let items = request.urls.map { url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            item.setDraggingFrame(bounds, contents: NSWorkspace.shared.icon(forFile: url.path))
            return item
        }
        let session = beginDraggingSession(with: items, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = false
        Thread.detachNewThread {
            moveAndRelease()
        }
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        exit(operation.isEmpty ? 1 : 0)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let screenHeight = NSScreen.screens.first?.frame.height ?? 0
let side: CGFloat = 12
let frame = NSRect(
    x: request.from.x - side / 2,
    y: screenHeight - request.from.y - side / 2,
    width: side,
    height: side
)
let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
window.level = .screenSaver
window.isOpaque = false
window.backgroundColor = NSColor.white.withAlphaComponent(0.01)
window.ignoresMouseEvents = false
window.contentView = DragView(frame: NSRect(origin: .zero, size: frame.size))
window.orderFrontRegardless()
app.activate(ignoringOtherApps: true)

DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
    postMouse(.mouseMoved, request.from)
    usleep(20_000)
    postMouse(.leftMouseDown, request.from)
}

DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10)) {
    postMouse(.leftMouseUp, request.to)
    FileHandle.standardError.write(Data("drag_files: the drag session did not end within 10 s\n".utf8))
    exit(3)
}

app.run()
