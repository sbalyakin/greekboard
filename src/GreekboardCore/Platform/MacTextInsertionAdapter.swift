import AppKit
import ApplicationServices
import Foundation

public enum TextInsertionError: LocalizedError {
  case accessibilityPermissionRequired
  case targetApplicationUnavailable
  case eventCreationFailed
  case insertionFailed

  public var errorDescription: String? {
    switch self {
    case .accessibilityPermissionRequired:
      return L10n.text(
        "insertion.permission",
        value: "Click Allow Typing to grant Accessibility access."
      )
    case .targetApplicationUnavailable:
      return L10n.text(
        "insertion.targetUnavailable",
        value: "The previously active application is no longer available."
      )
    case .eventCreationFailed:
      return L10n.text(
        "insertion.eventFailure",
        value: "macOS could not create a keyboard event."
      )
    case .insertionFailed:
      return L10n.text(
        "insertion.failure",
        value: "The character could not be inserted. You can copy it instead."
      )
    }
  }
}

@MainActor
public final class MacTextInsertionAdapter: TextInsertionServiceProtocol {
  public init() {}

  public func insert(
    _ request: TextInsertionRequest,
    into processIdentifier: pid_t
  ) async throws {
    guard AXIsProcessTrusted() else {
      throw TextInsertionError.accessibilityPermissionRequired
    }
    guard NSRunningApplication(processIdentifier: processIdentifier) != nil else {
      throw TextInsertionError.targetApplicationUnavailable
    }

    switch request {
    case let .text(text):
      try postUnicode(text)
    case let .keyPress(keyCode):
      try postKey(keyCode)
    }
  }

  private func postUnicode(_ text: String) throws {
    guard
      let keyDown = CGEvent(
        keyboardEventSource: nil,
        virtualKey: 0,
        keyDown: true
      ),
      let keyUp = CGEvent(
        keyboardEventSource: nil,
        virtualKey: 0,
        keyDown: false
      )
    else {
      throw TextInsertionError.eventCreationFailed
    }

    let characters = Array(text.utf16)
    characters.withUnsafeBufferPointer { buffer in
      guard let address = buffer.baseAddress else { return }
      keyDown.keyboardSetUnicodeString(
        stringLength: characters.count,
        unicodeString: address
      )
      keyUp.keyboardSetUnicodeString(
        stringLength: characters.count,
        unicodeString: address
      )
    }
    postKeyboardEvents(keyDown, keyUp)
  }

  private func postKey(
    _ keyCode: PhysicalKeyCode
  ) throws {
    guard
      let keyDown = CGEvent(
        keyboardEventSource: nil,
        virtualKey: CGKeyCode(keyCode.rawValue),
        keyDown: true
      ),
      let keyUp = CGEvent(
        keyboardEventSource: nil,
        virtualKey: CGKeyCode(keyCode.rawValue),
        keyDown: false
      )
    else {
      throw TextInsertionError.eventCreationFailed
    }
    postKeyboardEvents(keyDown, keyUp)
  }

  private func postKeyboardEvents(_ keyDown: CGEvent, _ keyUp: CGEvent) {
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
  }
}
