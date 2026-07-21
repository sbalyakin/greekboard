import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
  init(
    settings: SettingsStore,
    permissions: MacPermissionAdapter,
    setLaunchAtLogin: @escaping (Bool) throws -> Void
  ) {
    let view = SettingsView(
      settings: settings,
      permissions: permissions,
      setLaunchAtLogin: setLaunchAtLogin
    )
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Greekboard Settings"
    window.isReleasedWhenClosed = false
    window.contentViewController = NSHostingController(rootView: view)
    window.center()
    super.init(window: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  func show() {
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }

  func setAppearance(_ appearance: KeyboardAppearance) {
    window?.appearance = appearance.appKitAppearance
  }
}
