import AVFoundation
import Cocoa
import FlutterMacOS

private let videoFramesChannelName = "field_notes/video_frames"
private let frameAtMethod = "frameAt"
private let tallestFrameRatio = 4
private let frameJpegQuality = 0.8
private let millisecondsTimescale: CMTimeScale = 1000
private let frameTimeTolerance = CMTime.zero

final class VideoFramesBridge {
  private let channel: FlutterMethodChannel
  private let worker = DispatchQueue(label: "field_notes.video_frames", qos: .userInitiated)

  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: videoFramesChannelName,
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
    guard call.method == frameAtMethod else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String,
      let positionMs = arguments["positionMs"] as? Int,
      let width = arguments["width"] as? Int,
      !path.isEmpty,
      positionMs >= 0,
      width > 0
    else {
      result(
        FlutterError(
          code: "bad_arguments",
          message: "A path, a position and a width are required",
          details: nil
        )
      )
      return
    }
    self.worker.async {
      let jpeg = jpegFrame(path: path, positionMs: positionMs, width: width)
      DispatchQueue.main.async {
        result(jpeg.map { FlutterStandardTypedData(bytes: $0) })
      }
    }
  }
}

private func jpegFrame(path: String, positionMs: Int, width: Int) -> Data? {
  let generator = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: path)))
  generator.appliesPreferredTrackTransform = true
  generator.maximumSize = CGSize(width: width, height: width * tallestFrameRatio)
  generator.requestedTimeToleranceBefore = frameTimeTolerance
  generator.requestedTimeToleranceAfter = frameTimeTolerance
  let time = CMTime(value: CMTimeValue(positionMs), timescale: millisecondsTimescale)
  guard let image = try? generator.copyCGImage(at: time, actualTime: nil) else {
    return nil
  }
  return NSBitmapImageRep(cgImage: image).representation(
    using: .jpeg,
    properties: [.compressionFactor: frameJpegQuality]
  )
}
