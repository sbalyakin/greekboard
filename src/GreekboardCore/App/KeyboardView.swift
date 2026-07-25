import AppKit
import Combine
import SwiftUI

struct KeyboardView: View {
  let viewModel: KeyboardViewModel
  let settings: SettingsStore
  let permissions: MacPermissionAdapter

  @State private var chromeState: KeyboardViewChromeState

  init(
    viewModel: KeyboardViewModel,
    settings: SettingsStore,
    permissions: MacPermissionAdapter
  ) {
    self.viewModel = viewModel
    self.settings = settings
    self.permissions = permissions
    _chromeState = State(
      initialValue: KeyboardViewChromeState(
        hasInsertionError: viewModel.insertionErrorMessage != nil,
        clickTarget: settings.clickTarget,
        isAccessibilityGranted: permissions.isAccessibilityGranted
      )
    )
  }

  var body: some View {
    GeometryReader { proxy in
      let scale = KeyboardWindowMetrics.scale(
        to: proxy.size,
        showsStatusBanner: chromeState.showsStatusBanner,
        showsLocalInputPanel: chromeState.showsLocalInputPanel
      )
      VStack(spacing: 0) {
        KeyboardContentView(
          viewModel: viewModel,
          settings: settings,
          showsLocalInputPanel: chromeState.showsLocalInputPanel,
          scale: scale
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        KeyboardStatusBannerView(
          viewModel: viewModel,
          settings: settings,
          permissions: permissions,
          scale: scale
        )
      }
      .padding(KeyboardLayoutMetrics.padding * scale)
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .background(.regularMaterial)
    .onReceive(chromeStatePublisher) { state in
      guard chromeState != state else { return }
      chromeState = state
    }
  }

  private var chromeStatePublisher: AnyPublisher<KeyboardViewChromeState, Never> {
    Publishers.CombineLatest3(
      viewModel.$insertionErrorMessage.map { $0 != nil },
      settings.$clickTarget,
      permissions.$isAccessibilityGranted
    )
    .map(KeyboardViewChromeState.init)
    .removeDuplicates()
    .eraseToAnyPublisher()
  }
}

private struct KeyboardViewChromeState: Equatable {
  let showsStatusBanner: Bool
  let showsLocalInputPanel: Bool

  init(hasInsertionError: Bool, clickTarget: ClickTarget, isAccessibilityGranted: Bool) {
    showsStatusBanner = KeyboardWindowMetrics.showsStatusBanner(
      hasInsertionError: hasInsertionError,
      clickTarget: clickTarget,
      isAccessibilityGranted: isAccessibilityGranted
    )
    showsLocalInputPanel = KeyboardWindowMetrics.showsLocalInputPanel(
      clickTarget: clickTarget
    )
  }
}

private struct KeyboardContentView: View {
  let viewModel: KeyboardViewModel
  let settings: SettingsStore
  let showsLocalInputPanel: Bool
  let scale: CGFloat

  var body: some View {
    let keysWidth = KeyboardLayoutMetrics.keysWidth(for: viewModel.layout) * scale

    VStack(spacing: 0) {
      if showsLocalInputPanel {
        ObservedLocalInputPanel(
          viewModel: viewModel,
          settings: settings,
          scale: scale
        )
        .frame(width: keysWidth)
        .padding(.bottom, KeyboardWindowMetrics.localInputKeyboardGap * scale)
      }

      ObservedKeyboardGrid(
        viewModel: viewModel,
        settings: settings,
        scale: scale
      )
    }
    .padding(KeyboardLayoutMetrics.padding * scale)
  }
}

private struct ObservedKeyboardGrid: View {
  let viewModel: KeyboardViewModel
  let settings: SettingsStore
  let scale: CGFloat

  @State private var keyboardState: KeyboardState
  @State private var gridSettings: KeyboardGridSettings

  init(viewModel: KeyboardViewModel, settings: SettingsStore, scale: CGFloat) {
    self.viewModel = viewModel
    self.settings = settings
    self.scale = scale
    _keyboardState = State(initialValue: viewModel.state)
    _gridSettings = State(initialValue: KeyboardGridSettings(settings: settings))
  }

  var body: some View {
    VStack(spacing: KeyboardLayoutMetrics.verticalSpacing * scale) {
      ForEach(viewModel.layout.rows) { row in
        HStack(spacing: KeyboardLayoutMetrics.horizontalSpacing * scale) {
          ForEach(row.keys) { key in
            KeyCapView(
              presentation: keyCapPresentation(for: key),
              key: key,
              viewModel: viewModel
            )
            .equatable()
          }
        }
      }
    }
    .onReceive(viewModel.$state.removeDuplicates()) { state in
      guard keyboardState != state else { return }
      keyboardState = state
    }
    .onReceive(gridSettingsPublisher) { newSettings in
      guard gridSettings != newSettings else { return }
      gridSettings = newSettings
    }
  }

  private func keyCapPresentation(
    for key: KeyboardKey
  ) -> KeyCapPresentation {
    KeyCapPresentation(
      displayText: viewModel.displayText(for: key, state: keyboardState),
      latinLabel: key.latinLabel,
      isPressed: gridSettings.highlightPhysicalKeyPresses
        && viewModel.isPressed(key, state: keyboardState),
      isActive: viewModel.isActive(key, state: keyboardState),
      isEnabled: viewModel.isEnabled(key, state: keyboardState),
      visual: gridSettings.visual,
      scale: scale,
      accessibilityLabel: key.accessibilityLabel
    )
  }

  private var gridSettingsPublisher: AnyPublisher<KeyboardGridSettings, Never> {
    Publishers.CombineLatest4(
      settings.$showLatinKeyLabels,
      settings.$highlightPhysicalKeyPresses,
      settings.$highlightKeyHover,
      settings.$keyLabelScale
    )
    .combineLatest(settings.$keyCornerRadius, settings.$keyPressAnimation)
    .map { values, keyCornerRadius, keyPressAnimation in
      let (
        showLatinKeyLabels,
        highlightPhysicalKeyPresses,
        highlightKeyHover,
        keyLabelScale
      ) = values
      return KeyboardGridSettings(
        showLatinKeyLabels: showLatinKeyLabels,
        highlightPhysicalKeyPresses: highlightPhysicalKeyPresses,
        highlightKeyHover: highlightKeyHover,
        keyLabelScale: keyLabelScale,
        keyCornerRadius: keyCornerRadius,
        keyPressAnimation: keyPressAnimation
      )
    }
    .removeDuplicates()
    .eraseToAnyPublisher()
  }
}

private struct KeyboardGridSettings: Equatable {
  let highlightPhysicalKeyPresses: Bool
  let visual: KeyCapVisualSettings

  @MainActor
  init(settings: SettingsStore) {
    self.init(
      showLatinKeyLabels: settings.showLatinKeyLabels,
      highlightPhysicalKeyPresses: settings.highlightPhysicalKeyPresses,
      highlightKeyHover: settings.highlightKeyHover,
      keyLabelScale: settings.keyLabelScale,
      keyCornerRadius: settings.keyCornerRadius,
      keyPressAnimation: settings.keyPressAnimation
    )
  }

  init(
    showLatinKeyLabels: Bool,
    highlightPhysicalKeyPresses: Bool,
    highlightKeyHover: Bool,
    keyLabelScale: Double,
    keyCornerRadius: Double,
    keyPressAnimation: Bool
  ) {
    self.highlightPhysicalKeyPresses = highlightPhysicalKeyPresses
    self.visual = KeyCapVisualSettings(
      showLatinKeyLabels: showLatinKeyLabels,
      highlightKeyHover: highlightKeyHover,
      keyLabelScale: keyLabelScale,
      keyCornerRadius: keyCornerRadius,
      keyPressAnimation: keyPressAnimation
    )
  }
}

private struct KeyboardStatusBannerView: View {
  let viewModel: KeyboardViewModel
  let settings: SettingsStore
  let permissions: MacPermissionAdapter
  let scale: CGFloat

  @State private var state: KeyboardStatusBannerState

  init(
    viewModel: KeyboardViewModel,
    settings: SettingsStore,
    permissions: MacPermissionAdapter,
    scale: CGFloat
  ) {
    self.viewModel = viewModel
    self.settings = settings
    self.permissions = permissions
    self.scale = scale
    _state = State(
      initialValue: KeyboardStatusBannerState(
        insertionErrorMessage: viewModel.insertionErrorMessage,
        lastFailedText: viewModel.lastFailedText,
        clickTarget: settings.clickTarget,
        isAccessibilityGranted: permissions.isAccessibilityGranted
      )
    )
  }

  var body: some View {
    Group {
      if let message = state.insertionErrorMessage {
        HStack(spacing: 8 * scale) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.yellow)
          Text(message)
            .lineLimit(1)
          Spacer()
          if let text = state.lastFailedText {
            Button("Copy Character") {
              copy(text)
            }
            .controlSize(.small)
          }
          if !state.isAccessibilityGranted {
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
      } else if state.clickTarget.insertsIntoActiveApplication
        && !state.isAccessibilityGranted
      {
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
    .onReceive(statePublisher) { newState in
      guard state != newState else { return }
      state = newState
    }
  }

  private var statePublisher: AnyPublisher<KeyboardStatusBannerState, Never> {
    Publishers.CombineLatest4(
      viewModel.$insertionErrorMessage,
      viewModel.$lastFailedText,
      settings.$clickTarget,
      permissions.$isAccessibilityGranted
    )
    .map(KeyboardStatusBannerState.init)
    .removeDuplicates()
    .eraseToAnyPublisher()
  }

  private func copy(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }
}

private struct KeyboardStatusBannerState: Equatable {
  let insertionErrorMessage: String?
  let lastFailedText: String?
  let clickTarget: ClickTarget
  let isAccessibilityGranted: Bool
}

private struct KeyCapVisualSettings: Equatable {
  var showLatinKeyLabels: Bool
  var highlightKeyHover: Bool
  var keyLabelScale: Double
  var keyCornerRadius: Double
  var keyPressAnimation: Bool
}

private struct KeyCapPresentation: Equatable {
  var displayText: String
  var latinLabel: String
  var isPressed: Bool
  var isActive: Bool
  var isEnabled: Bool
  var visual: KeyCapVisualSettings
  var scale: CGFloat
  var accessibilityLabel: String
}

private struct ObservedLocalInputPanel: View {
  let viewModel: KeyboardViewModel
  let settings: SettingsStore
  let scale: CGFloat

  @State private var draft: DraftTextBuffer
  @State private var localSettings: LocalInputSettings

  init(viewModel: KeyboardViewModel, settings: SettingsStore, scale: CGFloat) {
    self.viewModel = viewModel
    self.settings = settings
    self.scale = scale
    _draft = State(initialValue: viewModel.draft)
    _localSettings = State(initialValue: LocalInputSettings(settings: settings))
  }

  var body: some View {
    LocalInputPanel(
      draft: draftBinding,
      scale: scale,
      keyLabelScale: localSettings.keyLabelScale,
      keyPressAnimation: localSettings.keyPressAnimation,
      onCopy: { copy(draft.text) },
      onClear: { viewModel.clearDraft() }
    )
    .onReceive(viewModel.$draft.removeDuplicates()) { newDraft in
      guard draft != newDraft else { return }
      draft = newDraft
    }
    .onReceive(localSettingsPublisher) { newSettings in
      guard localSettings != newSettings else { return }
      localSettings = newSettings
    }
  }

  private var draftBinding: Binding<DraftTextBuffer> {
    Binding(
      get: { draft },
      set: { newDraft in
        if draft != newDraft {
          draft = newDraft
        }
        if viewModel.draft != newDraft {
          viewModel.draft = newDraft
        }
      }
    )
  }

  private var localSettingsPublisher: AnyPublisher<LocalInputSettings, Never> {
    Publishers.CombineLatest(settings.$keyLabelScale, settings.$keyPressAnimation)
      .map { keyLabelScale, keyPressAnimation in
        LocalInputSettings(
          keyLabelScale: keyLabelScale,
          keyPressAnimation: keyPressAnimation
        )
      }
      .removeDuplicates()
      .eraseToAnyPublisher()
  }

  private func copy(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }
}

private struct LocalInputSettings: Equatable {
  let keyLabelScale: Double
  let keyPressAnimation: Bool

  @MainActor
  init(settings: SettingsStore) {
    self.init(
      keyLabelScale: settings.keyLabelScale,
      keyPressAnimation: settings.keyPressAnimation
    )
  }

  init(keyLabelScale: Double, keyPressAnimation: Bool) {
    self.keyLabelScale = keyLabelScale
    self.keyPressAnimation = keyPressAnimation
  }
}

private struct LocalInputPanel: View {
  @Binding var draft: DraftTextBuffer
  let scale: CGFloat
  let keyLabelScale: Double
  let keyPressAnimation: Bool
  let onCopy: () -> Void
  let onClear: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: KeyboardWindowMetrics.localInputFieldButtonSpacing * scale) {
      LocalDraftTextView(
        draft: $draft,
        fontSize: KeyboardLayoutMetrics.keyLabelFontSize * keyLabelScale * scale
      )
      .frame(maxWidth: .infinity)
      .frame(height: KeyboardWindowMetrics.localInputPanelHeight * scale)

      VStack(spacing: KeyboardLayoutMetrics.verticalSpacing * scale) {
        DraftActionButton(
          symbol: "⧉",
          accessibilityLabel: "Copy",
          scale: scale,
          animationEnabled: keyPressAnimation
        ) {
          onCopy()
        }

        DraftActionButton(
          symbol: "×",
          accessibilityLabel: "Clear",
          scale: scale,
          animationEnabled: keyPressAnimation
        ) {
          onClear()
        }
      }
    }
    .frame(height: KeyboardWindowMetrics.localInputPanelHeight * scale)
  }
}

private struct DraftActionButton: View {
  let symbol: String
  let accessibilityLabel: String
  let scale: CGFloat
  let animationEnabled: Bool
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme
  @State private var isHovered = false
  @State private var isPressed = false

  var body: some View {
    Button(action: action) {
      ZStack {
        RoundedRectangle(cornerRadius: 8 * scale)
          .fill(backgroundColor)
          .opacity(isHovered ? 1 : 0)
          .overlay {
            RoundedRectangle(cornerRadius: 8 * scale)
              .fill(
                Color(nsColor: .labelColor)
                  .opacity(isPressed ? 0.12 : 0.05)
              )
              .opacity(isHovered ? 1 : 0)
          }

        Text(symbol)
          .font(.system(size: 18 * scale, weight: .regular))
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(KeyCapPressButtonStyle(isPressed: $isPressed))
    .focusable(false)
    .frame(
      width: KeyboardWindowMetrics.localInputButtonHeight * scale,
      height: KeyboardWindowMetrics.localInputButtonHeight * scale
    )
    .onHover { hovering in
      isHovered = hovering
    }
    .animation(animation, value: isPressed)
    .animation(animation, value: isHovered)
    .accessibilityLabel(accessibilityLabel)
  }

  private var animation: Animation? {
    guard animationEnabled, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
      return nil
    }
    return .easeOut(duration: 0.08)
  }

  private var backgroundColor: Color {
    Color(nsColor: NSColor(hex: colorScheme == .dark ? "#3A3C3D" : "#E3E3E3"))
  }
}

private struct KeyCapView: View, Equatable {
  let presentation: KeyCapPresentation
  let key: KeyboardKey
  let viewModel: KeyboardViewModel
  @State private var isHovered = false
  @State private var isMousePressed = false

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.presentation == rhs.presentation && lhs.key.id == rhs.key.id
  }

  var body: some View {
    let pressed = isMousePressed || presentation.isPressed
    let hovered =
      presentation.visual.highlightKeyHover && isHovered && presentation.isEnabled

    Button {
      viewModel.press(key, clickCount: NSApp.currentEvent?.clickCount ?? 1)
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: presentation.visual.keyCornerRadius * presentation.scale)
          .fill(keyColor(isPressed: pressed, isActive: presentation.isActive))
          .overlay {
            if hovered && !pressed && !presentation.isActive {
              RoundedRectangle(cornerRadius: presentation.visual.keyCornerRadius * presentation.scale)
                .fill(Color.accentColor.opacity(0.08))
            }
          }
          .shadow(color: .black.opacity(0.18), radius: presentation.scale, y: presentation.scale)

        Text(presentation.displayText)
          .font(
            .system(
              size: KeyboardLayoutMetrics.keyLabelFontSize
                * presentation.visual.keyLabelScale
                * presentation.scale,
              weight: .medium
            )
          )
          .minimumScaleFactor(0.55)
          .lineLimit(1)

        if presentation.visual.showLatinKeyLabels && !presentation.latinLabel.isEmpty {
          Text(presentation.latinLabel.uppercased())
            .font(
              .system(
                size: 8 * presentation.visual.keyLabelScale * presentation.scale,
                weight: .regular
              )
            )
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(5 * presentation.scale)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(KeyCapPressButtonStyle(isPressed: $isMousePressed))
    .focusable(false)
    .disabled(!presentation.isEnabled)
    .opacity(presentation.isEnabled ? 1 : 0.33)
    .frame(
      width: KeyboardLayoutMetrics.keyWidth * key.width * presentation.scale,
      height: KeyboardLayoutMetrics.keyHeight * presentation.scale
    )
    .scaleEffect(pressed ? 0.96 : 1)
    .onHover { hovering in
      isHovered = hovering
    }
    .animation(
      animation(isEnabled: presentation.visual.keyPressAnimation),
      value: pressed
    )
    .animation(
      animation(isEnabled: presentation.visual.keyPressAnimation),
      value: hovered
    )
    .accessibilityLabel(presentation.accessibilityLabel)
    .accessibilityValue(presentation.isActive ? "Active" : "")
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
