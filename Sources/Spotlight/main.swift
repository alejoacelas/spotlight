@preconcurrency import AppKit
@preconcurrency import ServiceManagement

final class SpotlightAppDelegate: NSObject, NSApplicationDelegate {
    private let windowController = SpotlightWindowController()
    private var hotKey: GlobalHotKey!
    private var statusItem: NSStatusItem!
    private var shortcut = SpotlightShortcut(rawValue: UserDefaults.standard.string(forKey: "shortcut") ?? "") ?? .commandSpace
    private var applications: [ApplicationRecord] = []
    private var appHotKeys: [String: GlobalHotKey] = [:]
    private var appShortcuts: [String: AppShortcut] = {
        guard let data = UserDefaults.standard.data(forKey: "applicationShortcuts") else { return [:] }
        return (try? JSONDecoder().decode([String: AppShortcut].self, from: data)) ?? [:]
    }()
    private var aliases: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: "applicationAliases") as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "applicationAliases") }
    }
    private var excludedApplicationKeys: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "excludedApplications") ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: "excludedApplications") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        windowController.onLaunch = { [weak self] application in self?.open(application) }
        windowController.onRename = { [weak self] application, name in self?.rename(application, to: name) }
        windowController.onSetShortcut = { [weak self] application, shortcut in self?.setShortcut(shortcut, for: application) }
        windowController.onRemove = { [weak self] application in self?.removeFromSpotlight(application) }
        configureStatusItem()
        hotKey = GlobalHotKey { [weak self] in DispatchQueue.main.async { self?.windowController.toggle() } }
        registerShortcut(shortcut, reportFailure: true)
        registerLoginItem()
        observeApplicationUse()
        let demoQuery = CommandLine.arguments.first { $0.hasPrefix("--demo-query=") }?.dropFirst("--demo-query=".count).description
        reloadApplications(showWhenReady: CommandLine.arguments.contains("--demo") || demoQuery != nil, demoQuery: demoQuery)
    }

    func applicationWillResignActive(_ notification: Notification) {
        if windowController.window?.isVisible == true { windowController.hide() }
    }

    private func showSpotlight() {
        windowController.show()
    }

    private func reloadApplications(showWhenReady: Bool = false, demoQuery: String? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let applications = ApplicationCatalog.load()
            DispatchQueue.main.async {
                self.applications = ApplicationExclusions.applying(self.excludedApplicationKeys, to: applications)
                    .map { ApplicationAliases.applying(self.aliases, to: $0) }
                self.windowController.setApplications(self.applications)
                self.registerAppShortcuts()
                if showWhenReady {
                    self.showSpotlight()
                    if let demoQuery { self.windowController.setDemoQuery(demoQuery) }
                }
            }
        }
    }

    private func open(_ application: ApplicationRecord) {
        markRecentlyUsed(application)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: application.url, configuration: configuration) { _, error in
            if let error { self.presentError("Could not open \(application.name): \(error.localizedDescription)") }
        }
    }

    private func observeApplicationUse() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let running = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let application = self?.applications.first(where: { $0.bundleIdentifier == running.bundleIdentifier }) else { return }
            self?.markRecentlyUsed(application)
        }
    }

    private func markRecentlyUsed(_ application: ApplicationRecord) {
        applications = applications.map {
            guard $0.url == application.url else { return $0 }
            return ApplicationRecord(name: $0.name, originalName: $0.originalName, url: $0.url, bundleIdentifier: $0.bundleIdentifier, bundleVersion: $0.bundleVersion, lastUsedAt: Date())
        }
        windowController.setApplications(applications)
    }

    private func rename(_ application: ApplicationRecord, to proposedName: String) {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = ApplicationAliases.key(for: application)
        var updatedAliases = aliases
        if name.isEmpty || name == application.originalName {
            updatedAliases.removeValue(forKey: key)
        } else {
            updatedAliases[key] = name
        }
        aliases = updatedAliases
        applications = applications.map { ApplicationAliases.applying(updatedAliases, to: $0) }
        windowController.setApplications(applications)
    }

    private func removeFromSpotlight(_ application: ApplicationRecord) {
        let key = ApplicationAliases.key(for: application)
        var excluded = excludedApplicationKeys
        excluded.insert(key)
        excludedApplicationKeys = excluded
        appHotKeys[key]?.unregister()
        appHotKeys[key] = nil
        applications.removeAll { ApplicationAliases.key(for: $0) == key }
        windowController.setApplications(applications)
        configureStatusMenu()
    }

    private func setShortcut(_ shortcut: AppShortcut?, for application: ApplicationRecord) -> String? {
        let key = ApplicationAliases.key(for: application)
        let previous = appShortcuts[key]
        if previous == shortcut { return nil }

        appHotKeys[key]?.unregister()
        appHotKeys[key] = nil
        if let shortcut {
            let hotKey = GlobalHotKey { [weak self] in
                DispatchQueue.main.async { self?.open(application) }
            }
            guard hotKey.register(keyCode: shortcut.keyCode, carbonModifiers: shortcut.carbonModifiers) else {
                if let previous { restoreShortcut(previous, for: application) }
                return "\(shortcut.displayName) is already used by Spotlight, macOS, or another application."
            }
            appHotKeys[key] = hotKey
            appShortcuts[key] = shortcut
        } else {
            appShortcuts[key] = nil
        }
        persistAppShortcuts()
        windowController.setShortcuts(appShortcuts)
        return nil
    }

    private func restoreShortcut(_ shortcut: AppShortcut, for application: ApplicationRecord) {
        let key = ApplicationAliases.key(for: application)
        let hotKey = GlobalHotKey { [weak self] in DispatchQueue.main.async { self?.open(application) } }
        if hotKey.register(keyCode: shortcut.keyCode, carbonModifiers: shortcut.carbonModifiers) {
            appHotKeys[key] = hotKey
        }
    }

    private func registerAppShortcuts() {
        appHotKeys.removeAll()
        var unavailable: [String] = []
        for application in applications {
            let key = ApplicationAliases.key(for: application)
            guard let shortcut = appShortcuts[key] else { continue }
            let hotKey = GlobalHotKey { [weak self] in DispatchQueue.main.async { self?.open(application) } }
            if hotKey.register(keyCode: shortcut.keyCode, carbonModifiers: shortcut.carbonModifiers) {
                appHotKeys[key] = hotKey
            } else {
                unavailable.append("\(shortcut.displayName) for \(application.name)")
            }
        }
        windowController.setShortcuts(appShortcuts)
        if !unavailable.isEmpty { presentError("These shortcuts could not be registered: \(unavailable.joined(separator: ", ")).") }
    }

    private func persistAppShortcuts() {
        if let data = try? JSONEncoder().encode(appShortcuts) {
            UserDefaults.standard.set(data, forKey: "applicationShortcuts")
        }
    }

    private func registerShortcut(_ shortcut: SpotlightShortcut, reportFailure: Bool) {
        let previous = self.shortcut
        guard hotKey.register(shortcut) else {
            _ = hotKey.register(previous)
            if reportFailure { presentError("\(shortcut.title) is already in use. Choose the other shortcut from the Spotlight menu.") }
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
            presentError("Spotlight could not start at login: \(error.localizedDescription)")
        }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Spotlight")
        configureStatusMenu()
    }

    private func configureStatusMenu() {
        guard statusItem != nil else { return }
        let menu = NSMenu()
        let openItem = menu.addItem(withTitle: "Open Spotlight", action: #selector(openFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(.separator())
        for choice in SpotlightShortcut.allCases {
            let item = menu.addItem(withTitle: choice.title, action: #selector(changeShortcut(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.rawValue
            item.state = choice == shortcut ? .on : .off
        }
        menu.addItem(.separator())
        let refresh = menu.addItem(withTitle: "Refresh Applications", action: #selector(refreshFromMenu), keyEquivalent: "")
        refresh.target = self
        let restore = menu.addItem(withTitle: "Restore Removed Applications", action: #selector(restoreRemovedApplications), keyEquivalent: "")
        restore.target = self
        restore.isEnabled = !excludedApplicationKeys.isEmpty
        let login = menu.addItem(withTitle: "Start at Login", action: nil, keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        login.isEnabled = false
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit Spotlight", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        statusItem.menu = menu
    }

    @objc private func openFromMenu() { showSpotlight() }
    @objc private func refreshFromMenu() { reloadApplications() }
    @objc private func restoreRemovedApplications() {
        excludedApplicationKeys = []
        configureStatusMenu()
        reloadApplications()
    }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func changeShortcut(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String, let shortcut = SpotlightShortcut(rawValue: rawValue) else { return }
        registerShortcut(shortcut, reportFailure: true)
    }

    private func presentError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Spotlight"
            alert.informativeText = message
            alert.runModal()
        }
    }
}

let application = NSApplication.shared
let delegate = SpotlightAppDelegate()
application.delegate = delegate
application.run()
