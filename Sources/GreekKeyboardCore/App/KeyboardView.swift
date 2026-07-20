import AppKit
import SwiftUI

struct KeyboardView: View {
  @ObservedObject var viewModel: KeyboardViewModel
  @ObservedObject var settings: SettingsStore
  @ObservedObject var permissions: MacPermissionAdapter

  private var showsStatusBanner: Bool {
    KeyboardWindowMetrics.showsStatusBanner(
      hasInsertionError: viewModel.insertionErrorMessage != nil,
      clickToTypeEnabled: settings.enableClickToType,
      isAccessibilityGranted: permissions.isAccessibilityGranted
    )
  }

  var body: some View {
    GeometryReader { proxy in
      let scale = KeyboardWindowMetrics.scale(
        to: proxy.size,
        showsStatusBanner: showsStatusBanner
      )
      VStack(spacing: 0) {
        keyboard(scale: scale)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        statusBanner(scale: scale)
      }
      .padding(KeyboardLayoutMetrics.padding * scale)
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .background(.regularMaterial)
  }

  private func keyboard(scale: CGFloat) -> some View {
    VStack(spacing: KeyboardLayoutMetrics.verticalSpacing * scale) {
      ForEach(viewModel.layout.rows) { row in
        HStack(spacing: KeyboardLayoutMetrics.horizontalSpacing * scale) {
          ForEach(row.keys) { key in
            KeyCapView(
              key: key,
              scale: scale,
              viewModel: viewModel,
              settings: settings
            )
          }
        }
      }
    }
    .padding(KeyboardLayoutMetrics.padding * scale)
  }

  @ViewBuilder
  private func statusBanner(scale: CGFloat) -> some View {
    if let message = viewModel.insertionErrorMessage {
      HStack(spacing: 8 * scale) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.yellow)
        Text(message)
          .lineLimit(1)
        Spacer()
        if let text = viewModel.lastFailedText {
          Button("Copy Character") {
            copy(text)
          }
          .controlSize(.small)
        }
        if !permissions.isAccessibilityGranted {
          Button("Allow Typing…") {
            permissions.requestAccessibility()
          }
          .controlSize(.small)
        }
        Button {
          viewModel.dismissInsertionError()
        } label: {
          Image(systemName: "xmark")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss")
      }
      .font(.system(size: 11 * scale))
      .padding(.horizontal, 8 * scale)
      .frame(height: KeyboardWindowMetrics.statusBannerHeight * scale)
    } else if settings.enableClickToType && !permissions.isAccessibilityGranted {
      HStack(spacing: 8 * scale) {
        Image(systemName: "eye")
        Text("Viewer mode. Allow Accessibility access to type by clicking keys.")
          .lineLimit(1)
        Spacer()
        Button("Allow Typing…") {
          permissions.requestAccessibility()
        }
        .controlSize(.small)
      }
      .font(.system(size: 11 * scale))
      .padding(.horizontal, 8 * scale)
      .frame(height: KeyboardWindowMetrics.statusBannerHeight * scale)
    }
  }

  private func copy(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }
}

private struct KeyCapView: View {
  let key: KeyboardKey
  let scale: CGFloat
  @ObservedObject var viewModel: KeyboardViewModel
  @ObservedObject var settings: SettingsStore
  @State private var isHovered = false
  @State private var isMousePressed = false

  var body: some View {
    let pressed =
      isMousePressed
      || (settings.highlightPhysicalKeyPresses && viewModel.isPressed(key))
    let active = viewModel.isActive(key)
    let hovered = settings.highlightKeyHover && isHovered
    let isEnabled = viewModel.isEnabled(key)
    let displayText = viewModel.displayText(for: key)

    Button {
      viewModel.press(key, clickCount: NSApp.currentEvent?.clickCount ?? 1)
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: settings.keyCornerRadius * scale)
          .fill(keyColor(isPressed: pressed, isActive: active))
          .overlay {
            if hovered && !pressed && !active {
              RoundedRectangle(cornerRadius: settings.keyCornerRadius * scale)
                .fill(Color(nsColor: .labelColor).opacity(0.1))
            }
          }
          .shadow(color: .black.opacity(0.18), radius: scale, y: scale)

        Text(displayText)
          .font(
            .system(
              size: 20 * settings.keyLabelScale * scale,
              weight: .medium
            )
          )
          .minimumScaleFactor(0.55)
          .lineLimit(1)

        if settings.showLatinKeyLabels && !key.latinLabel.isEmpty {
          Text(key.latinLabel.uppercased())
            .font(
              .system(
                size: 8 * settings.keyLabelScale * scale,
                weight: .regular
              )
            )
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(5 * scale)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(KeyCapPressButtonStyle(isPressed: $isMousePressed))
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.58)
    .frame(
      width: KeyboardLayoutMetrics.keyWidth * key.width * scale,
      height: KeyboardLayoutMetrics.keyHeight * scale
    )
    .scaleEffect(pressed ? 0.96 : 1)
    .onHover { hovering in
      isHovered = hovering
    }
    .animation(
      animation(isEnabled: settings.keyPressAnimation),
      value: pressed
    )
    .animation(
      animation(isEnabled: settings.keyPressAnimation),
      value: hovered
    )
    .accessibilityLabel(key.accessibilityLabel)
    .accessibilityValue(active ? "Active" : "")
    .contextMenu {
      if let text = viewModel.copyText(for: key) {
        Button("Copy Character") {
          copy(text)
        }
      }
    }
  }

  private func keyColor(isPressed: Bool, isActive: Bool) -> Color {
    if isPressed {
      return .accentColor.opacity(0.9)
    }
    if isActive {
      return .accentColor.opacity(0.55)
    }
    return Color(nsColor: .controlBackgroundColor)
  }

  private func animation(isEnabled: Bool) -> Animation? {
    guard isEnabled, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
      return nil
    }
    return .easeOut(duration: 0.08)
  }

  private func copy(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }
}

private struct KeyCapPressButtonStyle: ButtonStyle {
  @Binding var isPressed: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .onChange(of: configuration.isPressed) { _, pressed in
        isPressed = pressed
      }
  }
}
