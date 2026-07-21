import AppKit
import XCTest
@testable import GreekKeyboardCore

final class NSColorHexTests: XCTestCase {
  func testHexColorCreatesExpectedSRGBComponentsAndOpacity() {
    guard let color = NSColor(hex: "#19191A", opacity: 0.4).usingColorSpace(.sRGB) else {
      return XCTFail("Expected an sRGB-compatible color")
    }

    XCTAssertEqual(color.redComponent, CGFloat(25.0 / 255.0), accuracy: 0.0001)
    XCTAssertEqual(color.greenComponent, CGFloat(25.0 / 255.0), accuracy: 0.0001)
    XCTAssertEqual(color.blueComponent, CGFloat(26.0 / 255.0), accuracy: 0.0001)
    XCTAssertEqual(color.alphaComponent, 0.4, accuracy: 0.0001)
  }
}
