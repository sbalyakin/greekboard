import CoreGraphics

enum KeyboardWindowMetrics {
  /// Tight around keyboard + outer padding; keeps visible margins small.
  static let baseContentSize = CGSize(width: 810, height: 270)
  /// Status / permissions banner height at scale 1.
  static let statusBannerHeight: CGFloat = 28
  /// Local draft Copy/Clear button height at scale 1 (matches regular macOS push buttons).
  static let localInputButtonHeight: CGFloat = 28
  /// Horizontal gap between draft field and button column at scale 1.
  static let localInputFieldButtonSpacing: CGFloat = 4
  /// Local draft panel height: Copy + gap + Clear.
  static var localInputPanelHeight: CGFloat {
    localInputButtonHeight * 2 + KeyboardLayoutMetrics.verticalSpacing
  }
  /// Gap between local draft panel and top keyboard row at scale 1.
  static let localInputKeyboardGap: CGFloat = 10
  static var localInputChromeHeight: CGFloat {
    localInputPanelHeight + localInputKeyboardGap
  }
  /// Matches the Settings "Keyboard Size" lower bound; keeps keys readable.
  static let minimumScale: CGFloat = 0.75
  static let maximumScale: CGFloat = 1.4

  static var aspectRatio: CGFloat {
    aspectRatio(showsStatusBanner: false, showsLocalInputPanel: false)
  }

  static var minimumContentWidth: CGFloat {
    baseContentSize.width * minimumScale
  }

  static var minimumContentSize: CGSize {
    contentSize(for: minimumScale, showsStatusBanner: false, showsLocalInputPanel: false)
  }

  static func aspectRatio(
    showsStatusBanner: Bool,
    showsLocalInputPanel: Bool = false
  ) -> CGFloat {
    let size = contentSize(
      for: 1,
      showsStatusBanner: showsStatusBanner,
      showsLocalInputPanel: showsLocalInputPanel
    )
    return size.width / size.height
  }

  static func contentSize(
    for scale: CGFloat,
    showsStatusBanner: Bool = false,
    showsLocalInputPanel: Bool = false
  ) -> CGSize {
    let effectiveHeight = baseContentSize.height
      + (showsStatusBanner ? statusBannerHeight : 0)
      + (showsLocalInputPanel ? localInputChromeHeight : 0)
    return CGSize(
      width: baseContentSize.width * scale,
      height: effectiveHeight * scale
    )
  }

  static func clampedScale(_ scale: CGFloat) -> CGFloat {
    min(max(scale, minimumScale), maximumScale)
  }

  static func scale(
    to availableSize: CGSize,
    showsStatusBanner: Bool = false,
    showsLocalInputPanel: Bool = false
  ) -> CGFloat {
    let effectiveHeight = baseContentSize.height
      + (showsStatusBanner ? statusBannerHeight : 0)
      + (showsLocalInputPanel ? localInputChromeHeight : 0)
    return min(
      availableSize.width / baseContentSize.width,
      availableSize.height / effectiveHeight
    )
  }

  static func showsStatusBanner(
    hasInsertionError: Bool,
    clickTarget: ClickTarget,
    isAccessibilityGranted: Bool
  ) -> Bool {
    hasInsertionError
      || (clickTarget.insertsIntoActiveApplication && !isAccessibilityGranted)
  }

  static func showsLocalInputPanel(clickTarget: ClickTarget) -> Bool {
    clickTarget == .textArea
  }
}
