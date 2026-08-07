import Foundation
import Testing
@testable import GreekboardCore

@MainActor
@Test("Slider settings persist only when committed")
func sliderSettingsPersistOnlyWhenCommitted() throws {
  let suiteName = "SettingsStoreTests-\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defer { defaults.removePersistentDomain(forName: suiteName) }
  let settings = SettingsStore(defaults: defaults)

  settings.keyLabelScale = 1.2
  settings.keyboardScale = 1.15
  settings.keyCornerRadius = 10
  settings.windowOpacityOnHover = 0.9
  settings.windowOpacityOutside = 0.6

  #expect(settings.keyLabelScale == 1.2)
  #expect(settings.keyboardScale == 1.15)
  #expect(settings.keyCornerRadius == 10)
  #expect(settings.windowOpacityOnHover == 0.9)
  #expect(settings.windowOpacityOutside == 0.6)
  #expect(defaults.object(forKey: "settings.keyLabelScale") == nil)
  #expect(defaults.object(forKey: "settings.keyboardScale") == nil)
  #expect(defaults.object(forKey: "settings.keyCornerRadius") == nil)
  #expect(defaults.object(forKey: "settings.windowOpacityOnHover") == nil)
  #expect(defaults.object(forKey: "settings.windowOpacityOutside") == nil)

  settings.commitSliderSettings()

  #expect(defaults.double(forKey: "settings.keyLabelScale") == 1.2)
  #expect(defaults.double(forKey: "settings.keyboardScale") == 1.15)
  #expect(defaults.double(forKey: "settings.keyCornerRadius") == 10)
  #expect(defaults.double(forKey: "settings.windowOpacityOnHover") == 0.9)
  #expect(defaults.double(forKey: "settings.windowOpacityOutside") == 0.6)
}
