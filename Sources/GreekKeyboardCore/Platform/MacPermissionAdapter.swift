import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
public final class MacPermissionAdapter: PermissionManagingProtocol {
  @Published public private(set) var isAccessibilityGranted = false
  @Published public private(set) var isInputMonitoringGranted = false

  public init() {
    refresh()
  }

  public func refresh() {
    isAccessibilityGranted = AXIsProcessTrusted()
    isInputMonitoringGranted = CGPreflightListenEventAccess()
  }

  public func requestAccessibility() {
    let options = [
      kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
    ] as CFDictionary
    isAccessibilityGranted = AXIsProcessTrustedWithOptions(options)
  }

  public func requestInputMonitoring() {
    isInputMonitoringGranted = CGRequestListenEventAccess()
  }

  public func openAccessibilitySettings() {
    openPrivacySettings(pane: "Privacy_Accessibility")
  }

  public func openInputMonitoringSettings() {
    openPrivacySettings(pane: "Privacy_ListenEvent")
  }

  private func openPrivacySettings(pane: String) {
    guard let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"
    ) else {
      return
    }
    NSWorkspace.shared.open(url)
  }
}
