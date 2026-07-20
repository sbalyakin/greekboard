import AppKit
import SwiftUI

@MainActor
final class KeyboardWindowController: NSWindowController, NSWindowDelegate {
  var onVisibilityChanged: ((Bool) -> Void)?

  init(
    viewModel: KeyboardViewModel,
    settings: SettingsStore,
    permissions: MacPermissionAdapter
  ) {
    let panel = KeyboardPanel(
      contentRect: NSRect(x: 0, y: 0, width: 920, height: 340),
      styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .utilityWindow],
      backing: .buffered,
      defer: false
    )
    panel.title = L10n.text("app.name", value: "Greekboard")
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isMovableByWindowBackground = true
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.becomesKeyOnlyIfNeeded = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.minSize = NSSize(width: 660, height: 250)
    panel.setFrameAutosaveName("GreekKeyboardPanelFrame")

    let rootView = KeyboardView(
      viewModel: viewModel,
      settings: settings,
      permissions: permissions
    )
    panel.contentViewController = NSHostingController(rootView: rootView)

    super.init(window: panel)
    panel.delegate = self
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
    guard let window else { return }
    let newSize = NSSize(width: 920 * scale, height: 340 * scale)
    var frame = window.frame
    frame.origin.y += frame.height - newSize.height
    frame.size = newSize
    window.setFrame(frame, display: true, animate: true)
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
}

private final class KeyboardPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}
