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
            keyView(key, scale: scale)
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

  private func keyView(_ key: KeyboardKey, scale: CGFloat) -> some View {
    let pressed = settings.highlightPhysicalKeyPresses && viewModel.isPressed(key)
    let active = viewModel.isActive(key)
    let isEnabled = viewModel.isEnabled(key)
    let displayText = viewModel.displayText(for: key)

    return Button {
      viewModel.press(key, clickCount: NSApp.currentEvent?.clickCount ?? 1)
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: settings.keyCornerRadius * scale)
          .fill(keyColor(isPressed: pressed, isActive: active))
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
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.58)
    .frame(
      width: KeyboardLayoutMetrics.keyWidth * key.width * scale,
      height: KeyboardLayoutMetrics.keyHeight * scale
    )
    .scaleEffect(pressed ? 0.96 : 1)
    .animation(
      animation(isEnabled: settings.keyPressAnimation),
      value: pressed
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
