import Foundation

public enum L10n {
  public static func text(_ key: String, value: String) -> String {
    NSLocalizedString(key, bundle: .module, value: value, comment: "")
  }
}
