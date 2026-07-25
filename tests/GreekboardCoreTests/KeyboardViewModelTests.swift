import Combine
import Foundation
import Testing
@testable import GreekboardCore

@MainActor
@Test("Physical input publishes only changed state")
func physicalInputPublishesOnlyChangedState() {
  let viewModel = makeKeyboardViewModel()
  let modifiers = PhysicalModifierState(
    shift: true,
    capsLock: false,
    option: false,
    control: false,
    command: false
  )
  var publicationCount = 0
  let observation = viewModel.$state.dropFirst().sink { _ in
    publicationCount += 1
  }

  let keyCode = PhysicalKeyCode(rawValue: 0)
  viewModel.handlePhysicalInput(.key(keyCode, isPressed: true, modifiers: modifiers))

  #expect(publicationCount == 1)
  #expect(viewModel.state.pressedPhysicalKeys == [keyCode])
  #expect(viewModel.state.modifiers.isPhysicalShiftPressed)

  viewModel.handlePhysicalInput(.key(keyCode, isPressed: true, modifiers: modifiers))
  viewModel.handlePhysicalInput(.modifiersChanged(modifiers))
  viewModel.handlePhysicalInput(
    .key(PhysicalKeyCode(rawValue: 255), isPressed: true, modifiers: modifiers)
  )

  #expect(publicationCount == 1)
  _ = observation
}

@MainActor
@Test("Physical input reset publishes only when state changes")
func physicalInputResetPublishesOnlyWhenStateChanges() {
  let viewModel = makeKeyboardViewModel()
  let modifiers = PhysicalModifierState(
    shift: false,
    capsLock: false,
    option: false,
    control: false,
    command: false
  )
  var publicationCount = 0
  let observation = viewModel.$state.dropFirst().sink { _ in
    publicationCount += 1
  }

  viewModel.handlePhysicalInput(
    .key(PhysicalKeyCode(rawValue: 0), isPressed: true, modifiers: modifiers)
  )
  viewModel.handlePhysicalInput(.reset)
  viewModel.handlePhysicalInput(.reset)

  #expect(publicationCount == 2)
  #expect(viewModel.state.pressedPhysicalKeys.isEmpty)
  _ = observation
}

@MainActor
@Test("Physical keys do not publish when highlighting is disabled")
func physicalKeysDoNotPublishWhenHighlightingIsDisabled() throws {
  let suiteName = "KeyboardViewModelTests-\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defer { defaults.removePersistentDomain(forName: suiteName) }
  let settings = SettingsStore(defaults: defaults)
  settings.highlightPhysicalKeyPresses = false
  let viewModel = makeKeyboardViewModel(settings: settings)
  let releasedModifiers = PhysicalModifierState(
    shift: false,
    capsLock: false,
    option: false,
    control: false,
    command: false
  )
  var publicationCount = 0
  let observation = viewModel.$state.dropFirst().sink { _ in
    publicationCount += 1
  }

  viewModel.handlePhysicalInput(
    .key(PhysicalKeyCode(rawValue: 0), isPressed: true, modifiers: releasedModifiers)
  )

  #expect(publicationCount == 0)
  #expect(viewModel.state.pressedPhysicalKeys.isEmpty)

  let shiftModifiers = PhysicalModifierState(
    shift: true,
    capsLock: false,
    option: false,
    control: false,
    command: false
  )
  viewModel.handlePhysicalInput(
    .key(PhysicalKeyCode(rawValue: 56), isPressed: true, modifiers: shiftModifiers)
  )

  #expect(publicationCount == 1)
  #expect(viewModel.state.pressedPhysicalKeys.isEmpty)
  #expect(viewModel.state.modifiers.isPhysicalShiftPressed)
  _ = observation
}

@MainActor
@Test("Keyboard presentation uses the supplied state snapshot")
func keyboardPresentationUsesSuppliedStateSnapshot() throws {
  let viewModel = makeKeyboardViewModel()
  let keyCode = PhysicalKeyCode(rawValue: 0)
  let key = try #require(viewModel.layout.key(for: keyCode))
  var snapshot = KeyboardState()
  snapshot.toggleShift()
  snapshot.setPhysicalKey(keyCode, isPressed: true)

  #expect(viewModel.displayText(for: key) == "α")
  #expect(viewModel.displayText(for: key, state: snapshot) == "Α")
  #expect(!viewModel.isPressed(key))
  #expect(viewModel.isPressed(key, state: snapshot))
}

@MainActor
private func makeKeyboardViewModel() -> KeyboardViewModel {
  makeKeyboardViewModel(settings: SettingsStore())
}

@MainActor
private func makeKeyboardViewModel(settings: SettingsStore) -> KeyboardViewModel {
  KeyboardViewModel(
    layout: .greekMonotonic,
    settings: settings,
    insertionService: NoopTextInsertionService(),
    applicationTracker: NoopApplicationTracker()
  )
}

@MainActor
private struct NoopTextInsertionService: TextInsertionServiceProtocol {
  func insert(
    _ request: TextInsertionRequest,
    into processIdentifier: pid_t
  ) async throws {}
}

@MainActor
private final class NoopApplicationTracker: ActiveApplicationTrackingProtocol {
  let targetProcessIdentifier: pid_t? = nil
}
