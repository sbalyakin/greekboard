import AppKit

private final class SettingsWindow: NSWindow {
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if event.modifierFlags.contains(.command), event.keyCode == 12 {
      close()
      return true
    }
    return super.performKeyEquivalent(with: event)
  }
}

private final class SettingsGroupView: NSView {
  override var wantsUpdateLayer: Bool { true }

  override func updateLayer() {
    let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    layer?.backgroundColor = NSColor(
      hex: isDark ? "#25262A" : "#F7F7F7"
    ).cgColor
    layer?.cornerRadius = 11
    layer?.masksToBounds = true
  }
}

private final class SettingsSeparatorView: NSView {
  override var wantsUpdateLayer: Bool { true }

  override func updateLayer() {
    let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    layer?.backgroundColor = NSColor(
      hex: isDark ? "#2F3034" : "#ECECEC"
      ).cgColor
  }
}

private final class SettingsToolbarSeparatorView: NSView {
  override var wantsUpdateLayer: Bool { true }

  override func updateLayer() {
    let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    layer?.backgroundColor = NSColor(
      hex: isDark ? "#303135" : "#F2F2F2"
    ).cgColor
  }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
  private enum Tab: String, CaseIterable {
    case general
    case appearance
    case permissions

    var title: String {
      switch self {
      case .general:
        "General"
      case .appearance:
        "Appearance"
      case .permissions:
        "Permissions"
      }
    }

    var systemImage: String {
      switch self {
      case .general:
        "gearshape"
      case .appearance:
        "paintbrush"
      case .permissions:
        "hand.raised"
      }
    }
  }

  private final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
  }

  private struct PermissionControls {
    let imageView: NSImageView
    let buttons: NSStackView
    let requestButton: NSButton
    let openSettingsButton: NSButton
  }

  private let settings: SettingsStore
  private let permissions: MacPermissionAdapter
  private let setLaunchAtLogin: (Bool) throws -> Void

  private var tabContentContainer: NSView!
  private var tabContentViews: [Tab: NSView] = [:]

  private var launchAtLoginSwitch: NSSwitch!
  private var showKeyboardOnLaunchSwitch: NSSwitch!
  private var alwaysOnTopSwitch: NSSwitch!
  private var hideDockIconSwitch: NSSwitch!
  private var launchAtLoginErrorLabel: NSTextField!

  private var showLatinKeyLabelsSwitch: NSSwitch!
  private var highlightPhysicalKeyPressesSwitch: NSSwitch!
  private var highlightKeyHoverSwitch: NSSwitch!
  private var keyLabelScaleSlider: NSSlider!
  private var activeApplicationRadio: NSButton!
  private var textAreaRadio: NSButton!

  private var appearancePopup: NSPopUpButton!
  private var keyboardScaleSlider: NSSlider!
  private var keyCornerRadiusSlider: NSSlider!
  private var keyPressAnimationSwitch: NSSwitch!

  private var accessibilityControls: PermissionControls!
  private var inputMonitoringControls: PermissionControls!

  init(
    settings: SettingsStore,
    permissions: MacPermissionAdapter,
    setLaunchAtLogin: @escaping (Bool) throws -> Void
  ) {
    self.settings = settings
    self.permissions = permissions
    self.setLaunchAtLogin = setLaunchAtLogin

    let window = SettingsWindow(
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Greekboard Settings"
    window.backgroundColor = NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      return NSColor(hex: isDark ? "#1E2023" : "#FFFFFF")
    }
    window.titlebarAppearsTransparent = true
    window.titlebarSeparatorStyle = .none
    window.isReleasedWhenClosed = false
    window.center()

    super.init(window: window)
    window.delegate = self
    setupUI()
    refreshControls()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  func show() {
    permissions.refresh()
    refreshControls()
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }

  func setAppearance(_ appearance: KeyboardAppearance) {
    window?.appearance = appearance.appKitAppearance
  }

  private func setupUI() {
    guard let window, let contentView = window.contentView else {
      return
    }

    let toolbar = NSToolbar(identifier: "SettingsToolbar")
    toolbar.delegate = self
    toolbar.displayMode = .iconAndLabel
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    window.toolbarStyle = .preference
    window.toolbar = toolbar
    toolbar.selectedItemIdentifier = NSToolbarItem.Identifier(Tab.general.rawValue)
    window.setContentSize(NSSize(width: 600, height: 500))

    tabContentViews[.general] = makeGeneralTabView()
    tabContentViews[.appearance] = makeAppearanceTabView()
    tabContentViews[.permissions] = makePermissionsTabView()

    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false
    tabContentContainer = container

    let toolbarSeparator = SettingsToolbarSeparatorView()
    toolbarSeparator.translatesAutoresizingMaskIntoConstraints = false

    contentView.addSubview(container)
    contentView.addSubview(toolbarSeparator)

    NSLayoutConstraint.activate([
      container.topAnchor.constraint(equalTo: contentView.topAnchor),
      container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

      toolbarSeparator.topAnchor.constraint(equalTo: contentView.topAnchor),
      toolbarSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      toolbarSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      toolbarSeparator.heightAnchor.constraint(equalToConstant: 1)
    ])

    showTab(.general)
  }

  private func showTab(_ tab: Tab) {
    guard let view = tabContentViews[tab] else {
      return
    }

    tabContentContainer.subviews.forEach { $0.removeFromSuperview() }
    view.translatesAutoresizingMaskIntoConstraints = false
    tabContentContainer.addSubview(view)
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: tabContentContainer.topAnchor),
      view.leadingAnchor.constraint(equalTo: tabContentContainer.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: tabContentContainer.trailingAnchor),
      view.bottomAnchor.constraint(equalTo: tabContentContainer.bottomAnchor)
    ])
  }

  private func makeGeneralTabView() -> NSView {
    let (scrollView, stack) = makeSettingsScrollStack()

    launchAtLoginErrorLabel = NSTextField(wrappingLabelWithString: "")
    launchAtLoginErrorLabel.font = NSFont.systemFont(ofSize: 11)
    launchAtLoginErrorLabel.textColor = .systemRed
    launchAtLoginErrorLabel.isHidden = true
    launchAtLoginSwitch = toggle(action: #selector(launchAtLoginChanged(_:)))
    showKeyboardOnLaunchSwitch = toggle(
      action: #selector(showKeyboardOnLaunchChanged(_:))
    )
    alwaysOnTopSwitch = toggle(action: #selector(alwaysOnTopChanged(_:)))
    hideDockIconSwitch = toggle(action: #selector(hideDockIconChanged(_:)))

    addSection(
      "Application",
      rowGroups: [
        [
          settingsRow(
            "Launch at Login",
            accessory: launchAtLoginSwitch,
            detail: launchAtLoginErrorLabel
          ),
          settingsRow("Show Keyboard on Launch", accessory: showKeyboardOnLaunchSwitch)
        ],
        [
          settingsRow("Always on Top", accessory: alwaysOnTopSwitch),
          settingsRow("Hide Dock Icon", accessory: hideDockIconSwitch)
        ]
      ],
      to: stack
    )

    let layoutPopup = menuPopup()
    layoutPopup.addItem(withTitle: "Greek Monotonic")
    layoutPopup.isEnabled = false
    addSection(
      "Layout",
      rows: [settingsRow("Keyboard Layout", accessory: layoutPopup)],
      to: stack
    )

    activeApplicationRadio = NSButton(
      radioButtonWithTitle: ClickTarget.activeApplication.title,
      target: self,
      action: #selector(clickTargetChanged(_:))
    )
    activeApplicationRadio.tag = 0
    textAreaRadio = NSButton(
      radioButtonWithTitle: ClickTarget.textArea.title,
      target: self,
      action: #selector(clickTargetChanged(_:))
    )
    textAreaRadio.tag = 1

    let radioStack = NSStackView(views: [activeApplicationRadio, textAreaRadio])
    radioStack.orientation = .horizontal
    radioStack.alignment = .centerY
    radioStack.spacing = 16
    addSection(
      "Input",
      rows: [settingsRow("Type Into", accessory: radioStack)],
      to: stack,
      spacingAfter: 16
    )

    finalizeSettingsStack(scrollView: scrollView, stack: stack)
    return scrollView
  }

  private func makeAppearanceTabView() -> NSView {
    let (scrollView, stack) = makeSettingsScrollStack()

    appearancePopup = menuPopup()
    for appearance in KeyboardAppearance.allCases {
      appearancePopup.addItem(withTitle: appearance.title)
      appearancePopup.lastItem?.representedObject = appearance.rawValue
    }
    appearancePopup.target = self
    appearancePopup.action = #selector(appearanceChanged(_:))
    addSection(
      "Appearance",
      rows: [settingsRow("Appearance", accessory: appearancePopup)],
      to: stack
    )

    showLatinKeyLabelsSwitch = toggle(
      action: #selector(showLatinKeyLabelsChanged(_:))
    )
    highlightPhysicalKeyPressesSwitch = toggle(
      action: #selector(highlightPhysicalKeyPressesChanged(_:))
    )
    highlightKeyHoverSwitch = toggle(
      action: #selector(highlightKeyHoverChanged(_:))
    )
    keyLabelScaleSlider = slider(
      value: settings.keyLabelScale,
      range: 0.8...1.35,
      action: #selector(keyLabelScaleChanged(_:))
    )
    addSection(
      "Key Labels",
      rows: [
        settingsRow("Show Latin Key Labels", accessory: showLatinKeyLabelsSwitch),
        settingsRow(
          "Highlight Physical Key Presses",
          accessory: highlightPhysicalKeyPressesSwitch
        ),
        settingsRow("Highlight Key Hover", accessory: highlightKeyHoverSwitch),
        settingsRow("Key Label Size", accessory: keyLabelScaleSlider)
      ],
      to: stack
    )

    keyboardScaleSlider = slider(
      value: settings.keyboardScale,
      range: Double(KeyboardWindowMetrics.minimumScale)...Double(
        KeyboardWindowMetrics.maximumScale
      ),
      action: #selector(keyboardScaleChanged(_:))
    )
    keyCornerRadiusSlider = slider(
      value: settings.keyCornerRadius,
      range: 2...14,
      action: #selector(keyCornerRadiusChanged(_:))
    )
    keyPressAnimationSwitch = toggle(
      action: #selector(keyPressAnimationChanged(_:))
    )
    addSection(
      "Keyboard",
      rows: [
        settingsRow("Keyboard Size", accessory: keyboardScaleSlider),
        settingsRow("Key Corner Radius", accessory: keyCornerRadiusSlider),
        settingsRow("Key Press Animation", accessory: keyPressAnimationSwitch)
      ],
      to: stack,
      spacingAfter: 16
    )

    finalizeSettingsStack(scrollView: scrollView, stack: stack)
    return scrollView
  }

  private func makePermissionsTabView() -> NSView {
    let (scrollView, stack) = makeSettingsScrollStack()

    let accessibilityRow = permissionRow(
      title: "Active Application",
      requestAction: #selector(requestAccessibility),
      openSettingsAction: #selector(openAccessibilitySettings)
    )
    accessibilityControls = accessibilityRow.controls

    let inputMonitoringRow = permissionRow(
      title: "Physical Key Highlighting",
      requestAction: #selector(requestInputMonitoring),
      openSettingsAction: #selector(openInputMonitoringSettings)
    )
    inputMonitoringControls = inputMonitoringRow.controls

    addSection(
      "Permissions",
      rows: [accessibilityRow.view, inputMonitoringRow.view],
      to: stack,
      spacingAfter: 10
    )

    let privacyNote = NSTextField(
      wrappingLabelWithString: "No keystrokes or typed text are recorded or sent over the network."
    )
    privacyNote.font = NSFont.systemFont(ofSize: 11)
    privacyNote.textColor = .secondaryLabelColor
    add(inset(privacyNote), to: stack, spacingAfter: 16)

    finalizeSettingsStack(scrollView: scrollView, stack: stack)
    return scrollView
  }

  private func makeSettingsScrollStack() -> (NSScrollView, NSStackView) {
    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.borderType = .noBorder
    scrollView.drawsBackground = false
    scrollView.autoresizingMask = [.width, .height]

    let stack = FlippedStackView()
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 0
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 0, right: 20)
    return (scrollView, stack)
  }

  private func finalizeSettingsStack(scrollView: NSScrollView, stack: NSStackView) {
    let clipView = scrollView.contentView
    scrollView.documentView = stack
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: clipView.topAnchor),
      stack.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: clipView.trailingAnchor)
    ])
  }

  private func add(_ view: NSView, to stack: NSStackView, spacingAfter: CGFloat) {
    stack.addArrangedSubview(view)
    view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true
    stack.setCustomSpacing(spacingAfter, after: view)
  }

  private func sectionHeader(_ text: String) -> NSView {
    let label = NSTextField(labelWithString: text)
    label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
    label.textColor = .labelColor
    return inset(label)
  }

  private func inset(_ view: NSView, by amount: CGFloat = 10) -> NSView {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false
    view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(view)
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: container.topAnchor),
      view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: amount),
      view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -amount),
      view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])
    return container
  }

  private func addSection(
    _ title: String,
    rows: [NSView],
    to stack: NSStackView,
    spacingAfter: CGFloat = 32
  ) {
    addSection(
      title,
      rowGroups: [rows],
      to: stack,
      spacingAfter: spacingAfter
    )
  }

  private func addSection(
    _ title: String,
    rowGroups: [[NSView]],
    to stack: NSStackView,
    spacingAfter: CGFloat = 32
  ) {
    let header = sectionHeader(title)
    add(header, to: stack, spacingAfter: 10)

    for (index, rows) in rowGroups.enumerated() {
      let isLastGroup = index == rowGroups.count - 1
      add(
        settingsGroup(rows: rows),
        to: stack,
        spacingAfter: isLastGroup ? spacingAfter : 10
      )
    }
  }

  private func settingsGroup(rows: [NSView]) -> NSView {
    let group = SettingsGroupView()
    group.translatesAutoresizingMaskIntoConstraints = false

    let arrangedViews = rows.enumerated().flatMap { index, row -> [NSView] in
      guard index < rows.count - 1 else {
        return [row]
      }
      return [row, settingsSeparator()]
    }
    let content = NSStackView(views: arrangedViews)
    content.orientation = .vertical
    content.alignment = .leading
    content.spacing = 0
    content.translatesAutoresizingMaskIntoConstraints = false
    group.addSubview(content)

    for view in arrangedViews {
      view.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
    }

    NSLayoutConstraint.activate([
      content.topAnchor.constraint(equalTo: group.topAnchor),
      content.leadingAnchor.constraint(equalTo: group.leadingAnchor),
      content.trailingAnchor.constraint(equalTo: group.trailingAnchor),
      content.bottomAnchor.constraint(equalTo: group.bottomAnchor)
    ])
    return group
  }

  private func settingsSeparator() -> NSView {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false

    let separator = SettingsSeparatorView()
    separator.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(separator)
    NSLayoutConstraint.activate([
      container.heightAnchor.constraint(equalToConstant: 1),
      separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
      separator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
      separator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      separator.heightAnchor.constraint(equalToConstant: 1)
    ])
    return container
  }

  private func settingsRow(
    _ title: String,
    accessory: NSView,
    detail: NSTextField? = nil
  ) -> NSView {
    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = NSFont.systemFont(ofSize: 13)

    let labels = NSStackView(views: [titleLabel] + (detail.map { [$0] } ?? []))
    labels.orientation = .vertical
    labels.alignment = .leading
    labels.spacing = 2
    accessory.setAccessibilityLabel(title)
    return settingsRow(leading: labels, accessory: accessory)
  }

  private func settingsRow(
    leading: NSView,
    accessory: NSView,
    minimumHeight: CGFloat = 36
  ) -> NSView {
    let row = NSView()
    row.translatesAutoresizingMaskIntoConstraints = false
    leading.translatesAutoresizingMaskIntoConstraints = false
    accessory.translatesAutoresizingMaskIntoConstraints = false
    row.addSubview(leading)
    row.addSubview(accessory)

    NSLayoutConstraint.activate([
      row.heightAnchor.constraint(greaterThanOrEqualToConstant: minimumHeight),
      leading.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
      leading.centerYAnchor.constraint(equalTo: row.centerYAnchor),
      leading.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: 6),
      leading.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -6),
      accessory.leadingAnchor.constraint(greaterThanOrEqualTo: leading.trailingAnchor, constant: 12),
      accessory.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
      accessory.centerYAnchor.constraint(equalTo: row.centerYAnchor),
      accessory.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: 6),
      accessory.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -6)
    ])
    return row
  }

  private func toggle(action: Selector) -> NSSwitch {
    let toggle = NSSwitch()
    toggle.controlSize = .mini
    toggle.target = self
    toggle.action = action
    return toggle
  }

  private func menuPopup() -> NSPopUpButton {
    let popup = NSPopUpButton()
    popup.isBordered = false
    popup.bezelStyle = .inline
    popup.alignment = .right
    popup.font = NSFont.systemFont(ofSize: 13)
    popup.setContentHuggingPriority(.required, for: .horizontal)
    popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
    return popup
  }

  private func slider(
    value: Double,
    range: ClosedRange<Double>,
    action: Selector
  ) -> NSSlider {
    let slider = NSSlider(
      value: value,
      minValue: range.lowerBound,
      maxValue: range.upperBound,
      target: self,
      action: action
    )
    slider.widthAnchor.constraint(equalToConstant: 220).isActive = true
    return slider
  }

  private func permissionRow(
    title: String,
    requestAction: Selector,
    openSettingsAction: Selector
  ) -> (view: NSView, controls: PermissionControls) {
    let imageView = NSImageView()
    imageView.imageScaling = .scaleProportionallyDown
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.widthAnchor.constraint(equalToConstant: 16).isActive = true
    imageView.heightAnchor.constraint(equalToConstant: 16).isActive = true

    let label = NSTextField(labelWithString: title)
    label.font = NSFont.systemFont(ofSize: 13)

    let statusRow = NSStackView(views: [imageView, label])
    statusRow.orientation = .horizontal
    statusRow.alignment = .centerY
    statusRow.spacing = 6

    let requestButton = NSButton(title: "Request…", target: self, action: requestAction)
    requestButton.bezelStyle = .rounded
    let openSettingsButton = NSButton(
      title: "Open Settings",
      target: self,
      action: openSettingsAction
    )
    openSettingsButton.bezelStyle = .rounded

    let buttons = NSStackView(views: [requestButton, openSettingsButton])
    buttons.orientation = .horizontal
    buttons.alignment = .centerY
    buttons.spacing = 8

    let content = settingsRow(
      leading: statusRow,
      accessory: buttons,
      minimumHeight: 40
    )

    return (
      content,
      PermissionControls(
        imageView: imageView,
        buttons: buttons,
        requestButton: requestButton,
        openSettingsButton: openSettingsButton
      )
    )
  }

  private func refreshControls() {
    launchAtLoginSwitch.state = state(for: settings.launchAtLogin)
    showKeyboardOnLaunchSwitch.state = state(for: settings.showKeyboardOnLaunch)
    alwaysOnTopSwitch.state = state(for: settings.alwaysOnTop)
    hideDockIconSwitch.state = state(for: settings.hideDockIcon)
    updateLaunchAtLoginError()

    showLatinKeyLabelsSwitch.state = state(for: settings.showLatinKeyLabels)
    highlightPhysicalKeyPressesSwitch.state = state(
      for: settings.highlightPhysicalKeyPresses
    )
    highlightKeyHoverSwitch.state = state(for: settings.highlightKeyHover)
    keyLabelScaleSlider.doubleValue = settings.keyLabelScale
    activeApplicationRadio.state = state(for: settings.clickTarget == .activeApplication)
    textAreaRadio.state = state(for: settings.clickTarget == .textArea)

    selectItem(in: appearancePopup, representedObject: settings.appearance.rawValue)
    keyboardScaleSlider.doubleValue = settings.keyboardScale
    keyCornerRadiusSlider.doubleValue = settings.keyCornerRadius
    keyPressAnimationSwitch.state = state(for: settings.keyPressAnimation)

    updatePermissionControls()
  }

  private func updateLaunchAtLoginError() {
    launchAtLoginErrorLabel.stringValue = settings.launchAtLoginErrorMessage ?? ""
    launchAtLoginErrorLabel.isHidden = settings.launchAtLoginErrorMessage == nil
  }

  private func updatePermissionControls() {
    updatePermissionControls(
      accessibilityControls,
      isGranted: permissions.isAccessibilityGranted
    )
    updatePermissionControls(
      inputMonitoringControls,
      isGranted: permissions.isInputMonitoringGranted
    )
  }

  private func updatePermissionControls(
    _ controls: PermissionControls,
    isGranted: Bool
  ) {
    controls.imageView.image = NSImage(
      systemSymbolName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle",
      accessibilityDescription: isGranted ? "Granted" : "Permission required"
    )
    controls.imageView.contentTintColor = isGranted ? .systemGreen : .secondaryLabelColor
    controls.buttons.isHidden = isGranted
    controls.requestButton.isHidden = isGranted
    controls.openSettingsButton.isHidden = isGranted
  }

  private func state(for value: Bool) -> NSControl.StateValue {
    value ? .on : .off
  }

  private func selectItem(in popup: NSPopUpButton, representedObject: String) {
    guard let index = popup.itemArray.firstIndex(where: {
      $0.representedObject as? String == representedObject
    }) else {
      return
    }
    popup.selectItem(at: index)
  }

  @objc private func toolbarTabSelected(_ sender: NSToolbarItem) {
    guard let tab = Tab(rawValue: sender.itemIdentifier.rawValue) else {
      return
    }
    showTab(tab)
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    Tab.allCases.map { NSToolbarItem.Identifier($0.rawValue) }
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarDefaultItemIdentifiers(toolbar)
  }

  func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarDefaultItemIdentifiers(toolbar)
  }

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    guard let tab = Tab(rawValue: itemIdentifier.rawValue) else {
      return nil
    }

    let item = NSToolbarItem(itemIdentifier: itemIdentifier)
    item.label = tab.title
    item.paletteLabel = tab.title
    item.image = NSImage(
      systemSymbolName: tab.systemImage,
      accessibilityDescription: tab.title
    )
    item.target = self
    item.action = #selector(toolbarTabSelected(_:))
    return item
  }

  @objc private func launchAtLoginChanged(_ sender: NSSwitch) {
    let isEnabled = sender.state == .on
    do {
      try setLaunchAtLogin(isEnabled)
      settings.launchAtLogin = isEnabled
      settings.launchAtLoginErrorMessage = nil
    } catch {
      sender.state = state(for: settings.launchAtLogin)
      settings.launchAtLoginErrorMessage = error.localizedDescription
    }
    updateLaunchAtLoginError()
  }

  @objc private func showKeyboardOnLaunchChanged(_ sender: NSSwitch) {
    settings.showKeyboardOnLaunch = sender.state == .on
  }

  @objc private func alwaysOnTopChanged(_ sender: NSSwitch) {
    settings.alwaysOnTop = sender.state == .on
  }

  @objc private func hideDockIconChanged(_ sender: NSSwitch) {
    settings.hideDockIcon = sender.state == .on
  }

  @objc private func showLatinKeyLabelsChanged(_ sender: NSSwitch) {
    settings.showLatinKeyLabels = sender.state == .on
  }

  @objc private func highlightPhysicalKeyPressesChanged(_ sender: NSSwitch) {
    settings.highlightPhysicalKeyPresses = sender.state == .on
  }

  @objc private func highlightKeyHoverChanged(_ sender: NSSwitch) {
    settings.highlightKeyHover = sender.state == .on
  }

  @objc private func keyLabelScaleChanged(_ sender: NSSlider) {
    settings.keyLabelScale = sender.doubleValue
  }

  @objc private func clickTargetChanged(_ sender: NSButton) {
    settings.clickTarget = sender.tag == 0 ? .activeApplication : .textArea
    activeApplicationRadio.state = state(for: settings.clickTarget == .activeApplication)
    textAreaRadio.state = state(for: settings.clickTarget == .textArea)
  }

  @objc private func appearanceChanged(_ sender: NSPopUpButton) {
    guard
      let rawValue = sender.selectedItem?.representedObject as? String,
      let appearance = KeyboardAppearance(rawValue: rawValue)
    else {
      return
    }
    settings.appearance = appearance
  }

  @objc private func keyboardScaleChanged(_ sender: NSSlider) {
    settings.keyboardScale = sender.doubleValue
  }

  @objc private func keyCornerRadiusChanged(_ sender: NSSlider) {
    settings.keyCornerRadius = sender.doubleValue
  }

  @objc private func keyPressAnimationChanged(_ sender: NSSwitch) {
    settings.keyPressAnimation = sender.state == .on
  }

  @objc private func requestAccessibility() {
    permissions.requestAccessibility()
    updatePermissionControls()
  }

  @objc private func openAccessibilitySettings() {
    permissions.openAccessibilitySettings()
  }

  @objc private func requestInputMonitoring() {
    permissions.requestInputMonitoring()
    updatePermissionControls()
  }

  @objc private func openInputMonitoringSettings() {
    permissions.openInputMonitoringSettings()
  }

}
