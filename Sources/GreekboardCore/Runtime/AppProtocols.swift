import Foundation

public enum TextInsertionRequest: Equatable, Sendable {
  case text(String)
  case keyPress(PhysicalKeyCode)
}

@MainActor
public protocol TextInsertionServiceProtocol {
  func insert(_ request: TextInsertionRequest, into processIdentifier: pid_t) async throws
}

@MainActor
public protocol ActiveApplicationTrackingProtocol: AnyObject {
  var targetProcessIdentifier: pid_t? { get }
}

@MainActor
public protocol PermissionManagingProtocol: AnyObject, ObservableObject {
  var isAccessibilityGranted: Bool { get }
  var isInputMonitoringGranted: Bool { get }
  func refresh()
  func requestAccessibility()
  func requestInputMonitoring()
  func openAccessibilitySettings()
  func openInputMonitoringSettings()
}

@MainActor
public protocol LaunchAtLoginServiceProtocol: AnyObject {
  var isEnabled: Bool { get }
  func setEnabled(_ isEnabled: Bool) throws
}

public enum PhysicalInputEvent: Sendable {
  case key(PhysicalKeyCode, isPressed: Bool, modifiers: PhysicalModifierState)
  case modifiersChanged(PhysicalModifierState)
  case reset
}

public struct PhysicalModifierState: Equatable, Sendable {
  public let shift: Bool
  public let capsLock: Bool
  public let option: Bool
  public let control: Bool
  public let command: Bool

  public init(
    shift: Bool,
    capsLock: Bool,
    option: Bool,
    control: Bool,
    command: Bool
  ) {
    self.shift = shift
    self.capsLock = capsLock
    self.option = option
    self.control = control
    self.command = command
  }
}

@MainActor
public protocol KeyboardInputMonitorProtocol: AnyObject {
  var onEvent: ((PhysicalInputEvent) -> Void)? { get set }
  func startLocalMonitoring()
  func setGlobalMonitoringEnabled(_ isEnabled: Bool)
  func stop()
}
