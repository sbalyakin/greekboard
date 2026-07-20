import CoreGraphics

enum KeyboardWindowMetrics {
  static let baseContentSize = CGSize(width: 920, height: 340)
  static let minimumContentWidth: CGFloat = 660

  static var aspectRatio: CGFloat {
    baseContentSize.width / baseContentSize.height
  }

  static var minimumContentSize: CGSize {
    contentSize(for: minimumContentWidth / baseContentSize.width)
  }

  static func contentSize(for scale: CGFloat) -> CGSize {
    CGSize(
      width: baseContentSize.width * scale,
      height: baseContentSize.height * scale
    )
  }

  static func scale(to availableSize: CGSize) -> CGFloat {
    min(
      availableSize.width / baseContentSize.width,
      availableSize.height / baseContentSize.height
    )
  }
}
