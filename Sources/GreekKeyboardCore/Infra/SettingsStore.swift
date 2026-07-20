import AppKit
import Combine
import Foundation

public enum KeyboardAppearance: String, CaseIterable, Identifiable, Sendable {
  case system
  case light
  case dark

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .system:
      return L10n.text("appearance.system", value: "System")
    case .light:
      return L10n.text("appearance.light", value: "Light")
    case .dark:
      return L10n.text("appearance.dark", value: "Dark")
    }
  }

  var appKitAppearance: NSAppearance? {
    switch self {
    case .system:
      return nil
    case .light:
      return NSAppearance(named: .aqua)
    case .dark:
      return NSAppearance(named: .darkAqua)
    }
  }
}

@MainActor
public final class SettingsStore: ObservableObject {
  @Published public var launchAtLoginErrorMessage: String?
  @Published public var launchAtLogin = false {
    didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
  }
  @Published public var showKeyboardOnLaunch = true {
    didSet { defaults.set(showKeyboardOnLaunch, forKey: Key.showKeyboardOnLaunch) }
  }
  @Published public var alwaysOnTop = true {
    didSet { defaults.set(alwaysOnTop, forKey: Key.alwaysOnTop) }
  }
  @Published public var hideDockIcon = true {
    didSet { defaults.set(hideDockIcon, forKey: Key.hideDockIcon) }
  }
  @Published public var showLatinKeyLabels = true {
    didSet { defaults.set(showLatinKeyLabels, forKey: Key.showLatinKeyLabels) }
  }
  @Published public var highlightPhysicalKeyPresses = true {
    didSet {
      defaults.set(highlightPhysicalKeyPresses, forKey: Key.highlightPhysicalKeyPresses)
    }
  }
  @Published public var enableClickToType = true {
    didSet { defaults.set(enableClickToType, forKey: Key.enableClickToType) }
  }
  @Published public var keyLabelScale = 1.0 {
    didSet { defaults.set(keyLabelScale, forKey: Key.keyLabelScale) }
  }
  @Published public var appearance = KeyboardAppearance.system {
    didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
  }
  @Published public var keyboardScale = 1.0 {
    didSet { defaults.set(keyboardScale, forKey: Key.keyboardScale) }
  }
  @Published public var keyCornerRadius = 8.0 {
    didSet { defaults.set(keyCornerRadius, forKey: Key.keyCornerRadius) }
  }
  @Published public var keyPressAnimation = true {
    didSet { defaults.set(keyPressAnimation, forKey: Key.keyPressAnimation) }
  }

  public let keyboardLayoutIdentifier = "greek-monotonic"

  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
    showKeyboardOnLaunch = defaults.object(forKey: Key.showKeyboardOnLaunch) as? Bool ?? true
    alwaysOnTop = defaults.object(forKey: Key.alwaysOnTop) as? Bool ?? true
    hideDockIcon = defaults.object(forKey: Key.hideDockIcon) as? Bool ?? true
    showLatinKeyLabels = defaults.object(forKey: Key.showLatinKeyLabels) as? Bool ?? true
    highlightPhysicalKeyPresses =
      defaults.object(forKey: Key.highlightPhysicalKeyPresses) as? Bool ?? true
    enableClickToType = defaults.object(forKey: Key.enableClickToType) as? Bool ?? true
    keyLabelScale = defaults.object(forKey: Key.keyLabelScale) as? Double ?? 1
    appearance = KeyboardAppearance(
      rawValue: defaults.string(forKey: Key.appearance) ?? "system"
    ) ?? .system
    keyboardScale = defaults.object(forKey: Key.keyboardScale) as? Double ?? 1
    keyCornerRadius = defaults.object(forKey: Key.keyCornerRadius) as? Double ?? 8
    keyPressAnimation = defaults.object(forKey: Key.keyPressAnimation) as? Bool ?? true
  }

  public var wasKeyboardVisible: Bool {
    defaults.object(forKey: Key.keyboardVisible) as? Bool ?? true
  }

  public func setKeyboardVisible(_ isVisible: Bool) {
    defaults.set(isVisible, forKey: Key.keyboardVisible)
  }
}

private extension SettingsStore {
  enum Key {
    static let launchAtLogin = "settings.launchAtLogin"
    static let showKeyboardOnLaunch = "settings.showKeyboardOnLaunch"
    static let alwaysOnTop = "settings.alwaysOnTop"
    static let hideDockIcon = "settings.hideDockIcon"
    static let showLatinKeyLabels = "settings.showLatinKeyLabels"
    static let highlightPhysicalKeyPresses = "settings.highlightPhysicalKeyPresses"
    static let enableClickToType = "settings.enableClickToType"
    static let keyLabelScale = "settings.keyLabelScale"
    static let appearance = "settings.appearance"
    static let keyboardScale = "settings.keyboardScale"
    static let keyCornerRadius = "settings.keyCornerRadius"
    static let keyPressAnimation = "settings.keyPressAnimation"
    static let keyboardVisible = "state.keyboardVisible"
  }
}
