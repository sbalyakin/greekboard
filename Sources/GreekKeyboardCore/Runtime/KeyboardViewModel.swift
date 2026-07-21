import Combine
import Foundation

@MainActor
public final class KeyboardViewModel: ObservableObject {
  @Published public private(set) var state = KeyboardState()
  @Published public private(set) var insertionErrorMessage: String?
  @Published public private(set) var lastFailedText: String?
  @Published var draft = DraftTextBuffer()

  public let layout: KeyboardLayout

  private let settings: SettingsStore
  private let insertionService: any TextInsertionServiceProtocol
  private let applicationTracker: any ActiveApplicationTrackingProtocol

  public init(
    layout: KeyboardLayout,
    settings: SettingsStore,
    insertionService: any TextInsertionServiceProtocol,
    applicationTracker: any ActiveApplicationTrackingProtocol
  ) {
    self.layout = layout
    self.settings = settings
    self.insertionService = insertionService
    self.applicationTracker = applicationTracker
  }

  public func clearDraft() {
    draft = DraftTextBuffer()
  }

  public func press(_ key: KeyboardKey, clickCount: Int = 1) {
    switch key.kind {
    case let .modifier(modifier):
      press(modifier, clickCount: clickCount)
    case .character, .deadKey, .special:
      guard let output = state.output(for: key) else { return }
      guard let consumedOutput = state.consume(output, in: layout) else { return }
      insert(consumedOutput)
    }
  }

  public func displayText(for key: KeyboardKey) -> String {
    if let composed = state.composedText(for: key, in: layout) {
      return composed
    }

    guard let output = state.output(for: key) else {
      return modifierDisplayText(for: key)
    }
    switch output {
    case let .text(text):
      return text
    case let .deadKey(deadKey):
      return deadKey.spacingCharacter
    case .keyPress:
      return key.latinLabel
    }
  }

  public func isPressed(_ key: KeyboardKey) -> Bool {
    guard let keyCode = key.physicalKeyCode else { return false }
    return state.pressedPhysicalKeys.contains(keyCode)
  }

  public func isActive(_ key: KeyboardKey) -> Bool {
    switch key.kind {
    case let .modifier(modifier):
      switch modifier {
      case .shift:
        return state.modifiers.isShiftEnabled
      case .capsLock:
        return state.modifiers.isCapsLockEnabled
      case .option:
        return state.modifiers.isOptionEnabled
      case .control:
        return state.modifiers.isPhysicalControlPressed
      case .command:
        return state.modifiers.isPhysicalCommandPressed
      }
    case .deadKey:
      guard case let .deadKey(deadKey) = state.output(for: key) else { return false }
      return state.activeDeadKey == deadKey
    case .character, .special:
      return false
    }
  }

  public func isEnabled(_ key: KeyboardKey) -> Bool {
    switch key.kind {
    case let .modifier(modifier):
      return modifier == .shift || modifier == .capsLock || modifier == .option
    case .character:
      guard state.activeDeadKey != nil else { return true }
      return state.composedText(for: key, in: layout) != nil
    case .deadKey, .special:
      return true
    }
  }

  public func copyText(for key: KeyboardKey) -> String? {
    if let composed = state.composedText(for: key, in: layout) {
      return composed
    }

    guard let output = state.output(for: key) else { return nil }
    switch output {
    case let .text(text):
      return text
    case let .deadKey(deadKey):
      return deadKey.spacingCharacter
    case .keyPress:
      return nil
    }
  }

  public func handlePhysicalInput(_ event: PhysicalInputEvent) {
    switch event {
    case let .key(keyCode, isPressed, modifiers):
      state.setPhysicalKey(keyCode, isPressed: isPressed)
      updatePhysicalModifiers(modifiers)
    case let .modifiersChanged(modifiers):
      updatePhysicalModifiers(modifiers)
    case .reset:
      state.resetPhysicalInput()
    }
  }

  public func dismissInsertionError() {
    insertionErrorMessage = nil
    lastFailedText = nil
  }

  private func press(_ modifier: KeyboardModifier, clickCount: Int) {
    switch modifier {
    case .shift:
      state.toggleShift(clickCount: clickCount)
    case .capsLock:
      state.toggleCapsLock()
    case .option:
      state.toggleOption()
    case .control, .command:
      break
    }
  }

  private func updatePhysicalModifiers(_ modifiers: PhysicalModifierState) {
    state.updatePhysicalModifiers(
      shift: modifiers.shift,
      capsLock: modifiers.capsLock,
      option: modifiers.option,
      control: modifiers.control,
      command: modifiers.command
    )
  }

  private func insert(_ output: KeyOutput) {
    guard settings.enableClickToType else {
      var next = draft
      next.apply(output)
      draft = next
      return
    }
    guard let processIdentifier = applicationTracker.targetProcessIdentifier else {
      insertionErrorMessage = L10n.text(
        "insertion.noTarget",
        value: "Select a text field in another application first."
      )
      lastFailedText = text(from: output)
      return
    }

    let request: TextInsertionRequest
    switch output {
    case let .text(text):
      request = .text(text)
    case let .keyPress(keyCode):
      request = .keyPress(keyCode)
    case .deadKey:
      return
    }

    Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        try await insertionService.insert(request, into: processIdentifier)
        insertionErrorMessage = nil
        lastFailedText = nil
      } catch {
        insertionErrorMessage = error.localizedDescription
        lastFailedText = text(from: output)
      }
    }
  }

  private func text(from output: KeyOutput) -> String? {
    guard case let .text(text) = output else { return nil }
    return text
  }

  private func modifierDisplayText(for key: KeyboardKey) -> String {
    switch key.kind {
    case let .modifier(modifier):
      switch modifier {
      case .shift:
        return "⇧"
      case .capsLock:
        return "⇪"
      case .option:
        return "⌥"
      case .control:
        return "⌃"
      case .command:
        return "⌘"
      }
    case .character, .deadKey, .special:
      return key.latinLabel
    }
  }
}
