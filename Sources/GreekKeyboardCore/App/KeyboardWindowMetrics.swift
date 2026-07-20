import CoreGraphics

enum KeyboardWindowMetrics {
  static let baseContentSize = CGSize(width: 920, height: 340)
  /// Matches the Settings "Keyboard Size" lower bound; keeps keys readable.
  static let minimumScale: CGFloat = 0.75
  static let maximumScale: CGFloat = 1.4

  static var aspectRatio: CGFloat {
    baseContentSize.width / baseContentSize.height
  }

  static var minimumContentWidth: CGFloat {
    baseContentSize.width * minimumScale
  }

  static var minimumContentSize: CGSize {
    contentSize(for: minimumScale)
  }

  static func contentSize(for scale: CGFloat) -> CGSize {
    CGSize(
      width: baseContentSize.width * scale,
      height: baseContentSize.height * scale
    )
  }

  static func clampedScale(_ scale: CGFloat) -> CGFloat {
    min(max(scale, minimumScale), maximumScale)
  }

  static func scale(to availableSize: CGSize) -> CGFloat {
    min(
      availableSize.width / baseContentSize.width,
      availableSize.height / baseContentSize.height
    )
  }
}
