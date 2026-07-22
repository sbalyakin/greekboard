import XCTest
@testable import GreekboardCore

final class KeyboardStateTests: XCTestCase {
  private let layout = KeyboardLayout.greekMonotonic

  func testBaseAndShiftOutput() throws {
    var state = KeyboardState()
    let alpha = try XCTUnwrap(layout.key(for: PhysicalKeyCode(rawValue: 0)))

    XCTAssertEqual(state.output(for: alpha), .text("α"))
    state.toggleShift()
    XCTAssertEqual(state.output(for: alpha), .text("Α"))
  }

  func testCapsLockAndShiftUseExclusiveOr() throws {
    var state = KeyboardState()
    let alpha = try XCTUnwrap(layout.key(for: PhysicalKeyCode(rawValue: 0)))

    state.toggleCapsLock()
    XCTAssertEqual(state.output(for: alpha), .text("Α"))
    state.toggleShift()
    XCTAssertEqual(state.output(for: alpha), .text("α"))
  }

  func testVirtualCapsLockSurvivesPhysicalModifierUpdates() throws {
    var state = KeyboardState()
    let alpha = try XCTUnwrap(layout.key(for: PhysicalKeyCode(rawValue: 0)))

    state.toggleCapsLock()
    state.updatePhysicalModifiers(
      shift: false,
      capsLock: false,
      option: false,
      control: false,
      command: false
    )

    XCTAssertEqual(state.output(for: alpha), .text("Α"))
  }

  func testCapsLockDoesNotShiftPunctuation() throws {
    var state = KeyboardState()
    let questionMark = try XCTUnwrap(layout.key(for: PhysicalKeyCode(rawValue: 12)))

    state.toggleCapsLock()

    XCTAssertEqual(state.output(for: questionMark), .text(";"))
  }

  func testOneShotShiftIsConsumedAfterText() throws {
    var state = KeyboardState()
    let alpha = try XCTUnwrap(layout.key(for: PhysicalKeyCode(rawValue: 0)))
    state.toggleShift()

    let output = try XCTUnwrap(state.output(for: alpha))
    XCTAssertEqual(state.consume(output, in: layout), .text("Α"))
    XCTAssertEqual(state.modifiers.virtualShift, .off)
  }

  func testDoubleClickLocksShift() throws {
    var state = KeyboardState()
    let alpha = try XCTUnwrap(layout.key(for: PhysicalKeyCode(rawValue: 0)))

    state.toggleShift(clickCount: 2)
    XCTAssertEqual(state.modifiers.virtualShift, .locked)
    _ = state.consume(try XCTUnwrap(state.output(for: alpha)), in: layout)
    XCTAssertEqual(state.modifiers.virtualShift, .locked)
  }

  func testAcuteDeadKeyComposesWithVowel() throws {
    var state = KeyboardState()
    let acute = try XCTUnwrap(layout.key(for: PhysicalKeyCode(rawValue: 41)))
    let alpha = try XCTUnwrap(layout.key(for: PhysicalKeyCode(rawValue: 0)))

    XCTAssertNil(state.consume(try XCTUnwrap(state.output(for: acute)), in: layout))
    XCTAssertEqual(state.activeDeadKey, .acute)
    XCTAssertEqual(
      state.consume(try XCTUnwrap(state.output(for: alpha)), in: layout),
      .text("ά")
    )
    XCTAssertNil(state.activeDeadKey)
  }

  func testDeadKeyAndIncompatibleCharacterInsertNothing() throws {
    var state = KeyboardState()
    let acute = try XCTUnwrap(layout.key(for: PhysicalKeyCode(rawValue: 41)))
    let beta = try XCTUnwrap(layout.key(for: PhysicalKeyCode(rawValue: 11)))
    let alpha = try XCTUnwrap(layout.key(for: PhysicalKeyCode(rawValue: 0)))

    _ = state.consume(try XCTUnwrap(state.output(for: acute)), in: layout)
    XCTAssertNil(state.consume(try XCTUnwrap(state.output(for: beta)), in: layout))
    XCTAssertEqual(state.activeDeadKey, .acute)
    XCTAssertEqual(state.composedText(for: alpha, in: layout), "ά")
    XCTAssertNil(state.composedText(for: beta, in: layout))
    XCTAssertEqual(
      state.consume(try XCTUnwrap(state.output(for: alpha)), in: layout),
      .text("ά")
    )
  }

  func testDiaeresisAndCombinedAccentMappings() throws {
    var state = KeyboardState()
    let deadKey = try XCTUnwrap(layout.key(for: PhysicalKeyCode(rawValue: 41)))
    let iota = try XCTUnwrap(layout.key(for: PhysicalKeyCode(rawValue: 34)))

    state.toggleShift()
    _ = state.consume(try XCTUnwrap(state.output(for: deadKey)), in: layout)
    XCTAssertEqual(
      state.consume(try XCTUnwrap(state.output(for: iota)), in: layout),
      .text("ϊ")
    )

    state.toggleOption()
    _ = state.consume(try XCTUnwrap(state.output(for: deadKey)), in: layout)
    XCTAssertEqual(
      state.consume(try XCTUnwrap(state.output(for: iota)), in: layout),
      .text("ΐ")
    )
  }

  func testOptionFallsBackToBaseAndIsConsumed() throws {
    var state = KeyboardState()
    let alpha = try XCTUnwrap(layout.key(for: PhysicalKeyCode(rawValue: 0)))

    state.toggleOption()
    let output = try XCTUnwrap(state.output(for: alpha))

    XCTAssertEqual(state.consume(output, in: layout), .text("α"))
    XCTAssertFalse(state.modifiers.isOptionEnabled)
  }

  func testResetPhysicalInputPreservesVirtualModifiers() {
    var state = KeyboardState()
    state.toggleCapsLock()
    state.setPhysicalKey(PhysicalKeyCode(rawValue: 0), isPressed: true)
    state.updatePhysicalModifiers(
      shift: true,
      capsLock: true,
      option: true,
      control: true,
      command: true
    )

    state.resetPhysicalInput()

    XCTAssertTrue(state.pressedPhysicalKeys.isEmpty)
    XCTAssertTrue(state.modifiers.isCapsLockEnabled)
    XCTAssertFalse(state.modifiers.isPhysicalShiftPressed)
    XCTAssertFalse(state.modifiers.isPhysicalOptionPressed)
    XCTAssertFalse(state.modifiers.isPhysicalControlPressed)
    XCTAssertFalse(state.modifiers.isPhysicalCommandPressed)
  }

  func testLayoutContainsRequiredGreekSymbols() {
    let outputs = layout.keys.flatMap { key in
      [key.baseOutput, key.shiftOutput, key.optionOutput, key.optionShiftOutput]
    }
    let text = outputs.compactMap { output -> String? in
      guard case let .text(value) = output else { return nil }
      return value
    }.joined()

    for required in ["ς", "σ", ";", "·"] {
      XCTAssertTrue(text.contains(required), "Missing required symbol: \(required)")
    }
  }

  func testKeyboardRowsMatchScalingReferenceWidth() {
    for row in layout.rows {
      XCTAssertEqual(
        KeyboardLayoutMetrics.contentWidth(for: row),
        KeyboardLayoutMetrics.baseSize.width,
        accuracy: 0.000_001,
        "Row \(row.id) must match the scaling reference width"
      )
    }
    XCTAssertLessThanOrEqual(
      KeyboardLayoutMetrics.contentHeight(rowCount: layout.rows.count),
      KeyboardLayoutMetrics.baseSize.height
    )
  }

  func testKeyboardWindowSizesPreserveAspectRatio() {
    for scale in [0.75, 1, 1.4] {
      let size = KeyboardWindowMetrics.contentSize(for: scale)
      XCTAssertEqual(
        size.width / size.height,
        KeyboardWindowMetrics.aspectRatio,
        accuracy: 0.000_001
      )
    }
  }

  func testKeyboardWindowContentSizeGrowsForStatusBanner() {
    let withoutBanner = KeyboardWindowMetrics.contentSize(for: 1, showsStatusBanner: false)
    let withBanner = KeyboardWindowMetrics.contentSize(for: 1, showsStatusBanner: true)
    XCTAssertEqual(withoutBanner.width, withBanner.width)
    XCTAssertEqual(
      withBanner.height,
      withoutBanner.height + KeyboardWindowMetrics.statusBannerHeight
    )
  }

  func testKeyboardWindowContentSizeGrowsForLocalInputPanel() {
    let withoutPanel = KeyboardWindowMetrics.contentSize(for: 1, showsLocalInputPanel: false)
    let withPanel = KeyboardWindowMetrics.contentSize(for: 1, showsLocalInputPanel: true)
    XCTAssertEqual(withoutPanel.width, withPanel.width)
    XCTAssertEqual(
      withPanel.height,
      withoutPanel.height + KeyboardWindowMetrics.localInputChromeHeight
    )
  }

  func testLocalInputPanelShowsForTextAreaTarget() {
    XCTAssertTrue(KeyboardWindowMetrics.showsLocalInputPanel(clickTarget: .textArea))
    XCTAssertFalse(KeyboardWindowMetrics.showsLocalInputPanel(clickTarget: .activeApplication))
  }

  func testStatusBannerVisibilityMatchesPermissionsMessage() {
    XCTAssertTrue(
      KeyboardWindowMetrics.showsStatusBanner(
        hasInsertionError: false,
        clickTarget: .activeApplication,
        isAccessibilityGranted: false
      )
    )
    XCTAssertFalse(
      KeyboardWindowMetrics.showsStatusBanner(
        hasInsertionError: false,
        clickTarget: .activeApplication,
        isAccessibilityGranted: true
      )
    )
    XCTAssertTrue(
      KeyboardWindowMetrics.showsStatusBanner(
        hasInsertionError: true,
        clickTarget: .textArea,
        isAccessibilityGranted: true
      )
    )
  }

  func testKeyboardWindowContentSizeClampsToMinimumScale() {
    XCTAssertEqual(
      KeyboardWindowMetrics.clampedScale(0.5),
      KeyboardWindowMetrics.minimumScale
    )
    XCTAssertEqual(
      KeyboardWindowMetrics.contentSize(for: KeyboardWindowMetrics.clampedScale(0.5)),
      KeyboardWindowMetrics.minimumContentSize
    )
  }
}
