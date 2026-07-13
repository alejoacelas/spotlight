@preconcurrency import AppKit
@preconcurrency import ServiceManagement

final class LauncherAppDelegate: NSObject, NSApplicationDelegate {
    private let windowController = LauncherWindowController()
    private var hotKey: GlobalHotKey!
    private var statusItem: NSStatusItem!
    private var shortcut = LauncherShortcut(rawValue: UserDefaults.standard.string(forKey: "shortcut") ?? "") ?? .commandSpace
    private var applications: [ApplicationRecord] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        windowController.onLaunch = { [weak self] application in self?.open(application) }
        configureStatusItem()
        hotKey = GlobalHotKey { [weak self] in DispatchQueue.main.async { self?.showLauncher() } }
        registerShortcut(shortcut, reportFailure: true)
        registerLoginItem()
        let demoQuery = CommandLine.arguments.first { $0.hasPrefix("--demo-query=") }?.dropFirst("--demo-query=".count).description
        reloadApplications(showWhenReady: CommandLine.arguments.contains("--demo") || demoQuery != nil, demoQuery: demoQuery)
    }

    func applicationWillResignActive(_ notification: Notification) {
        if windowController.window?.isVisible == true { windowController.hide() }
    }

    private func showLauncher() {
        windowController.show()
    }

    private func reloadApplications(showWhenReady: Bool = false, demoQuery: String? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let applications = ApplicationCatalog.load()
            DispatchQueue.main.async {
                self.applications = applications
                self.windowController.setApplications(applications)
                if showWhenReady {
                    self.showLauncher()
                    if let demoQuery { self.windowController.setDemoQuery(demoQuery) }
                }
            }
        }
    }

    private func open(_ application: ApplicationRecord) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: application.url, configuration: configuration) { _, error in
            if let error { self.presentError("Could not open \(application.name): \(error.localizedDescription)") }
        }
    }

    private func registerShortcut(_ shortcut: LauncherShortcut, reportFailure: Bool) {
        let previous = self.shortcut
        guard hotKey.register(shortcut) else {
            _ = hotKey.register(previous)
            if reportFailure { presentError("\(shortcut.title) is already in use. Choose the other shortcut from the Launcher menu.") }
            return
        }
        self.shortcut = shortcut
        UserDefaults.standard.set(shortcut.rawValue, forKey: "shortcut")
        configureStatusMenu()
    }

    private func registerLoginItem() {
        do {
            if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
        } catch {
            presentError("Launcher could not start at login: \(error.localizedDescription)")
        }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Launcher")
        configureStatusMenu()
    }

    private func configureStatusMenu() {
        guard statusItem != nil else { return }
        let menu = NSMenu()
        let openItem = menu.addItem(withTitle: "Open Launcher", action: #selector(openFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(.separator())
        for choice in LauncherShortcut.allCases {
            let item = menu.addItem(withTitle: choice.title, action: #selector(changeShortcut(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.rawValue
            item.state = choice == shortcut ? .on : .off
        }
        menu.addItem(.separator())
        let refresh = menu.addItem(withTitle: "Refresh Applications", action: #selector(refreshFromMenu), keyEquivalent: "")
        refresh.target = self
        let login = menu.addItem(withTitle: "Start at Login", action: nil, keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        login.isEnabled = false
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit Launcher", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        statusItem.menu = menu
    }

    @objc private func openFromMenu() { showLauncher() }
    @objc private func refreshFromMenu() { reloadApplications() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func changeShortcut(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String, let shortcut = LauncherShortcut(rawValue: rawValue) else { return }
        registerShortcut(shortcut, reportFailure: true)
    }

    private func presentError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Launcher"
            alert.informativeText = message
            alert.runModal()
        }
    }
}

let application = NSApplication.shared
let delegate = LauncherAppDelegate()
application.delegate = delegate
application.run()
