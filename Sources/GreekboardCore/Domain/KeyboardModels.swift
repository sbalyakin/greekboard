import Foundation

public struct PhysicalKeyCode: RawRepresentable, Hashable, Sendable {
  public let rawValue: UInt16

  public init(rawValue: UInt16) {
    self.rawValue = rawValue
  }
}

public enum DeadKey: String, CaseIterable, Sendable {
  case acute
  case diaeresis
  case diaeresisAcute

  var spacingCharacter: String {
    switch self {
    case .acute:
      return "΄"
    case .diaeresis:
      return "¨"
    case .diaeresisAcute:
      return "΅"
    }
  }
}

public enum KeyboardModifier: Sendable {
  case shift
  case capsLock
  case option
  case control
  case command
}

public enum SpecialKey: Sendable {
  case tab
  case returnKey
  case delete
  case space
}

public enum KeyboardKeyKind: Sendable {
  case character(isLetter: Bool)
  case deadKey
  case modifier(KeyboardModifier)
  case special(SpecialKey)
}

public enum KeyOutput: Equatable, Sendable {
  case text(String)
  case deadKey(DeadKey)
  case keyPress(PhysicalKeyCode)
}

public struct KeyboardKey: Identifiable, Sendable {
  public let id: String
  public let physicalKeyCode: PhysicalKeyCode?
  public let latinLabel: String
  public let accessibilityLabel: String
  public let width: Double
  public let kind: KeyboardKeyKind
  public let baseOutput: KeyOutput?
  public let shiftOutput: KeyOutput?
  public let optionOutput: KeyOutput?
  public let optionShiftOutput: KeyOutput?

  public init(
    id: String,
    physicalKeyCode: PhysicalKeyCode?,
    latinLabel: String,
    accessibilityLabel: String,
    width: Double = 1,
    kind: KeyboardKeyKind,
    baseOutput: KeyOutput? = nil,
    shiftOutput: KeyOutput? = nil,
    optionOutput: KeyOutput? = nil,
    optionShiftOutput: KeyOutput? = nil
  ) {
    self.id = id
    self.physicalKeyCode = physicalKeyCode
    self.latinLabel = latinLabel
    self.accessibilityLabel = accessibilityLabel
    self.width = width
    self.kind = kind
    self.baseOutput = baseOutput
    self.shiftOutput = shiftOutput
    self.optionOutput = optionOutput
    self.optionShiftOutput = optionShiftOutput
  }
}

public struct KeyboardRow: Identifiable, Sendable {
  public let id: String
  public let keys: [KeyboardKey]

  public init(id: String, keys: [KeyboardKey]) {
    self.id = id
    self.keys = keys
  }
}

public struct KeyboardLayout: Sendable {
  public let name: String
  public let rows: [KeyboardRow]
  public let deadKeyMappings: [DeadKey: [String: String]]

  public init(
    name: String,
    rows: [KeyboardRow],
    deadKeyMappings: [DeadKey: [String: String]]
  ) {
    self.name = name
    self.rows = rows
    self.deadKeyMappings = deadKeyMappings
  }

  public var keys: [KeyboardKey] {
    rows.flatMap(\.keys)
  }

  public func key(for physicalKeyCode: PhysicalKeyCode) -> KeyboardKey? {
    keys.first { $0.physicalKeyCode == physicalKeyCode }
  }
}
