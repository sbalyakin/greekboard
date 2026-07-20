import CoreGraphics

enum KeyboardLayoutMetrics {
  static let baseSize = CGSize(width: 820, height: 280)
  static let keyWidth: CGFloat = 48
  static let keyHeight: CGFloat = 46
  static let horizontalSpacing: CGFloat = 6
  static let verticalSpacing: CGFloat = 7
  static let padding: CGFloat = 10

  static func contentWidth(for row: KeyboardRow) -> CGFloat {
    let keysWidth = row.keys.reduce(CGFloat.zero) { width, key in
      width + keyWidth * key.width
    }
    let gapsWidth = horizontalSpacing * CGFloat(max(row.keys.count - 1, 0))
    return keysWidth + gapsWidth + 2 * padding
  }

  static func contentHeight(rowCount: Int) -> CGFloat {
    let keysHeight = keyHeight * CGFloat(rowCount)
    let gapsHeight = verticalSpacing * CGFloat(max(rowCount - 1, 0))
    return keysHeight + gapsHeight + 2 * padding
  }
}
