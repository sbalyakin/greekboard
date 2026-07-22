import Foundation

/// Editable draft text used when Type Into is set to Text Area.
struct DraftTextBuffer: Equatable {
  var text: String
  /// Selection in UTF-16 units (NSString / NSTextView coordinates).
  var selectedRange: NSRange

  init(text: String = "", selectedRange: NSRange = NSRange(location: 0, length: 0)) {
    self.text = text
    self.selectedRange = Self.clamped(selectedRange, in: text as NSString)
  }

  mutating func clear() {
    text = ""
    selectedRange = NSRange(location: 0, length: 0)
  }

  mutating func apply(_ output: KeyOutput) {
    switch output {
    case let .text(string):
      replaceSelection(with: string)
    case let .keyPress(keyCode):
      applyKeyPress(keyCode)
    case .deadKey:
      break
    }
  }

  mutating func replaceSelection(with replacement: String) {
    let nsText = text as NSString
    let range = Self.clamped(selectedRange, in: nsText)
    text = nsText.replacingCharacters(in: range, with: replacement)
    let cursor = range.location + (replacement as NSString).length
    selectedRange = NSRange(location: cursor, length: 0)
  }

  private mutating func applyKeyPress(_ keyCode: PhysicalKeyCode) {
    switch keyCode.rawValue {
    case 51:
      deleteBackward()
    case 36:
      replaceSelection(with: "\n")
    case 48:
      replaceSelection(with: "\t")
    default:
      break
    }
  }

  private mutating func deleteBackward() {
    let nsText = text as NSString
    var range = Self.clamped(selectedRange, in: nsText)
    if range.length == 0 {
      guard range.location > 0 else { return }
      range = nsText.rangeOfComposedCharacterSequence(at: range.location - 1)
    }
    text = nsText.replacingCharacters(in: range, with: "")
    selectedRange = NSRange(location: range.location, length: 0)
  }

  private static func clamped(_ range: NSRange, in text: NSString) -> NSRange {
    let length = text.length
    let location = min(max(range.location, 0), length)
    let maxLength = length - location
    let clampedLength = min(max(range.length, 0), maxLength)
    return NSRange(location: location, length: clampedLength)
  }
}
