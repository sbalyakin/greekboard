import Foundation

public extension KeyboardLayout {
  static let greekMonotonic = KeyboardLayout(
    name: "Greek Monotonic",
    rows: [
      KeyboardRow(id: "number", keys: [
        character("grave", 50, "`", "Grave", "`", "~"),
        character("1", 18, "1", "1", "1", "!"),
        character("2", 19, "2", "2", "2", "@"),
        character("3", 20, "3", "3", "3", "#"),
        character("4", 21, "4", "4", "4", "$"),
        character("5", 23, "5", "5", "5", "%"),
        character("6", 22, "6", "6", "6", "^"),
        character("7", 26, "7", "7", "7", "&"),
        character("8", 28, "8", "8", "8", "*"),
        character("9", 25, "9", "9", "9", "("),
        character("0", 29, "0", "0", "0", ")"),
        character("minus", 27, "-", "Minus", "-", "_"),
        character("equals", 24, "=", "Equals", "=", "+"),
        special("delete", 51, "⌫", "Delete", width: 2, key: .delete)
      ]),
      KeyboardRow(id: "top", keys: [
        special("tab", 48, "⇥", "Tab", width: 1.5, key: .tab),
        character(
          "q",
          12,
          "Q",
          "Greek Question Mark",
          ";",
          ":",
          option: "·"
        ),
        letter("w", 13, "W", "Final Sigma", "ς", "Σ"),
        letter("e", 14, "E", "Epsilon", "ε", "Ε"),
        letter("r", 15, "R", "Rho", "ρ", "Ρ"),
        letter("t", 17, "T", "Tau", "τ", "Τ"),
        letter("y", 16, "Y", "Upsilon", "υ", "Υ"),
        letter("u", 32, "U", "Theta", "θ", "Θ"),
        letter("i", 34, "I", "Iota", "ι", "Ι"),
        letter("o", 31, "O", "Omicron", "ο", "Ο"),
        letter("p", 35, "P", "Pi", "π", "Π"),
        character("leftBracket", 33, "[", "Left Bracket", "[", "{"),
        character("rightBracket", 30, "]", "Right Bracket", "]", "}"),
        character("backslash", 42, "\\", "Backslash", "\\", "|", width: 1.5)
      ]),
      KeyboardRow(id: "home", keys: [
        modifier("capsLock", 57, "caps", "Caps Lock", width: 1.75, .capsLock),
        letter("a", 0, "A", "Alpha", "α", "Α"),
        letter("s", 1, "S", "Sigma", "σ", "Σ"),
        letter("d", 2, "D", "Delta", "δ", "Δ"),
        letter("f", 3, "F", "Phi", "φ", "Φ"),
        letter("g", 5, "G", "Gamma", "γ", "Γ"),
        letter("h", 4, "H", "Eta", "η", "Η"),
        letter("j", 38, "J", "Xi", "ξ", "Ξ"),
        letter("k", 40, "K", "Kappa", "κ", "Κ"),
        letter("l", 37, "L", "Lambda", "λ", "Λ"),
        deadKey("semicolon", 41, ";", "Acute Accent"),
        character("quote", 39, "'", "Apostrophe", "'", "\""),
        special("return", 36, "⏎", "Return", width: 2.375, key: .returnKey)
      ]),
      KeyboardRow(id: "bottom", keys: [
        modifier("leftShift", 56, "shift", "Left Shift", width: 2.25, .shift),
        letter("z", 6, "Z", "Zeta", "ζ", "Ζ"),
        letter("x", 7, "X", "Chi", "χ", "Χ"),
        letter("c", 8, "C", "Psi", "ψ", "Ψ"),
        letter("v", 9, "V", "Omega", "ω", "Ω"),
        letter("b", 11, "B", "Beta", "β", "Β"),
        letter("n", 45, "N", "Nu", "ν", "Ν"),
        letter("m", 46, "M", "Mu", "μ", "Μ"),
        character("comma", 43, ",", "Comma", ",", "<"),
        character("period", 47, ".", "Period", ".", ">"),
        character("slash", 44, "/", "Slash", "/", "?"),
        modifier("rightShift", 60, "shift", "Right Shift", width: 3, .shift)
      ]),
      KeyboardRow(id: "modifiers", keys: [
        modifier("leftControl", 59, "control", "Left Control", width: 1.5, .control),
        modifier("leftOption", 58, "option", "Left Option", width: 1.25, .option),
        modifier("leftCommand", 55, "command", "Left Command", width: 1.5, .command),
        special("space", 49, "", "Space", width: 7.375, key: .space),
        modifier("rightCommand", 54, "command", "Right Command", width: 1.5, .command),
        modifier("rightOption", 61, "option", "Right Option", width: 1.25, .option),
        modifier("rightControl", 62, "control", "Right Control", width: 1.5, .control)
      ])
    ],
    deadKeyMappings: [
      .acute: [
        "α": "ά", "Α": "Ά", "ε": "έ", "Ε": "Έ", "η": "ή", "Η": "Ή",
        "ι": "ί", "Ι": "Ί", "ο": "ό", "Ο": "Ό", "υ": "ύ", "Υ": "Ύ",
        "ω": "ώ", "Ω": "Ώ"
      ],
      .diaeresis: [
        "ι": "ϊ", "Ι": "Ϊ", "υ": "ϋ", "Υ": "Ϋ"
      ],
      .diaeresisAcute: [
        "ι": "ΐ", "υ": "ΰ"
      ]
    ]
  )
}

private extension KeyboardLayout {
  static func character(
    _ id: String,
    _ keyCode: UInt16,
    _ latinLabel: String,
    _ accessibilityLabel: String,
    _ base: String,
    _ shift: String,
    option: String? = nil,
    optionShift: String? = nil,
    width: Double = 1
  ) -> KeyboardKey {
    KeyboardKey(
      id: id,
      physicalKeyCode: PhysicalKeyCode(rawValue: keyCode),
      latinLabel: latinLabel,
      accessibilityLabel: accessibilityLabel,
      width: width,
      kind: .character(isLetter: false),
      baseOutput: .text(base),
      shiftOutput: .text(shift),
      optionOutput: option.map(KeyOutput.text),
      optionShiftOutput: optionShift.map(KeyOutput.text)
    )
  }

  static func letter(
    _ id: String,
    _ keyCode: UInt16,
    _ latinLabel: String,
    _ accessibilityLabel: String,
    _ base: String,
    _ shift: String,
    option: String? = nil
  ) -> KeyboardKey {
    KeyboardKey(
      id: id,
      physicalKeyCode: PhysicalKeyCode(rawValue: keyCode),
      latinLabel: latinLabel,
      accessibilityLabel: accessibilityLabel,
      kind: .character(isLetter: true),
      baseOutput: .text(base),
      shiftOutput: .text(shift),
      optionOutput: option.map(KeyOutput.text)
    )
  }

  static func deadKey(
    _ id: String,
    _ keyCode: UInt16,
    _ latinLabel: String,
    _ accessibilityLabel: String
  ) -> KeyboardKey {
    KeyboardKey(
      id: id,
      physicalKeyCode: PhysicalKeyCode(rawValue: keyCode),
      latinLabel: latinLabel,
      accessibilityLabel: accessibilityLabel,
      kind: .deadKey,
      baseOutput: .deadKey(.acute),
      shiftOutput: .deadKey(.diaeresis),
      optionOutput: .deadKey(.diaeresisAcute)
    )
  }

  static func modifier(
    _ id: String,
    _ keyCode: UInt16,
    _ latinLabel: String,
    _ accessibilityLabel: String,
    width: Double,
    _ modifier: KeyboardModifier
  ) -> KeyboardKey {
    KeyboardKey(
      id: id,
      physicalKeyCode: PhysicalKeyCode(rawValue: keyCode),
      latinLabel: latinLabel,
      accessibilityLabel: accessibilityLabel,
      width: width,
      kind: .modifier(modifier)
    )
  }

  static func special(
    _ id: String,
    _ keyCode: UInt16,
    _ latinLabel: String,
    _ accessibilityLabel: String,
    width: Double,
    key: SpecialKey
  ) -> KeyboardKey {
    let output: KeyOutput
    switch key {
    case .tab:
      output = .keyPress(PhysicalKeyCode(rawValue: 48))
    case .returnKey:
      output = .keyPress(PhysicalKeyCode(rawValue: 36))
    case .delete:
      output = .keyPress(PhysicalKeyCode(rawValue: 51))
    case .space:
      output = .text(" ")
    }

    return KeyboardKey(
      id: id,
      physicalKeyCode: PhysicalKeyCode(rawValue: keyCode),
      latinLabel: latinLabel,
      accessibilityLabel: accessibilityLabel,
      width: width,
      kind: .special(key),
      baseOutput: output
    )
  }
}
