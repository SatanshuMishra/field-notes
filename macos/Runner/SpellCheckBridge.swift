import Cocoa
import FlutterMacOS

private let spellCheckChannelName = "field_notes/spellcheck"
private let spellCheckMethod = "check"
private let maxSpellSuggestions = 5

final class SpellCheckBridge {
  private let channel: FlutterMethodChannel
  private var documentTag: Int?

  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: spellCheckChannelName,
      binaryMessenger: messenger
    )
    self.channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case spellCheckMethod:
      guard let arguments = call.arguments as? [String: Any],
        let text = arguments["text"] as? String
      else {
        result(
          FlutterError(
            code: "bad-arguments",
            message: "check expects a string under \"text\"",
            details: nil
          )
        )
        return
      }
      result(self.check(text))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func spellDocumentTag() -> Int {
    if let tag = self.documentTag {
      return tag
    }
    NSSpellChecker.shared.automaticallyIdentifiesLanguages = true
    let tag = NSSpellChecker.uniqueSpellDocumentTag()
    self.documentTag = tag
    return tag
  }

  private func check(_ text: String) -> [[String: Any]] {
    let checker = NSSpellChecker.shared
    let tag = self.spellDocumentTag()
    let whole = NSRange(location: 0, length: (text as NSString).length)
    let results = checker.check(
      text,
      range: whole,
      types: NSTextCheckingResult.CheckingType.spelling.rawValue,
      options: nil,
      inSpellDocumentWithTag: tag,
      orthography: nil,
      wordCount: nil
    )
    return results
      .filter { $0.resultType == .spelling }
      .map { checked in
        let guesses =
          checker.guesses(
            forWordRange: checked.range,
            in: text,
            language: nil,
            inSpellDocumentWithTag: tag
          ) ?? []
        return [
          "start": checked.range.location,
          "end": checked.range.location + checked.range.length,
          "suggestions": Array(guesses.prefix(maxSpellSuggestions)),
        ]
      }
  }
}
