import AppKit
import CoreGraphics
import Foundation

let usageText = """
usage: inp now
       inp move x y
       inp click x y [count] [mods] [holdMs]
       inp rightclick x y
       inp drag x1 y1 x2 y2 [mods] [pressMs] [hoverMs]
       inp scroll x y dy [dx]
       inp key keycode [mods] [holdMs]
       inp type text
mods is none or a comma list of shift, cmd, opt, ctrl
"""

func fail() -> Never {
    FileHandle.standardError.write(Data((usageText + "\n").utf8))
    exit(2)
}

func number(_ text: String) -> Double {
    guard let value = Double(text), value.isFinite else { fail() }
    return value
}

func whole(_ text: String, minimum: Int = 0) -> Int {
    guard let value = Int(text), value >= minimum else { fail() }
    return value
}

func modifiers(_ text: String) -> CGEventFlags {
    if text.isEmpty || text == "none" {
        return []
    }
    return text.split(separator: ",").reduce(into: CGEventFlags()) { flags, name in
        switch name {
        case "shift": flags.insert(.maskShift)
        case "cmd": flags.insert(.maskCommand)
        case "opt": flags.insert(.maskAlternate)
        case "ctrl": flags.insert(.maskControl)
        default: fail()
        }
    }
}

func uptimeNanos() -> UInt64 {
    clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
}

func pause(_ milliseconds: Int) {
    if milliseconds > 0 {
        usleep(useconds_t(milliseconds * 1000))
    }
}

let source = CGEventSource(stateID: .hidSystemState)

func post(_ event: CGEvent?) {
    guard let event else {
        FileHandle.standardError.write(Data("inp: could not create an event\n".utf8))
        exit(1)
    }
    event.post(tap: .cghidEventTap)
}

func mouse(_ type: CGEventType, _ point: CGPoint, _ button: CGMouseButton, flags: CGEventFlags = [], clickState: Int64 = 1) {
    let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: button)
    event?.flags = flags
    event?.setIntegerValueField(.mouseEventClickState, value: clickState)
    post(event)
}

func keyEvent(code: CGKeyCode, down: Bool, flags: CGEventFlags, unit: UniChar? = nil) -> UInt64 {
    let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
    event?.flags = flags
    if let unit {
        var units: [UniChar] = [unit]
        event?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &units)
    }
    let stamp = uptimeNanos()
    event?.timestamp = CGEventTimestamp(stamp)
    post(event)
    return stamp
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { fail() }
let rest = Array(arguments.dropFirst())

switch command {
case "now":
    guard rest.isEmpty else { fail() }
    print(uptimeNanos())
case "move":
    guard rest.count == 2 else { fail() }
    let point = CGPoint(x: number(rest[0]), y: number(rest[1]))
    mouse(.mouseMoved, point, .left)
case "click":
    guard (2...5).contains(rest.count) else { fail() }
    let point = CGPoint(x: number(rest[0]), y: number(rest[1]))
    let count = rest.count > 2 ? whole(rest[2], minimum: 1) : 1
    guard count <= 3 else { fail() }
    let flags = rest.count > 3 ? modifiers(rest[3]) : []
    let hold = rest.count > 4 ? whole(rest[4]) : 20
    mouse(.mouseMoved, point, .left)
    pause(20)
    for click in 1...count {
        mouse(.leftMouseDown, point, .left, flags: flags, clickState: Int64(click))
        pause(hold)
        mouse(.leftMouseUp, point, .left, flags: flags, clickState: Int64(click))
        if click < count {
            pause(40)
        }
    }
case "rightclick":
    guard rest.count == 2 else { fail() }
    let point = CGPoint(x: number(rest[0]), y: number(rest[1]))
    mouse(.mouseMoved, point, .right)
    pause(20)
    mouse(.rightMouseDown, point, .right)
    pause(20)
    mouse(.rightMouseUp, point, .right)
case "drag":
    guard (4...7).contains(rest.count) else { fail() }
    let start = CGPoint(x: number(rest[0]), y: number(rest[1]))
    let end = CGPoint(x: number(rest[2]), y: number(rest[3]))
    let flags = rest.count > 4 ? modifiers(rest[4]) : []
    let press = rest.count > 5 ? whole(rest[5]) : 60
    let hover = rest.count > 6 ? whole(rest[6]) : 0
    let steps = 24
    mouse(.mouseMoved, start, .left)
    pause(20)
    mouse(.leftMouseDown, start, .left, flags: flags)
    pause(press)
    for step in 1...steps {
        let fraction = Double(step) / Double(steps)
        let point = CGPoint(
            x: start.x + (end.x - start.x) * fraction,
            y: start.y + (end.y - start.y) * fraction
        )
        mouse(.leftMouseDragged, point, .left, flags: flags)
        pause(16)
    }
    pause(hover)
    mouse(.leftMouseUp, end, .left, flags: flags)
case "scroll":
    guard (3...4).contains(rest.count) else { fail() }
    let point = CGPoint(x: number(rest[0]), y: number(rest[1]))
    let dy = Int32(number(rest[2]).rounded())
    let dx = rest.count > 3 ? Int32(number(rest[3]).rounded()) : 0
    mouse(.mouseMoved, point, .left)
    let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0)
    event?.location = point
    post(event)
case "key":
    guard (1...3).contains(rest.count) else { fail() }
    let code = whole(rest[0])
    guard code <= Int(UInt16.max) else { fail() }
    let flags = rest.count > 1 ? modifiers(rest[1]) : []
    let hold = rest.count > 2 ? whole(rest[2]) : 20
    let stamp = keyEvent(code: CGKeyCode(code), down: true, flags: flags)
    print(stamp)
    pause(hold)
    _ = keyEvent(code: CGKeyCode(code), down: false, flags: flags)
case "type":
    guard rest.count == 1, !rest[0].isEmpty else { fail() }
    for unit in rest[0].utf16 {
        let stamp = keyEvent(code: 0, down: true, flags: [], unit: unit)
        print(stamp)
        pause(12)
        _ = keyEvent(code: 0, down: false, flags: [], unit: unit)
        pause(24)
    }
default:
    fail()
}
