import AppKit
import SwiftUI
import XCTest
@testable import GreekKeyboardCore

final class LocalDraftTextViewTests: XCTestCase {
  func testExternalEditIsUndoneBeforeEarlierTextViewEdit() throws {
    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 240, height: 63))
    textView.allowsUndo = true
    let window = NSWindow(
      contentRect: textView.frame,
      styleMask: [.titled],
      backing: .buffered,
      defer: false
    )
    window.contentView = textView
    window.makeFirstResponder(textView)

    let box = DraftBox()
    let coordinator = makeCoordinator(box: box)
    coordinator.textView = textView
    textView.delegate = coordinator
    let undoManager = try XCTUnwrap(textView.undoManager)
    undoManager.groupsByEvent = false

    undoManager.beginUndoGrouping()
    textView.insertText("a", replacementRange: NSRange(location: 0, length: 0))
    undoManager.endUndoGrouping()

    let externalDraft = DraftTextBuffer(
      text: "aβ",
      selectedRange: NSRange(location: 2, length: 0)
    )
    box.value = externalDraft
    undoManager.beginUndoGrouping()
    coordinator.apply(externalDraft, to: textView)
    undoManager.endUndoGrouping()

    undoManager.undo()

    XCTAssertEqual(textView.string, "a")
    XCTAssertEqual(box.value.text, "a")
  }

  func testExternalSelectionScrollsIntoView() throws {
    let field = LocalDraftFieldView()
    field.frame = NSRect(x: 0, y: 0, width: 240, height: 63)
    let window = NSWindow(
      contentRect: field.frame,
      styleMask: [.titled],
      backing: .buffered,
      defer: false
    )
    window.contentView = field
    field.layoutSubtreeIfNeeded()

    let text = (0..<100).map { "line \($0)" }.joined(separator: "\n")
    let draft = DraftTextBuffer(
      text: text,
      selectedRange: NSRange(location: (text as NSString).length, length: 0)
    )
    let box = DraftBox(value: draft)
    let coordinator = makeCoordinator(box: box)
    coordinator.textView = field.textView

    coordinator.apply(draft, to: field.textView, registersUndo: false)

    let scrollView = try XCTUnwrap(field.textView.enclosingScrollView)
    XCTAssertGreaterThan(scrollView.documentVisibleRect.minY, 0)
  }

  private func makeCoordinator(
    box: DraftBox
  ) -> LocalDraftTextView.Coordinator {
    LocalDraftTextView.Coordinator(
      draft: Binding(
        get: { box.value },
        set: { box.value = $0 }
      )
    )
  }

}

private final class DraftBox {
  var value: DraftTextBuffer

  init(value: DraftTextBuffer = DraftTextBuffer()) {
    self.value = value
  }
}
