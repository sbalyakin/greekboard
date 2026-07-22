import AppKit
import Foundation

@MainActor
public final class MacActiveApplicationAdapter: ActiveApplicationTrackingProtocol {
  public private(set) var targetProcessIdentifier: pid_t?

  private let ownProcessIdentifier: pid_t

  public init(workspace: NSWorkspace = .shared) {
    ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
    let frontmost = workspace.frontmostApplication
    if frontmost?.processIdentifier != ownProcessIdentifier {
      targetProcessIdentifier = frontmost?.processIdentifier
    }
    workspace.notificationCenter.addObserver(
      self,
      selector: #selector(applicationDidActivate(_:)),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil
    )
  }

  deinit {
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  @objc
  private func applicationDidActivate(_ notification: Notification) {
    guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
      as? NSRunningApplication,
      application.processIdentifier != ownProcessIdentifier
    else {
      return
    }
    targetProcessIdentifier = application.processIdentifier
  }
}
