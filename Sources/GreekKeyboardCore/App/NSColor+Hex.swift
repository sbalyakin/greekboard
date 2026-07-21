import AppKit

extension NSColor {
  convenience init(hex: String, opacity: CGFloat = 1) {
    precondition((0...1).contains(opacity), "Opacity must be between 0 and 1")
    guard
      hex.count == 7,
      hex.first == "#",
      let value = UInt32(hex.dropFirst(), radix: 16)
    else {
      preconditionFailure("Hex color must use the #RRGGBB format")
    }

    self.init(
      srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
      green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255,
      alpha: opacity
    )
  }
}
