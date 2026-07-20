import AppKit
import Combine
import SwiftUI

@MainActor
final class KeyboardWindowController: NSWindowController, NSWindowDelegate {
  var onVisibilityChanged: ((Bool) -> Void)?

  private let viewModel: KeyboardViewModel
  private let settings: SettingsStore
  private let permissions: MacPermissionAdapter
  private var cancellables = Set<AnyCancellable>()

  init(
    viewModel: KeyboardViewModel,
    settings: SettingsStore,
    permissions: MacPermissionAdapter
  ) {
    self.viewModel = viewModel
    self.settings = settings
    self.permissions = permissions

    let initialShowsBanner = KeyboardWindowMetrics.showsStatusBanner(
      hasInsertionError: viewModel.insertionErrorMessage != nil,
      clickToTypeEnabled: settings.enableClickToType,
      isAccessibilityGranted: permissions.isAccessibilityGranted
    )
    let initialContentSize = KeyboardWindowMetrics.contentSize(
      for: 1,
      showsStatusBanner: initialShowsBanner
    )

    let panel = KeyboardPanel(
      contentRect: NSRect(origin: .zero, size: initialContentSize),
      styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .utilityWindow],
      backing: .buffered,
      defer: false
    )
    panel.title = L10n.text("app.name", value: "Greekboard")
    panel.titleVisibility = .visible
    panel.titlebarAppearsTransparent = true
    panel.isMovableByWindowBackground = true
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.becomesKeyOnlyIfNeeded = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.contentAspectRatio = initialContentSize
    panel.contentMinSize = KeyboardWindowMetrics.contentSize(
      for: KeyboardWindowMetrics.minimumScale,
      showsStatusBanner: initialShowsBanner
    )
    panel.setFrameAutosaveName("GreekKeyboardPanelFrame")
    Self.normalizeContentAspectRatio(of: panel, showsStatusBanner: initialShowsBanner)

    let rootView = KeyboardView(
      viewModel: viewModel,
      settings: settings,
      permissions: permissions
    )
    let contentController = NSViewController()
    contentController.view = ResizeCursorHostingView(rootView: rootView)
    panel.contentViewController = contentController

    super.init(window: panel)
    panel.delegate = self
    observeStatusBanner()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  var isVisible: Bool {
    window?.isVisible == true
  }

  func show() {
    window?.orderFrontRegardless()
    onVisibilityChanged?(true)
  }

  func hide() {
    window?.orderOut(nil)
    onVisibilityChanged?(false)
  }

  func setAlwaysOnTop(_ isEnabled: Bool) {
    window?.level = isEnabled ? .floating : .normal
  }

  func setAppearance(_ appearance: KeyboardAppearance) {
    window?.appearance = appearance.appKitAppearance
  }

  func resize(to scale: Double) {
    applyContentSize(
      scale: KeyboardWindowMetrics.clampedScale(CGFloat(scale)),
      animated: true
    )
  }

  func ensureVisibleOnScreen() {
    guard let window else { return }
    let isOnScreen = NSScreen.screens.contains { screen in
      screen.visibleFrame.intersects(window.frame)
    }
    guard !isOnScreen, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
    var frame = window.frame
    frame.origin.x = screen.visibleFrame.midX - frame.width / 2
    frame.origin.y = screen.visibleFrame.midY - frame.height / 2
    window.setFrame(frame, display: true)
  }

  func windowWillClose(_ notification: Notification) {
    onVisibilityChanged?(false)
  }

  func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
    let minFrame = sender.frameRect(
      forContentRect: NSRect(
        origin: .zero,
        size: KeyboardWindowMetrics.contentSize(
          for: KeyboardWindowMetrics.minimumScale,
          showsStatusBanner: showsStatusBanner
        )
      )
    ).size
    return NSSize(
      width: max(frameSize.width, minFrame.width),
      height: max(frameSize.height, minFrame.height)
    )
  }

  private var showsStatusBanner: Bool {
    KeyboardWindowMetrics.showsStatusBanner(
      hasInsertionError: viewModel.insertionErrorMessage != nil,
      clickToTypeEnabled: settings.enableClickToType,
      isAccessibilityGranted: permissions.isAccessibilityGranted
    )
  }

  private func observeStatusBanner() {
    Publishers.CombineLatest3(
      viewModel.$insertionErrorMessage.map { $0 != nil },
      settings.$enableClickToType,
      permissions.$isAccessibilityGranted
    )
    .map { hasError, clickToType, granted in
      KeyboardWindowMetrics.showsStatusBanner(
        hasInsertionError: hasError,
        clickToTypeEnabled: clickToType,
        isAccessibilityGranted: granted
      )
    }
    .removeDuplicates()
    .dropFirst()
    .sink { [weak self] _ in
      self?.applyContentSize(animated: true)
    }
    .store(in: &cancellables)
  }

  private func applyContentSize(scale: CGFloat? = nil, animated: Bool) {
    guard let window else { return }
    let scale = scale ?? currentScale()
    let showsBanner = showsStatusBanner
    let contentSize = KeyboardWindowMetrics.contentSize(
      for: scale,
      showsStatusBanner: showsBanner
    )
    window.contentAspectRatio = contentSize
    window.contentMinSize = KeyboardWindowMetrics.contentSize(
      for: KeyboardWindowMetrics.minimumScale,
      showsStatusBanner: showsBanner
    )
    let frameSize = window.frameRect(
      forContentRect: NSRect(origin: .zero, size: contentSize)
    ).size
    var frame = window.frame
    frame.origin.y += frame.height - frameSize.height
    frame.size = frameSize
    window.setFrame(frame, display: true, animate: animated)
  }

  private func currentScale() -> CGFloat {
    guard let window else { return 1 }
    let contentSize = window.contentRect(forFrameRect: window.frame).size
    return KeyboardWindowMetrics.clampedScale(
      contentSize.width / KeyboardWindowMetrics.baseContentSize.width
    )
  }

  private static func normalizeContentAspectRatio(
    of window: NSWindow,
    showsStatusBanner: Bool
  ) {
    let contentSize = window.contentRect(forFrameRect: window.frame).size
    let scale = max(
      contentSize.width / KeyboardWindowMetrics.baseContentSize.width,
      KeyboardWindowMetrics.minimumScale
    )
    let normalizedContentSize = KeyboardWindowMetrics.contentSize(
      for: scale,
      showsStatusBanner: showsStatusBanner
    )
    let normalizedFrameSize = window.frameRect(
      forContentRect: NSRect(origin: .zero, size: normalizedContentSize)
    ).size
    var frame = window.frame
    frame.origin.y += frame.height - normalizedFrameSize.height
    frame.size = normalizedFrameSize
    window.setFrame(frame, display: false)
  }
}

private final class KeyboardPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

private final class ResizeCursorHostingView<Content: View>: NSHostingView<Content> {
  private let resizeEdgeWidth: CGFloat = 8

  override func resetCursorRects() {
    super.resetCursorRects()

    let edgeWidth = min(resizeEdgeWidth, bounds.width / 2, bounds.height / 2)
    let sideHeight = max(bounds.height - 2 * edgeWidth, 0)

    addCursorRect(
      NSRect(x: 0, y: edgeWidth, width: edgeWidth, height: sideHeight),
      cursor: .resizeLeftRight
    )
    addCursorRect(
      NSRect(
        x: bounds.width - edgeWidth,
        y: edgeWidth,
        width: edgeWidth,
        height: sideHeight
      ),
      cursor: .resizeLeftRight
    )
    addCursorRect(
      NSRect(x: 0, y: 0, width: bounds.width, height: edgeWidth),
      cursor: .resizeUpDown
    )
    addCursorRect(
      NSRect(
        x: 0,
        y: bounds.height - edgeWidth,
        width: bounds.width,
        height: edgeWidth
      ),
      cursor: .resizeUpDown
    )
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    window?.invalidateCursorRects(for: self)
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    window?.invalidateCursorRects(for: self)
  }
}
