@preconcurrency import AppKit
@preconcurrency import ServiceManagement

final class SpotlightAppDelegate: NSObject, NSApplicationDelegate {
    private let windowController = SpotlightWindowController()
    private var hotKey: GlobalHotKey?
    private var statusItem: NSStatusItem!
    private var desiredShortcut = LauncherShortcut(
        rawValue: UserDefaults.standard.string(forKey: "shortcut") ?? ""
    ) ?? .commandSpace
    private var registeredShortcut: LauncherShortcut?
    private var mainShortcutError: String?
    private var applications: [ApplicationRecord] = []
    private var appHotKeys: [String: GlobalHotKey] = [:]
    private var appShortcutApplications: [String: URL] = [:]
    private var appShortcuts: [String: AppShortcut] = [:]
    private var unavailableAppShortcutKeys = Set<String>()
    private var lifecycleObservers: [NSObjectProtocol] = []
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
        let shortcutLoad = LauncherPreferences.loadAppShortcuts()
        appShortcuts = shortcutLoad.shortcuts
        windowController.onLaunch = { [weak self] application in self?.open(application) }
        windowController.onRename = { [weak self] application, name in self?.rename(application, to: name) }
        windowController.onSetShortcut = { [weak self] application, shortcut in self?.setShortcut(shortcut, for: application) }
        windowController.onRemove = { [weak self] application in self?.removeFromSpotlight(application) }
        configureStatusItem()
        installMainHotKey(reportFailure: true)
        registerLoginItem()
        observeApplicationUse()
        observeShortcutLifecycle()
        if shortcutLoad.resetCorruptValue {
            presentError("Saved application shortcuts were invalid and have been reset.")
        }
        let demoQuery = CommandLine.arguments.first { $0.hasPrefix("--demo-query=") }?.dropFirst("--demo-query=".count).description
        reloadApplications(showWhenReady: CommandLine.arguments.contains("--demo") || demoQuery != nil, demoQuery: demoQuery)
    }

    func applicationWillResignActive(_ notification: Notification) {
        if windowController.window?.isVisible == true, windowController.window?.attachedSheet == nil {
            windowController.hide()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        for observer in lifecycleObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
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
                self.registerAppShortcuts(reportFailures: true)
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
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let running = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let application = self?.applications.first(where: { $0.bundleIdentifier == running.bundleIdentifier }) else { return }
            self?.markRecentlyUsed(application)
        }
        lifecycleObservers.append(observer)
    }

    private func observeShortcutLifecycle() {
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            let observer = NSWorkspace.shared.notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.retryUnavailableShortcuts()
            }
            lifecycleObservers.append(observer)
        }
    }

    private func retryUnavailableShortcuts() {
        if registeredShortcut == nil { installMainHotKey(reportFailure: false) }
        if !unavailableAppShortcutKeys.isEmpty { registerAppShortcuts(reportFailures: false) }
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
        appHotKeys[key] = nil
        appShortcutApplications[key] = nil
        unavailableAppShortcutKeys.remove(key)
        applications.removeAll { ApplicationAliases.key(for: $0) == key }
        windowController.setApplications(applications)
        windowController.setShortcuts(appShortcuts, unavailable: unavailableAppShortcutKeys)
        configureStatusMenu()
    }

    private func setShortcut(_ shortcut: AppShortcut?, for application: ApplicationRecord) -> String? {
        let key = ApplicationAliases.key(for: application)
        let previous = appShortcuts[key]
        if previous == shortcut { return nil }

        if let shortcut {
            do {
                let candidate = try makeAppHotKey(for: application)
                guard candidate.register(keyCode: shortcut.keyCode, carbonModifiers: shortcut.carbonModifiers) else {
                    return "\(shortcut.displayName) is already used by Launcher, macOS, or another application."
                }
                appHotKeys[key] = candidate
                appShortcutApplications[key] = application.url
                appShortcuts[key] = shortcut
                unavailableAppShortcutKeys.remove(key)
            } catch {
                return error.localizedDescription
            }
        } else {
            appHotKeys[key] = nil
            appShortcutApplications[key] = nil
            appShortcuts[key] = nil
            unavailableAppShortcutKeys.remove(key)
        }
        LauncherPreferences.saveAppShortcuts(appShortcuts)
        windowController.setShortcuts(appShortcuts, unavailable: unavailableAppShortcutKeys)
        return nil
    }

    private func registerAppShortcuts(reportFailures: Bool) {
        let applicationsByKey = Dictionary(uniqueKeysWithValues: applications.map {
            (ApplicationAliases.key(for: $0), $0)
        })
        for key in Array(appHotKeys.keys) where appShortcuts[key] == nil || applicationsByKey[key] == nil || appShortcutApplications[key] != applicationsByKey[key]?.url {
            appHotKeys[key] = nil
            appShortcutApplications[key] = nil
        }

        var unavailable: [String] = []
        for key in appShortcuts.keys.sorted() {
            guard let shortcut = appShortcuts[key] else { continue }
            guard let application = applicationsByKey[key], appHotKeys[key] == nil else { continue }
            do {
                let candidate = try makeAppHotKey(for: application)
                if candidate.register(keyCode: shortcut.keyCode, carbonModifiers: shortcut.carbonModifiers) {
                    appHotKeys[key] = candidate
                    appShortcutApplications[key] = application.url
                    unavailableAppShortcutKeys.remove(key)
                } else {
                    unavailableAppShortcutKeys.insert(key)
                    unavailable.append("\(shortcut.displayName) for \(application.name)")
                }
            } catch {
                unavailableAppShortcutKeys.insert(key)
                unavailable.append("\(shortcut.displayName) for \(application.name): \(error.localizedDescription)")
            }
        }
        windowController.setShortcuts(appShortcuts, unavailable: unavailableAppShortcutKeys)
        if reportFailures, !unavailable.isEmpty {
            presentError("These shortcuts could not be registered: \(unavailable.joined(separator: ", ")).")
        }
    }

    private func makeAppHotKey(for application: ApplicationRecord) throws -> GlobalHotKey {
        try GlobalHotKey { [weak self] in
            DispatchQueue.main.async { self?.open(application) }
        }
    }

    private func installMainHotKey(reportFailure: Bool) {
        do {
            if hotKey == nil {
                hotKey = try GlobalHotKey { [weak self] in
                    DispatchQueue.main.async { self?.windowController.toggle() }
                }
            }
            guard let hotKey, hotKey.register(desiredShortcut) else {
                mainShortcutError = "\(desiredShortcut.title) is already in use by macOS or another application."
                registeredShortcut = nil
                configureStatusMenu()
                if reportFailure, let mainShortcutError { presentError(mainShortcutError) }
                return
            }
            registeredShortcut = desiredShortcut
            mainShortcutError = nil
            configureStatusMenu()
        } catch {
            hotKey = nil
            registeredShortcut = nil
            mainShortcutError = error.localizedDescription
            configureStatusMenu()
            if reportFailure { presentError(error.localizedDescription) }
        }
    }

    private func changeMainShortcut(to shortcut: LauncherShortcut) {
        guard let hotKey, hotKey.register(shortcut) else {
            presentError("\(shortcut.title) is already in use. \(desiredShortcut.title) remains active.")
            return
        }
        desiredShortcut = shortcut
        registeredShortcut = shortcut
        mainShortcutError = nil
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
            let unavailable = choice == desiredShortcut && registeredShortcut == nil
            let title = unavailable ? "\(choice.title) — unavailable" : choice.title
            let item = menu.addItem(withTitle: title, action: #selector(changeShortcut(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.rawValue
            item.state = choice == registeredShortcut ? .on : .off
        }
        if let mainShortcutError {
            let error = menu.addItem(withTitle: mainShortcutError, action: nil, keyEquivalent: "")
            error.isEnabled = false
        }
        if !unavailableAppShortcutKeys.isEmpty {
            let count = unavailableAppShortcutKeys.count
            let label = menu.addItem(
                withTitle: "\(count) application shortcut\(count == 1 ? "" : "s") unavailable",
                action: nil,
                keyEquivalent: ""
            )
            label.isEnabled = false
        }
        menu.addItem(.separator())
        let refresh = menu.addItem(withTitle: "Refresh Applications", action: #selector(refreshFromMenu), keyEquivalent: "")
        refresh.target = self
        let restore = menu.addItem(withTitle: "Restore Removed Applications", action: #selector(restoreRemovedApplications), keyEquivalent: "")
        restore.target = self
        restore.isEnabled = !excludedApplicationKeys.isEmpty
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit Launcher", action: #selector(quit), keyEquivalent: "q")
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
        guard let rawValue = sender.representedObject as? String,
              let shortcut = LauncherShortcut(rawValue: rawValue) else { return }
        changeMainShortcut(to: shortcut)
    }

    private func presentError(_ message: String) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Launcher"
            alert.informativeText = message
            alert.runModal()
        }
    }
}

let application = NSApplication.shared
let delegate = SpotlightAppDelegate()
application.delegate = delegate
application.run()
