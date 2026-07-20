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
      if insertUsingAccessibility(text, into: processIdentifier) {
        return
      }
      try postUnicode(text, into: processIdentifier)
    case let .keyPress(keyCode):
      try postKey(keyCode, into: processIdentifier)
    }
  }

  private func insertUsingAccessibility(_ text: String, into processIdentifier: pid_t) -> Bool {
    let application = AXUIElementCreateApplication(processIdentifier)
    var focusedValue: CFTypeRef?
    let copyResult = AXUIElementCopyAttributeValue(
      application,
      kAXFocusedUIElementAttribute as CFString,
      &focusedValue
    )
    guard
      copyResult == .success,
      let focusedValue,
      CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
    else {
      return false
    }
    // The Core Foundation type ID check above proves this cast invariant.
    let focusedElement = focusedValue as! AXUIElement
    let setResult = AXUIElementSetAttributeValue(
      focusedElement,
      kAXSelectedTextAttribute as CFString,
      text as CFTypeRef
    )
    return setResult == .success
  }

  private func postUnicode(_ text: String, into processIdentifier: pid_t) throws {
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
    keyDown.postToPid(processIdentifier)
    keyUp.postToPid(processIdentifier)
  }

  private func postKey(
    _ keyCode: PhysicalKeyCode,
    into processIdentifier: pid_t
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
    keyDown.postToPid(processIdentifier)
    keyUp.postToPid(processIdentifier)
  }
}
