import AppKit
import Foundation

@MainActor
public final class MacKeyboardInputMonitorAdapter: KeyboardInputMonitorProtocol {
  public var onEvent: ((PhysicalInputEvent) -> Void)?

  private var localMonitor: Any?
  private var globalMonitor: Any?
  private var pressedModifierKeys = Set<PhysicalKeyCode>()

  public init() {}

  deinit {
    if let localMonitor {
      NSEvent.removeMonitor(localMonitor)
    }
    if let globalMonitor {
      NSEvent.removeMonitor(globalMonitor)
    }
  }

  public func startLocalMonitoring() {
    guard localMonitor == nil else { return }
    localMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.keyDown, .keyUp, .flagsChanged]
    ) { [weak self] event in
      MainActor.assumeIsolated {
        self?.process(event)
      }
      return event
    }
  }

  public func setGlobalMonitoringEnabled(_ isEnabled: Bool) {
    if isEnabled {
      startGlobalMonitoring()
    } else if let globalMonitor {
      NSEvent.removeMonitor(globalMonitor)
      self.globalMonitor = nil
      pressedModifierKeys.removeAll()
      onEvent?(.reset)
    }
  }

  public func stop() {
    if let localMonitor {
      NSEvent.removeMonitor(localMonitor)
      self.localMonitor = nil
    }
    if let globalMonitor {
      NSEvent.removeMonitor(globalMonitor)
      self.globalMonitor = nil
    }
    pressedModifierKeys.removeAll()
    onEvent?(.reset)
  }

  private func startGlobalMonitoring() {
    guard globalMonitor == nil else { return }
    globalMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.keyDown, .keyUp, .flagsChanged]
    ) { [weak self] event in
      MainActor.assumeIsolated {
        self?.process(event)
      }
    }
  }

  private func process(_ event: NSEvent) {
    let keyCode = PhysicalKeyCode(rawValue: event.keyCode)
    let modifiers = physicalModifiers(from: event.modifierFlags)

    switch event.type {
    case .keyDown:
      onEvent?(.key(keyCode, isPressed: true, modifiers: modifiers))
    case .keyUp:
      onEvent?(.key(keyCode, isPressed: false, modifiers: modifiers))
    case .flagsChanged:
      let isPressed = modifierIsPressed(keyCode, flags: event.modifierFlags)
      onEvent?(.key(keyCode, isPressed: isPressed, modifiers: modifiers))
      onEvent?(.modifiersChanged(modifiers))
    default:
      break
    }
  }

  private func modifierIsPressed(
    _ keyCode: PhysicalKeyCode,
    flags: NSEvent.ModifierFlags
  ) -> Bool {
    if keyCode.rawValue == 57 {
      return flags.contains(.capsLock)
    }
    if pressedModifierKeys.remove(keyCode) != nil {
      return false
    }
    guard flag(for: keyCode).map(flags.contains) == true else { return false }
    pressedModifierKeys.insert(keyCode)
    return true
  }

  private func flag(for keyCode: PhysicalKeyCode) -> NSEvent.ModifierFlags? {
    switch keyCode.rawValue {
    case 56, 60:
      return .shift
    case 57:
      return .capsLock
    case 58, 61:
      return .option
    case 59, 62:
      return .control
    case 54, 55:
      return .command
    default:
      return nil
    }
  }

  private func physicalModifiers(
    from flags: NSEvent.ModifierFlags
  ) -> PhysicalModifierState {
    PhysicalModifierState(
      shift: flags.contains(.shift),
      capsLock: flags.contains(.capsLock),
      option: flags.contains(.option),
      control: flags.contains(.control),
      command: flags.contains(.command)
    )
  }
}
