import CoreGraphics

enum KeyboardLayoutMetrics {
  static let baseSize = CGSize(width: 804, height: 264)
  static let keyWidth: CGFloat = 48
  static let keyHeight: CGFloat = 46
  static let keyLabelFontSize: CGFloat = 20
  static let horizontalSpacing: CGFloat = 6
  static let verticalSpacing: CGFloat = 7
  static let padding: CGFloat = 3

  static func keysWidth(for row: KeyboardRow) -> CGFloat {
    let keysWidth = row.keys.reduce(CGFloat.zero) { width, key in
      width + keyWidth * key.width
    }
    let gapsWidth = horizontalSpacing * CGFloat(max(row.keys.count - 1, 0))
    return keysWidth + gapsWidth
  }

  static func keysWidth(for layout: KeyboardLayout) -> CGFloat {
    layout.rows.map(keysWidth(for:)).max() ?? 0
  }

  static func contentWidth(for row: KeyboardRow) -> CGFloat {
    keysWidth(for: row) + 2 * padding
  }

  static func contentHeight(rowCount: Int) -> CGFloat {
    let keysHeight = keyHeight * CGFloat(rowCount)
    let gapsHeight = verticalSpacing * CGFloat(max(rowCount - 1, 0))
    return keysHeight + gapsHeight + 2 * padding
  }
}
