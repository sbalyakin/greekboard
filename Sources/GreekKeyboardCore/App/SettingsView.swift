import SwiftUI

struct SettingsView: View {
  @ObservedObject var settings: SettingsStore
  @ObservedObject var permissions: MacPermissionAdapter
  let setLaunchAtLogin: (Bool) throws -> Void

  var body: some View {
    Form {
      Section("General") {
        Toggle("Launch at Login", isOn: launchAtLoginBinding)
        Toggle("Show Keyboard on Launch", isOn: $settings.showKeyboardOnLaunch)
        Toggle("Always on Top", isOn: $settings.alwaysOnTop)
        Toggle("Hide Dock Icon", isOn: $settings.hideDockIcon)
        if let message = settings.launchAtLoginErrorMessage {
          Text(message)
            .font(.caption)
            .foregroundStyle(.red)
        }
      }

      Section("Keyboard") {
        Picker("Keyboard Layout", selection: .constant(settings.keyboardLayoutIdentifier)) {
          Text("Greek Monotonic").tag("greek-monotonic")
        }
        .disabled(true)
        Toggle("Show Latin Key Labels", isOn: $settings.showLatinKeyLabels)
        Toggle(
          "Highlight Physical Key Presses",
          isOn: $settings.highlightPhysicalKeyPresses
        )
        Toggle("Highlight Key Hover", isOn: $settings.highlightKeyHover)
        Picker("Type Into", selection: $settings.clickTarget) {
          ForEach(ClickTarget.allCases) { target in
            Text(target.title).tag(target)
          }
        }
        .pickerStyle(.radioGroup)
        slider("Key Label Size", value: $settings.keyLabelScale, range: 0.8...1.35)
      }

      Section("Appearance") {
        Picker("Appearance", selection: $settings.appearance) {
          ForEach(KeyboardAppearance.allCases) { appearance in
            Text(appearance.title).tag(appearance)
          }
        }
        slider(
          "Keyboard Size",
          value: $settings.keyboardScale,
          range: Double(KeyboardWindowMetrics.minimumScale)...Double(KeyboardWindowMetrics.maximumScale)
        )
        slider("Key Corner Radius", value: $settings.keyCornerRadius, range: 2...14)
        Toggle("Key Press Animation", isOn: $settings.keyPressAnimation)
      }

      Section("Permissions") {
        permissionRow(
          title: "Active Application",
          isGranted: permissions.isAccessibilityGranted,
          request: permissions.requestAccessibility,
          openSettings: permissions.openAccessibilitySettings
        )
        permissionRow(
          title: "Physical Key Highlighting",
          isGranted: permissions.isInputMonitoringGranted,
          request: permissions.requestInputMonitoring,
          openSettings: permissions.openInputMonitoringSettings
        )
        Text("No keystrokes or typed text are recorded or sent over the network.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .padding(8)
    .frame(width: 520, height: 620)
  }

  private var launchAtLoginBinding: Binding<Bool> {
    Binding(
      get: { settings.launchAtLogin },
      set: { newValue in
        do {
          try setLaunchAtLogin(newValue)
          settings.launchAtLogin = newValue
          settings.launchAtLoginErrorMessage = nil
        } catch {
          settings.launchAtLoginErrorMessage = error.localizedDescription
        }
      }
    )
  }

  private func slider(
    _ title: String,
    value: Binding<Double>,
    range: ClosedRange<Double>
  ) -> some View {
    HStack {
      Text(title)
      Slider(value: value, in: range)
        .frame(maxWidth: 220)
    }
  }

  private func permissionRow(
    title: String,
    isGranted: Bool,
    request: @escaping () -> Void,
    openSettings: @escaping () -> Void
  ) -> some View {
    HStack {
      Label(
        title,
        systemImage: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle"
      )
      .foregroundStyle(isGranted ? .green : .primary)
      Spacer()
      if !isGranted {
        Button("Request…", action: request)
        Button("Open Settings", action: openSettings)
      }
    }
  }
}
