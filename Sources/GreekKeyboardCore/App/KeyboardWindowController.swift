import AppKit
import Combine
import SwiftUI

@MainActor
final class KeyboardWindowController: NSWindowController, NSWindowDelegate {
  var onVisibilityChanged: ((Bool) -> Void)?
  var onOpenSettings: (() -> Void)?

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
      clickTarget: settings.clickTarget,
      isAccessibilityGranted: permissions.isAccessibilityGranted
    )
    let initialShowsLocalInput = KeyboardWindowMetrics.showsLocalInputPanel(
      clickTarget: settings.clickTarget
    )
    let initialContentSize = KeyboardWindowMetrics.contentSize(
      for: 1,
      showsStatusBanner: initialShowsBanner,
      showsLocalInputPanel: initialShowsLocalInput
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
    panel.allowsKeyFocus = initialShowsLocalInput
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.contentAspectRatio = initialContentSize
    panel.contentMinSize = KeyboardWindowMetrics.contentSize(
      for: KeyboardWindowMetrics.minimumScale,
      showsStatusBanner: initialShowsBanner,
      showsLocalInputPanel: initialShowsLocalInput
    )
    panel.setFrameAutosaveName("GreekKeyboardPanelFrame")
    Self.normalizeContentAspectRatio(
      of: panel,
      showsStatusBanner: initialShowsBanner,
      showsLocalInputPanel: initialShowsLocalInput
    )

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
    installSettingsButton(on: panel)
    observeWindowChrome()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  var isVisible: Bool {
    window?.isVisible == true
  }

  func show() {
    syncWindowChrome(animated: false)
    window?.orderFrontRegardless()
    onVisibilityChanged?(true)
  }

  func syncWindowChrome(animated: Bool = true) {
    applyWindowChrome(
      WindowChromeState.current(
        viewModel: viewModel,
        settings: settings,
        permissions: permissions
      ),
      animated: animated
    )
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
          showsStatusBanner: showsStatusBanner,
          showsLocalInputPanel: showsLocalInputPanel
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
      clickTarget: settings.clickTarget,
      isAccessibilityGranted: permissions.isAccessibilityGranted
    )
  }

  private var showsLocalInputPanel: Bool {
    KeyboardWindowMetrics.showsLocalInputPanel(clickTarget: settings.clickTarget)
  }

  private func installSettingsButton(on panel: NSPanel) {
    guard let titlebar = panel.standardWindowButton(.closeButton)?.superview else { return }

    let hitSize: CGFloat = 16
    let trailingInset: CGFloat = 10

    let button = HoverHighlightButton(title: "", target: self, action: #selector(openSettings))
    button.isBordered = false
    button.bezelStyle = .inline
    button.setButtonType(.momentaryChange)
    button.attributedTitle = NSAttributedString(
      string: "⋯",
      attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .regular),
        .foregroundColor: NSColor.secondaryLabelColor
      ]
    )
    button.toolTip = "Settings"
    button.setAccessibilityLabel("Settings")
    button.translatesAutoresizingMaskIntoConstraints = false
    titlebar.addSubview(button)
    NSLayoutConstraint.activate([
      button.centerYAnchor.constraint(equalTo: titlebar.centerYAnchor, constant: 1.5),
      button.trailingAnchor.constraint(
        equalTo: titlebar.trailingAnchor,
        constant: -trailingInset
      ),
      button.widthAnchor.constraint(equalToConstant: hitSize),
      button.heightAnchor.constraint(equalToConstant: hitSize)
    ])
  }

  @objc
  private func openSettings() {
    onOpenSettings?()
  }

  private func observeWindowChrome() {
    Publishers.CombineLatest3(
      viewModel.$insertionErrorMessage.map { $0 != nil },
      settings.$clickTarget,
      permissions.$isAccessibilityGranted
    )
    .map(WindowChromeState.init)
    .removeDuplicates()
    .dropFirst()
    // Defer so Settings radio can finish its own binding update first.
    .receive(on: DispatchQueue.main)
    .sink { [weak self] chrome in
      DispatchQueue.main.async {
        self?.applyWindowChrome(chrome, animated: false)
      }
    }
    .store(in: &cancellables)
  }

  private func applyWindowChrome(_ chrome: WindowChromeState, animated: Bool) {
    if let panel = window as? KeyboardPanel {
      panel.allowsKeyFocus = chrome.showsLocalInputPanel
    }
    applyContentSize(
      showsStatusBanner: chrome.showsStatusBanner,
      showsLocalInputPanel: chrome.showsLocalInputPanel,
      animated: animated
    )
  }

  private func applyContentSize(
    scale: CGFloat? = nil,
    showsStatusBanner: Bool? = nil,
    showsLocalInputPanel: Bool? = nil,
    animated: Bool
  ) {
    guard let window else { return }
    let scale = scale ?? currentScale()
    let showsBanner = showsStatusBanner ?? self.showsStatusBanner
    let showsLocal = showsLocalInputPanel ?? self.showsLocalInputPanel
    let contentSize = KeyboardWindowMetrics.contentSize(
      for: scale,
      showsStatusBanner: showsBanner,
      showsLocalInputPanel: showsLocal
    )
    let frameSize = window.frameRect(
      forContentRect: NSRect(origin: .zero, size: contentSize)
    ).size
    var frame = window.frame
    frame.origin.y += frame.height - frameSize.height
    frame.size = frameSize
    // Set frame before aspect ratio so AppKit does not stretch width to the old height.
    window.setFrame(frame, display: true, animate: animated)
    window.contentAspectRatio = contentSize
    window.contentMinSize = KeyboardWindowMetrics.contentSize(
      for: KeyboardWindowMetrics.minimumScale,
      showsStatusBanner: showsBanner,
      showsLocalInputPanel: showsLocal
    )
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
    showsStatusBanner: Bool,
    showsLocalInputPanel: Bool
  ) {
    let contentSize = window.contentRect(forFrameRect: window.frame).size
    let scale = max(
      contentSize.width / KeyboardWindowMetrics.baseContentSize.width,
      KeyboardWindowMetrics.minimumScale
    )
    let normalizedContentSize = KeyboardWindowMetrics.contentSize(
      for: scale,
      showsStatusBanner: showsStatusBanner,
      showsLocalInputPanel: showsLocalInputPanel
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

private struct WindowChromeState: Equatable {
  let showsStatusBanner: Bool
  let showsLocalInputPanel: Bool

  init(hasInsertionError: Bool, clickTarget: ClickTarget, isAccessibilityGranted: Bool) {
    showsStatusBanner = KeyboardWindowMetrics.showsStatusBanner(
      hasInsertionError: hasInsertionError,
      clickTarget: clickTarget,
      isAccessibilityGranted: isAccessibilityGranted
    )
    showsLocalInputPanel = KeyboardWindowMetrics.showsLocalInputPanel(
      clickTarget: clickTarget
    )
  }

  @MainActor
  static func current(
    viewModel: KeyboardViewModel,
    settings: SettingsStore,
    permissions: MacPermissionAdapter
  ) -> WindowChromeState {
    WindowChromeState(
      hasInsertionError: viewModel.insertionErrorMessage != nil,
      clickTarget: settings.clickTarget,
      isAccessibilityGranted: permissions.isAccessibilityGranted
    )
  }
}

private final class KeyboardPanel: NSPanel {
  var allowsKeyFocus = false

  override var canBecomeKey: Bool { allowsKeyFocus }
  override var canBecomeMain: Bool { false }

  /// NSPanel closes on Escape by default; keep the keyboard visible and only resign focus.
  override func cancelOperation(_ sender: Any?) {
    makeFirstResponder(nil)
  }
}

private final class HoverHighlightButton: NSButton {
  private var trackingArea: NSTrackingArea?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configureHoverChrome()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let trackingArea {
      removeTrackingArea(trackingArea)
    }
    let area = NSTrackingArea(
      rect: bounds,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    trackingArea = area
    addTrackingArea(area)
  }

  override func mouseEntered(with event: NSEvent) {
    super.mouseEntered(with: event)
    setHoverHighlighted(true)
  }

  override func mouseExited(with event: NSEvent) {
    super.mouseExited(with: event)
    setHoverHighlighted(false)
  }

  private func configureHoverChrome() {
    wantsLayer = true
    layer?.cornerRadius = 5
    layer?.backgroundColor = .clear
  }

  private func setHoverHighlighted(_ isHighlighted: Bool) {
    let color: NSColor = isHighlighted
      ? NSColor.labelColor.withAlphaComponent(0.1)
      : .clear
    layer?.backgroundColor = color.cgColor
  }
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
