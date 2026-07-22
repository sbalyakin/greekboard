import AppKit
import Foundation

public enum GreekboardViewerApplication {
  @MainActor
  public static func run() {
    let application = NSApplication.shared
    let delegate = ApplicationDelegate()
    application.delegate = delegate
    withExtendedLifetime(delegate) {
      application.run()
    }
  }
}

@MainActor
private final class ApplicationDelegate: NSObject, NSApplicationDelegate {
  private var coordinator: AppCoordinator?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let coordinator = AppCoordinator()
    self.coordinator = coordinator
    coordinator.start()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    coordinator?.handleReopen()
    return true
  }
}
