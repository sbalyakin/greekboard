import Foundation

public enum VirtualShiftState: Equatable, Sendable {
  case off
  case once
  case locked
}

public struct ModifierState: Equatable, Sendable {
  public var virtualShift: VirtualShiftState = .off
  public var isVirtualOptionEnabled = false
  public var isVirtualCapsLockEnabled = false
  public var isPhysicalShiftPressed = false
  public var isPhysicalCapsLockEnabled = false
  public var isPhysicalOptionPressed = false
  public var isPhysicalControlPressed = false
  public var isPhysicalCommandPressed = false

  public init() {}

  public var isShiftEnabled: Bool {
    virtualShift != .off || isPhysicalShiftPressed
  }

  public var isOptionEnabled: Bool {
    isVirtualOptionEnabled || isPhysicalOptionPressed
  }

  public var isCapsLockEnabled: Bool {
    isVirtualCapsLockEnabled || isPhysicalCapsLockEnabled
  }

  public var usesUppercaseLetters: Bool {
    isCapsLockEnabled != isShiftEnabled
  }
}

public struct KeyboardState: Sendable {
  public private(set) var modifiers = ModifierState()
  public private(set) var activeDeadKey: DeadKey?
  public private(set) var pressedPhysicalKeys = Set<PhysicalKeyCode>()

  public init() {}

  public mutating func toggleShift(clickCount: Int = 1) {
    if clickCount > 1 {
      modifiers.virtualShift = modifiers.virtualShift == .locked ? .off : .locked
      return
    }

    modifiers.virtualShift = modifiers.virtualShift == .off ? .once : .off
  }

  public mutating func toggleOption() {
    modifiers.isVirtualOptionEnabled.toggle()
  }

  public mutating func toggleCapsLock() {
    modifiers.isVirtualCapsLockEnabled.toggle()
  }

  public mutating func updatePhysicalModifiers(
    shift: Bool,
    capsLock: Bool,
    option: Bool,
    control: Bool,
    command: Bool
  ) {
    modifiers.isPhysicalShiftPressed = shift
    modifiers.isPhysicalCapsLockEnabled = capsLock
    modifiers.isPhysicalOptionPressed = option
    modifiers.isPhysicalControlPressed = control
    modifiers.isPhysicalCommandPressed = command
  }

  public mutating func setPhysicalKey(_ keyCode: PhysicalKeyCode, isPressed: Bool) {
    if isPressed {
      pressedPhysicalKeys.insert(keyCode)
    } else {
      pressedPhysicalKeys.remove(keyCode)
    }
  }

  public mutating func resetPhysicalInput() {
    pressedPhysicalKeys.removeAll()
    modifiers.isPhysicalShiftPressed = false
    modifiers.isPhysicalCapsLockEnabled = false
    modifiers.isPhysicalOptionPressed = false
    modifiers.isPhysicalControlPressed = false
    modifiers.isPhysicalCommandPressed = false
  }

  public mutating func cancelDeadKey() {
    activeDeadKey = nil
  }

  public func output(for key: KeyboardKey) -> KeyOutput? {
    switch key.kind {
    case let .character(isLetter):
      return characterOutput(for: key, isLetter: isLetter)
    case .deadKey:
      return modifierSensitiveOutput(for: key, usesShift: modifiers.isShiftEnabled)
    case .modifier:
      return nil
    case .special:
      return key.baseOutput
    }
  }

  public mutating func consume(_ output: KeyOutput, in layout: KeyboardLayout) -> KeyOutput? {
    defer {
      if modifiers.virtualShift == .once {
        modifiers.virtualShift = .off
      }
      if modifiers.isVirtualOptionEnabled {
        modifiers.isVirtualOptionEnabled = false
      }
    }

    switch output {
    case let .deadKey(deadKey):
      if activeDeadKey == deadKey {
        activeDeadKey = nil
        return .text(deadKey.spacingCharacter)
      }
      activeDeadKey = deadKey
      return nil

    case let .text(text):
      guard let deadKey = activeDeadKey else {
        return output
      }
      activeDeadKey = nil
      let composed = layout.deadKeyMappings[deadKey]?[text]
        ?? deadKey.spacingCharacter + text
      return .text(composed)

    case .keyPress:
      activeDeadKey = nil
      return output
    }
  }

  private func characterOutput(for key: KeyboardKey, isLetter: Bool) -> KeyOutput? {
    let usesShift = isLetter ? modifiers.usesUppercaseLetters : modifiers.isShiftEnabled
    return modifierSensitiveOutput(for: key, usesShift: usesShift)
  }

  private func modifierSensitiveOutput(
    for key: KeyboardKey,
    usesShift: Bool
  ) -> KeyOutput? {
    if modifiers.isOptionEnabled {
      let optionOutput = usesShift
        ? key.optionShiftOutput ?? key.optionOutput
        : key.optionOutput
      if let optionOutput {
        return optionOutput
      }
    }
    return usesShift ? key.shiftOutput ?? key.baseOutput : key.baseOutput
  }
}
