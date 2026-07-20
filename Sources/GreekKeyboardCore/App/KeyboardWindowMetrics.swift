import CoreGraphics

enum KeyboardWindowMetrics {
  /// Tight around keyboard + outer padding; keeps visible margins small.
  static let baseContentSize = CGSize(width: 810, height: 270)
  /// Status / permissions banner height at scale 1.
  static let statusBannerHeight: CGFloat = 28
  /// Matches the Settings "Keyboard Size" lower bound; keeps keys readable.
  static let minimumScale: CGFloat = 0.75
  static let maximumScale: CGFloat = 1.4

  static var aspectRatio: CGFloat {
    aspectRatio(showsStatusBanner: false)
  }

  static var minimumContentWidth: CGFloat {
    baseContentSize.width * minimumScale
  }

  static var minimumContentSize: CGSize {
    contentSize(for: minimumScale, showsStatusBanner: false)
  }

  static func aspectRatio(showsStatusBanner: Bool) -> CGFloat {
    let size = contentSize(for: 1, showsStatusBanner: showsStatusBanner)
    return size.width / size.height
  }

  static func contentSize(for scale: CGFloat, showsStatusBanner: Bool = false) -> CGSize {
    let effectiveHeight = baseContentSize.height
      + (showsStatusBanner ? statusBannerHeight : 0)
    return CGSize(
      width: baseContentSize.width * scale,
      height: effectiveHeight * scale
    )
  }

  static func clampedScale(_ scale: CGFloat) -> CGFloat {
    min(max(scale, minimumScale), maximumScale)
  }

  static func scale(to availableSize: CGSize, showsStatusBanner: Bool = false) -> CGFloat {
    let effectiveHeight = baseContentSize.height
      + (showsStatusBanner ? statusBannerHeight : 0)
    return min(
      availableSize.width / baseContentSize.width,
      availableSize.height / effectiveHeight
    )
  }

  static func showsStatusBanner(
    hasInsertionError: Bool,
    clickToTypeEnabled: Bool,
    isAccessibilityGranted: Bool
  ) -> Bool {
    hasInsertionError || (clickToTypeEnabled && !isAccessibilityGranted)
  }
}
