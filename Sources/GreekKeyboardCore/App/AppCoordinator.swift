import AppKit
import Combine
import Foundation

@MainActor
final class AppCoordinator: NSObject, NSMenuDelegate {
  private let settings: SettingsStore
  private let permissions: MacPermissionAdapter
  private let inputMonitor: MacKeyboardInputMonitorAdapter
  private let launchAtLoginService: MacLaunchAtLoginAdapter
  private let keyboardWindowController: KeyboardWindowController
  private let settingsWindowController: SettingsWindowController
  private let statusItem: NSStatusItem
  private let statusMenu = NSMenu()

  private var cancellables = Set<AnyCancellable>()
  private var showMenuItem: NSMenuItem?
  private var hideMenuItem: NSMenuItem?
  private var alwaysOnTopMenuItem: NSMenuItem?
  private var latinLabelsMenuItem: NSMenuItem?

  override init() {
    let settings = SettingsStore()
    let permissions = MacPermissionAdapter()
    let applicationTracker = MacActiveApplicationAdapter()
    let inputMonitor = MacKeyboardInputMonitorAdapter()
    let launchAtLoginService = MacLaunchAtLoginAdapter()
    let viewModel = KeyboardViewModel(
      layout: .greekMonotonic,
      settings: settings,
      insertionService: MacTextInsertionAdapter(),
      applicationTracker: applicationTracker
    )
    let keyboardWindowController = KeyboardWindowController(
      viewModel: viewModel,
      settings: settings,
      permissions: permissions
    )
    let settingsWindowController = SettingsWindowController(
      settings: settings,
      permissions: permissions,
      setLaunchAtLogin: launchAtLoginService.setEnabled
    )

    self.settings = settings
    self.permissions = permissions
    self.inputMonitor = inputMonitor
    self.launchAtLoginService = launchAtLoginService
    self.keyboardWindowController = keyboardWindowController
    self.settingsWindowController = settingsWindowController
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    super.init()

    settings.launchAtLogin = launchAtLoginService.isEnabled
    configureApplication()
    configureKeyboardWindow()
    configureInputMonitoring(viewModel: viewModel)
    configureMenuBar()
    observeSettings()
    observeSystemChanges()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  func start() {
    refreshPermissionsAndMonitoring()
    if settings.showKeyboardOnLaunch {
      keyboardWindowController.show()
    }
  }

  func handleReopen() {
    keyboardWindowController.show()
  }

  func menuWillOpen(_ menu: NSMenu) {
    let isVisible = keyboardWindowController.isVisible
    showMenuItem?.isEnabled = !isVisible
    hideMenuItem?.isEnabled = isVisible
    alwaysOnTopMenuItem?.state = settings.alwaysOnTop ? .on : .off
    latinLabelsMenuItem?.state = settings.showLatinKeyLabels ? .on : .off
  }

  private func configureApplication() {
    NSApp.setActivationPolicy(settings.hideDockIcon ? .accessory : .regular)
  }

  private func configureKeyboardWindow() {
    keyboardWindowController.setAlwaysOnTop(settings.alwaysOnTop)
    keyboardWindowController.setAppearance(settings.appearance)
    keyboardWindowController.onVisibilityChanged = { [weak self] isVisible in
      self?.settings.setKeyboardVisible(isVisible)
    }
    keyboardWindowController.onOpenSettings = { [weak self] in
      self?.showSettings()
    }
  }

  private func configureInputMonitoring(viewModel: KeyboardViewModel) {
    inputMonitor.onEvent = { [weak viewModel] event in
      viewModel?.handlePhysicalInput(event)
    }
    inputMonitor.startLocalMonitoring()
  }

  private func configureMenuBar() {
    if let button = statusItem.button {
      button.title = "Ω"
      button.toolTip = L10n.text("app.name", value: "Greekboard")
      button.setAccessibilityLabel(
        L10n.text("app.name", value: "Greekboard")
      )
      button.target = self
      button.action = #selector(statusItemClicked(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    statusMenu.delegate = self

    let showItem = item("Show Keyboard", action: #selector(showKeyboard))
    let hideItem = item("Hide Keyboard", action: #selector(hideKeyboard))
    let alwaysOnTopItem = item("Always on Top", action: #selector(toggleAlwaysOnTop))
    let latinLabelsItem = item(
      "Show Latin Key Labels",
      action: #selector(toggleLatinLabels)
    )
    showMenuItem = showItem
    hideMenuItem = hideItem
    alwaysOnTopMenuItem = alwaysOnTopItem
    latinLabelsMenuItem = latinLabelsItem

    statusMenu.addItem(showItem)
    statusMenu.addItem(hideItem)
    statusMenu.addItem(.separator())
    statusMenu.addItem(alwaysOnTopItem)
    statusMenu.addItem(latinLabelsItem)
    statusMenu.addItem(.separator())
    statusMenu.addItem(item("Settings…", action: #selector(showSettings)))
    statusMenu.addItem(item("About Greekboard", action: #selector(showAbout)))
    statusMenu.addItem(.separator())
    statusMenu.addItem(item("Quit", action: #selector(quit)))
  }

  private func observeSettings() {
    settings.$alwaysOnTop
      .dropFirst()
      .sink { [weak self] isEnabled in
        self?.keyboardWindowController.setAlwaysOnTop(isEnabled)
      }
      .store(in: &cancellables)

    settings.$hideDockIcon
      .dropFirst()
      .sink { isHidden in
        NSApp.setActivationPolicy(isHidden ? .accessory : .regular)
      }
      .store(in: &cancellables)

    settings.$appearance
      .dropFirst()
      .sink { [weak self] appearance in
        self?.keyboardWindowController.setAppearance(appearance)
        self?.settingsWindowController.setAppearance(appearance)
      }
      .store(in: &cancellables)

    settings.$highlightPhysicalKeyPresses
      .dropFirst()
      .sink { [weak self] _ in
        self?.refreshPermissionsAndMonitoring()
      }
      .store(in: &cancellables)

    settings.$keyboardScale
      .dropFirst()
      .removeDuplicates()
      .sink { [weak self] scale in
        self?.keyboardWindowController.resize(to: scale)
      }
      .store(in: &cancellables)
  }

  private func observeSystemChanges() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: NSApplication.didBecomeActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenParametersDidChange),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(workspaceDidWake),
      name: NSWorkspace.didWakeNotification,
      object: nil
    )
  }

  private func refreshPermissionsAndMonitoring() {
    permissions.refresh()
    inputMonitor.setGlobalMonitoringEnabled(
      permissions.isInputMonitoringGranted && settings.highlightPhysicalKeyPresses
    )
  }

  private func item(_ title: String, action: Selector) -> NSMenuItem {
    let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
    menuItem.target = self
    return menuItem
  }

  @objc
  private func statusItemClicked(_ sender: Any?) {
    guard let event = NSApp.currentEvent else { return }

    let isRightClick =
      event.type == .rightMouseUp || event.modifierFlags.contains(.control)
    if isRightClick {
      showStatusMenu()
      return
    }

    toggleKeyboard()
  }

  private func showStatusMenu() {
    guard let button = statusItem.button else { return }
    let location = NSPoint(x: 0, y: button.bounds.maxY + 2)
    statusMenu.popUp(positioning: nil, at: location, in: button)
  }

  private func toggleKeyboard() {
    if keyboardWindowController.isVisible {
      keyboardWindowController.hide()
    } else {
      keyboardWindowController.show()
    }
  }

  @objc
  private func showKeyboard() {
    keyboardWindowController.show()
  }

  @objc
  private func hideKeyboard() {
    keyboardWindowController.hide()
  }

  @objc
  private func toggleAlwaysOnTop() {
    settings.alwaysOnTop.toggle()
  }

  @objc
  private func toggleLatinLabels() {
    settings.showLatinKeyLabels.toggle()
  }

  @objc
  private func showSettings() {
    permissions.refresh()
    settingsWindowController.setAppearance(settings.appearance)
    settingsWindowController.show()
  }

  @objc
  private func showAbout() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(nil)
  }

  @objc
  private func quit() {
    NSApp.terminate(nil)
  }

  @objc
  private func applicationDidBecomeActive() {
    refreshPermissionsAndMonitoring()
  }

  @objc
  private func workspaceDidWake() {
    refreshPermissionsAndMonitoring()
  }

  @objc
  private func screenParametersDidChange() {
    keyboardWindowController.ensureVisibleOnScreen()
  }
}
