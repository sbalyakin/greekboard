import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
public final class MacPermissionAdapter: PermissionManagingProtocol {
  @Published public private(set) var isAccessibilityGranted = false
  @Published public private(set) var isInputMonitoringGranted = false

  private var pollTimer: Timer?
  private var waitingForAccessibility = false
  private var waitingForInputMonitoring = false
  private var isRelaunching = false
  private var systemSettingsWasFrontmost = false
  private var didInstallObservers = false

  public init() {
    refresh()
  }

  deinit {
    pollTimer?.invalidate()
  }

  public func refresh() {
    applyPermissionState(
      accessibility: AXIsProcessTrusted(),
      inputMonitoring: CGPreflightListenEventAccess()
    )
  }

  public func requestAccessibility() {
    let options = [
      kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
    ] as CFDictionary
    // Prompt is asynchronous; usually still false until the user grants in Settings.
    let accessibility = AXIsProcessTrustedWithOptions(options)
    waitingForAccessibility = true
    installObserversIfNeeded()
    applyPermissionState(
      accessibility: accessibility,
      inputMonitoring: isInputMonitoringGranted
    )
  }

  public func requestInputMonitoring() {
    let inputMonitoring = CGRequestListenEventAccess()
    waitingForInputMonitoring = true
    installObserversIfNeeded()
    applyPermissionState(
      accessibility: isAccessibilityGranted,
      inputMonitoring: inputMonitoring
    )
  }

  public func openAccessibilitySettings() {
    waitingForAccessibility = true
    installObserversIfNeeded()
    openPrivacySettings(pane: "Privacy_Accessibility")
    updatePolling()
  }

  public func openInputMonitoringSettings() {
    waitingForInputMonitoring = true
    installObserversIfNeeded()
    openPrivacySettings(pane: "Privacy_ListenEvent")
    updatePolling()
  }

  private func applyPermissionState(accessibility: Bool, inputMonitoring: Bool) {
    if isAccessibilityGranted != accessibility {
      isAccessibilityGranted = accessibility
    }
    if isInputMonitoringGranted != inputMonitoring {
      isInputMonitoringGranted = inputMonitoring
    }
    if accessibility {
      waitingForAccessibility = false
    }
    if inputMonitoring {
      waitingForInputMonitoring = false
    }
    updatePolling()
  }

  private func openPrivacySettings(pane: String) {
    guard let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"
    ) else {
      return
    }
    NSWorkspace.shared.open(url)
  }

  private func updatePolling() {
    let needsPolling = waitingForAccessibility || waitingForInputMonitoring
    if needsPolling {
      startPollingIfNeeded()
    } else {
      stopPolling()
    }
  }

  private func startPollingIfNeeded() {
    guard pollTimer == nil else { return }
    pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.handlePollTick()
      }
    }
  }

  private func stopPolling() {
    pollTimer?.invalidate()
    pollTimer = nil
  }

  private func handlePollTick() {
    refresh()
  }

  private var isWaitingForPermission: Bool {
    waitingForAccessibility || waitingForInputMonitoring
  }

  private func installObserversIfNeeded() {
    guard !didInstallObservers else { return }
    didInstallObservers = true

    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(accessibilityTrustedStateDidChange),
      name: Notification.Name("com.apple.accessibility.api"),
      object: nil,
      suspensionBehavior: .deliverImmediately
    )

    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(frontmostApplicationDidChange),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil
    )
  }

  @objc
  private func accessibilityTrustedStateDidChange(_ notification: Notification) {
    // Delivered when Accessibility TCC changes; process trust cache may stay stale.
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(250))
      refresh()
      if waitingForAccessibility && !isAccessibilityGranted {
        relaunchToApplyPermissions()
      }
    }
  }

  @objc
  private func frontmostApplicationDidChange(_ notification: Notification) {
    let settingsFrontmost = isSystemSettingsFrontmost()
    let leftSettings = systemSettingsWasFrontmost && !settingsFrontmost
    systemSettingsWasFrontmost = settingsFrontmost
    guard leftSettings, isWaitingForPermission else { return }
    refresh()
    if isWaitingForPermission {
      relaunchToApplyPermissions()
    }
  }

  private func isSystemSettingsFrontmost() -> Bool {
    guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
      return false
    }
    return Self.systemSettingsBundleIDs.contains(bundleID)
  }

  private func relaunchToApplyPermissions() {
    guard !isRelaunching else { return }
    isRelaunching = true
    stopPolling()

    let appPath = Bundle.main.bundlePath
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = [
      "-c",
      "sleep 0.4; exec /usr/bin/open \"$1\"",
      "--",
      appPath
    ]
    try? process.run()
    NSApp.terminate(nil)
  }

  private static let systemSettingsBundleIDs: Set<String> = [
    "com.apple.systempreferences",
    "com.apple.SystemPreferences",
    "com.apple.Preferences",
    "com.apple.AccessibilitySettings"
  ]
}
