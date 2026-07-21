import XCTest
@testable import GreekKeyboardCore

final class DraftTextBufferTests: XCTestCase {
  func testInsertTextAtCursor() {
    var draft = DraftTextBuffer(text: "ab", selectedRange: NSRange(location: 1, length: 0))
    draft.apply(.text("X"))
    XCTAssertEqual(draft.text, "aXb")
    XCTAssertEqual(draft.selectedRange, NSRange(location: 2, length: 0))
  }

  func testInsertTextReplacesSelection() {
    var draft = DraftTextBuffer(text: "abcd", selectedRange: NSRange(location: 1, length: 2))
    draft.apply(.text("Z"))
    XCTAssertEqual(draft.text, "aZd")
    XCTAssertEqual(draft.selectedRange, NSRange(location: 2, length: 0))
  }

  func testDeleteBackwardRemovesPreviousCharacter() {
    var draft = DraftTextBuffer(text: "αβ", selectedRange: NSRange(location: 2, length: 0))
    draft.apply(.keyPress(PhysicalKeyCode(rawValue: 51)))
    XCTAssertEqual(draft.text, "α")
    XCTAssertEqual(draft.selectedRange, NSRange(location: 1, length: 0))
  }

  func testDeleteBackwardRemovesSelection() {
    var draft = DraftTextBuffer(text: "abcd", selectedRange: NSRange(location: 1, length: 2))
    draft.apply(.keyPress(PhysicalKeyCode(rawValue: 51)))
    XCTAssertEqual(draft.text, "ad")
    XCTAssertEqual(draft.selectedRange, NSRange(location: 1, length: 0))
  }

  func testReturnInsertsNewline() {
    var draft = DraftTextBuffer(text: "a", selectedRange: NSRange(location: 1, length: 0))
    draft.apply(.keyPress(PhysicalKeyCode(rawValue: 36)))
    XCTAssertEqual(draft.text, "a\n")
  }

  func testTabInsertsTab() {
    var draft = DraftTextBuffer(text: "a", selectedRange: NSRange(location: 1, length: 0))
    draft.apply(.keyPress(PhysicalKeyCode(rawValue: 48)))
    XCTAssertEqual(draft.text, "a\t")
  }

  func testClearResetsBuffer() {
    var draft = DraftTextBuffer(text: "hello", selectedRange: NSRange(location: 2, length: 1))
    draft.clear()
    XCTAssertEqual(draft.text, "")
    XCTAssertEqual(draft.selectedRange, NSRange(location: 0, length: 0))
  }
}
