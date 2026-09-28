import AppKit
import Foundation

let usageText = """
usage: pasteboard image <file> <png|tiff|jpeg|heic>
       pasteboard files <path>...
       pasteboard mixed <text> <path>...
       pasteboard text <string>
       pasteboard clear
"""

func fail() -> Never {
    FileHandle.standardError.write(Data((usageText + "\n").utf8))
    exit(2)
}

func existingFiles(_ paths: [String]) -> [NSURL] {
    guard !paths.isEmpty else { fail() }
    return paths.map { path in
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &directory), !directory.boolValue else {
            fail()
        }
        return NSURL(fileURLWithPath: path).absoluteURL! as NSURL
    }
}

func imageType(_ name: String) -> NSPasteboard.PasteboardType {
    switch name {
    case "png": return .png
    case "tiff": return .tiff
    case "jpeg": return NSPasteboard.PasteboardType("public.jpeg")
    case "heic": return NSPasteboard.PasteboardType("public.heic")
    default: fail()
    }
}

func finish(_ written: Bool) -> Never {
    guard written else {
        FileHandle.standardError.write(Data("pasteboard: the write was refused\n".utf8))
        exit(1)
    }
    exit(0)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { fail() }
let rest = Array(arguments.dropFirst())
let board = NSPasteboard.general

switch command {
case "image":
    guard rest.count == 2 else { fail() }
    let type = imageType(rest[1])
    let file = existingFiles([rest[0]])[0]
    guard let data = try? Data(contentsOf: file as URL), !data.isEmpty else { fail() }
    board.clearContents()
    finish(board.setData(data, forType: type))
case "files":
    let urls = existingFiles(rest)
    board.clearContents()
    finish(board.writeObjects(urls))
case "mixed":
    guard rest.count >= 2 else { fail() }
    let urls = existingFiles(Array(rest.dropFirst()))
    board.clearContents()
    let objects: [NSPasteboardWriting] = urls + [rest[0] as NSString]
    finish(board.writeObjects(objects))
case "text":
    guard rest.count == 1 else { fail() }
    board.clearContents()
    finish(board.setString(rest[0], forType: .string))
case "clear":
    guard rest.isEmpty else { fail() }
    board.clearContents()
    exit(0)
default:
    fail()
}
