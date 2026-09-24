import Cocoa
import FlutterMacOS
import ImageIO

private let imagePasteboardChannelName = "field_notes/pasteboard"
private let pngMime = "image/png"
private let jpegMime = "image/jpeg"
private let convertedLongEdge = 2048
private let jpegPasteboardType = NSPasteboard.PasteboardType("public.jpeg")
private let heicPasteboardType = NSPasteboard.PasteboardType("public.heic")

final class ImagePasteboardBridge {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: imagePasteboardChannelName,
      binaryMessenger: messenger
    )
    self.channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      self.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "contents":
      result(self.contents(of: NSPasteboard.general))
    case "image":
      self.readImage(from: NSPasteboard.general, result: result)
    case "imageFile":
      guard let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String
      else {
        result(
          FlutterError(
            code: "bad-arguments",
            message: "imageFile expects a string under \"path\"",
            details: nil
          )
        )
        return
      }
      let url = URL(fileURLWithPath: path)
      convertOffMain(result: result) {
        CGImageSourceCreateWithURL(url as CFURL, nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func contents(of pasteboard: NSPasteboard) -> [String: Any] {
    let urls =
      pasteboard.readObjects(
        forClasses: [NSURL.self],
        options: [.urlReadingFileURLsOnly: true]
      ) as? [URL] ?? []
    let types = pasteboard.types ?? []
    let named: [(String, NSPasteboard.PasteboardType)] = [
      ("png", .png),
      ("tiff", .tiff),
      ("jpeg", jpegPasteboardType),
      ("heic", heicPasteboardType),
    ]
    return [
      "paths": urls.map { $0.path },
      "imageTypes": named.filter { types.contains($0.1) }.map { $0.0 },
      "hasText": types.contains(.string),
    ]
  }

  private func readImage(from pasteboard: NSPasteboard, result: @escaping FlutterResult) {
    if let png = pasteboard.data(forType: .png) {
      result(imageAnswer(png, mime: pngMime))
      return
    }
    if let jpeg = pasteboard.data(forType: jpegPasteboardType) {
      result(imageAnswer(jpeg, mime: jpegMime))
      return
    }
    guard
      let data = pasteboard.data(forType: .tiff)
        ?? pasteboard.data(forType: heicPasteboardType)
    else {
      result(nil)
      return
    }
    convertOffMain(result: result) {
      CGImageSourceCreateWithData(data as CFData, nil)
    }
  }
}

private func imageAnswer(_ bytes: Data, mime: String) -> [String: Any] {
  return [
    "bytes": FlutterStandardTypedData(bytes: bytes),
    "mime": mime,
  ]
}

private func convertOffMain(
  result: @escaping FlutterResult,
  source: @escaping () -> CGImageSource?
) {
  DispatchQueue.global(qos: .userInitiated).async {
    let answer = source().flatMap(pngBytes).map { imageAnswer($0, mime: pngMime) }
    DispatchQueue.main.async {
      result(answer)
    }
  }
}

private func pngBytes(_ source: CGImageSource) -> Data? {
  let options: [CFString: Any] = [
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceCreateThumbnailWithTransform: true,
    kCGImageSourceThumbnailMaxPixelSize: convertedLongEdge,
  ]
  guard
    let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  else {
    return nil
  }
  return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}
