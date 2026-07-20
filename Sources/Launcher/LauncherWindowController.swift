import AppKit

final class LauncherPanel: NSPanel {
    var renameAction: (() -> Void)?
    var actionsAction: (() -> Void)?
    var openIndexAction: ((Int) -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           let key = event.charactersIgnoringModifiers?.lowercased() {
            if key == "r" { renameAction?(); return true }
            if key == "k" { actionsAction?(); return true }
            if let number = Int(key), (1...6).contains(number) { openIndexAction?(number - 1); return true }
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class ApplicationCellView: NSTableCellView {
    let commandLabel = NSTextField(labelWithString: "")
}

final class LauncherWindowController: NSWindowController, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let emptyLabel = NSTextField(labelWithString: "No matching applications")
    private var applications: [ApplicationRecord] = []
    private var matches: [ApplicationMatch] = []
    private var shortcuts: [String: AppShortcut] = [:]
    private var launchedForQuery: String?
    var onLaunch: ((ApplicationRecord) -> Void)?
    var onRename: ((ApplicationRecord, String) -> Void)?
    var onSetShortcut: ((ApplicationRecord, AppShortcut?) -> String?)?
    var onRemove: ((ApplicationRecord) -> Void)?

    init() {
        let panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 274),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)
        panel.renameAction = { [weak self] in self?.promptForActionsSelected() }
        panel.actionsAction = { [weak self] in self?.promptForActionsSelected() }
        panel.openIndexAction = { [weak self] index in self?.launch(at: index) }
        configureWindow(panel)
        configureContent()
    }

    required init?(coder: NSCoder) { nil }

    func setApplications(_ applications: [ApplicationRecord]) {
        self.applications = applications
        updateResults()
    }

    func setShortcuts(_ shortcuts: [String: AppShortcut]) {
        self.shortcuts = shortcuts
        tableView.reloadData()
    }

    func toggle() {
        window?.isVisible == true ? hide() : show()
    }

    func show() {
        guard let window else { return }
        launchedForQuery = nil
        searchField.stringValue = ""
        updateResults()
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        if let visibleFrame = screen?.visibleFrame {
            window.setFrameOrigin(NSPoint(x: visibleFrame.midX - window.frame.width / 2, y: visibleFrame.maxY - window.frame.height - 110))
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(searchField)
    }

    func hide() {
        if let sheet = window?.attachedSheet { window?.endSheet(sheet, returnCode: .abort) }
        window?.orderOut(nil)
        searchField.stringValue = ""
    }

    func controlTextDidChange(_ obj: Notification) {
        queryDidChange()
    }

    func setDemoQuery(_ query: String) {
        searchField.stringValue = query
        queryDidChange()
    }

    private func queryDidChange() {
        updateResults()
        let query = searchField.stringValue
        guard launchedForQuery != query,
              let match = LauncherModel.uniqueMatch(query: query, matches: matches) else { return }
        launchedForQuery = query
        launch(match)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1)
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1)
        case #selector(NSResponder.insertNewline(_:)):
            launchSelected()
        case #selector(NSResponder.cancelOperation(_:)):
            hide()
        default:
            return false
        }
        return true
    }

    func numberOfRows(in tableView: NSTableView) -> Int { matches.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ApplicationCell")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: self) as? ApplicationCellView) ?? makeCell(identifier: identifier)
        let match = matches[row]
        cell.textField?.stringValue = match.application.name
        cell.imageView?.image = NSWorkspace.shared.icon(forFile: match.application.url.path)
        cell.imageView?.imageScaling = .scaleProportionallyUpOrDown
        let rowCommand = "⌘\(row + 1)"
        if let shortcut = shortcuts[ApplicationAliases.key(for: match.application)] {
            cell.commandLabel.stringValue = "\(shortcut.displayName)   \(rowCommand)"
        } else {
            cell.commandLabel.stringValue = rowCommand
        }
        cell.toolTip = match.application.url.path
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if tableView.selectedRow < 0, !matches.isEmpty { tableView.selectRowIndexes([0], byExtendingSelection: false) }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:
            hide()
        case 36, 76:
            launchSelected()
        case 125:
            moveSelection(by: 1)
        case 126:
            moveSelection(by: -1)
        default:
            super.keyDown(with: event)
        }
    }

    @objc private func doubleClicked() { launchSelected() }

    private func configureWindow(_ panel: NSPanel) {
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
    }

    private func configureContent() {
        guard let window else { return }
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true
        window.contentView = effect

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.font = .systemFont(ofSize: 18, weight: .regular)
        searchField.controlSize = .large
        searchField.focusRingType = .none
        searchField.placeholderString = "Open an application — ⌘K actions"
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Application"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 34
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(doubleClicked)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.isHidden = true

        effect.addSubview(searchField)
        effect.addSubview(scrollView)
        effect.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: effect.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 14),
            searchField.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -14),
            searchField.heightAnchor.constraint(equalToConstant: 38),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -8),
            emptyLabel.centerXAnchor.constraint(equalTo: effect.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> ApplicationCellView {
        let cell = ApplicationCellView()
        cell.identifier = identifier
        let icon = NSImageView()
        let label = NSTextField(labelWithString: "")
        icon.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.lineBreakMode = .byTruncatingMiddle
        cell.commandLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.commandLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        cell.commandLabel.textColor = .secondaryLabelColor
        cell.commandLabel.alignment = .right
        cell.addSubview(icon)
        cell.addSubview(label)
        cell.addSubview(cell.commandLabel)
        cell.imageView = icon
        cell.textField = label
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(lessThanOrEqualTo: cell.commandLabel.leadingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            cell.commandLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
            cell.commandLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            cell.commandLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
        ])
        return cell
    }

    private func updateResults() {
        matches = LauncherModel.matches(query: searchField.stringValue, applications: applications)
        resizeWindow(for: matches.count)
        tableView.reloadData()
        emptyLabel.isHidden = !matches.isEmpty
        if matches.isEmpty {
            tableView.deselectAll(nil)
        } else {
            tableView.selectRowIndexes([0], byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
    }

    private func resizeWindow(for resultCount: Int) {
        guard let window else { return }
        let newHeight = min(274, max(88, 64 + CGFloat(resultCount) * 35))
        guard window.frame.height != newHeight else { return }
        var frame = window.frame
        frame.origin.y += frame.height - newHeight
        frame.size.height = newHeight
        window.setFrame(frame, display: true)
    }

    private func moveSelection(by offset: Int) {
        guard !matches.isEmpty else { return }
        let current = max(0, tableView.selectedRow)
        let next = min(max(current + offset, 0), matches.count - 1)
        tableView.selectRowIndexes([next], byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    private func launchSelected() {
        guard matches.indices.contains(tableView.selectedRow) else { return }
        launch(matches[tableView.selectedRow].application)
    }

    private func launch(at index: Int) {
        guard matches.indices.contains(index) else { return }
        launch(matches[index].application)
    }

    private func selectedApplication() -> ApplicationRecord? {
        guard matches.indices.contains(tableView.selectedRow) else { return nil }
        return matches[tableView.selectedRow].application
    }

    private func promptForActionsSelected() {
        guard let application = selectedApplication(), let window else { return }
        let alert = NSAlert()
        alert.messageText = application.name
        alert.informativeText = "Choose an action for this application."
        alert.addButton(withTitle: "Rename…")
        alert.addButton(withTitle: "Assign Shortcut…")
        alert.addButton(withTitle: "Remove from Launcher")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            DispatchQueue.main.async {
                if response == .alertFirstButtonReturn { self.promptToRename(application) }
                if response == .alertSecondButtonReturn { self.promptToSetShortcut(application) }
                if response == .alertThirdButtonReturn { self.onRemove?(application) }
            }
        }
    }

    private func promptToRename(_ application: ApplicationRecord) {
        guard let window else { return }
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.stringValue = application.name

        let alert = NSAlert()
        alert.messageText = "Rename \(application.originalName)"
        alert.informativeText = "This changes its name only in Launcher. Leave it empty to restore the original name."
        alert.accessoryView = input
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        alert.beginSheetModal(for: window) { [weak self, weak window] response in
            guard let self else { return }
            if response == .alertFirstButtonReturn { self.onRename?(application, input.stringValue) }
            window?.makeKeyAndOrderFront(nil)
            window?.makeFirstResponder(self.searchField)
        }
    }

    private func promptToSetShortcut(_ application: ApplicationRecord) {
        guard let window else { return }
        let key = ApplicationAliases.key(for: application)
        let recorder = ShortcutRecorderView(shortcut: shortcuts[key])
        let alert = NSAlert()
        alert.messageText = "Shortcut for \(application.name)"
        alert.informativeText = "Press a shortcut with Control, Option, or Command. It will open the app from anywhere."
        alert.accessoryView = recorder
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].isEnabled = recorder.shortcut != nil
        alert.buttons[1].isEnabled = shortcuts[key] != nil
        recorder.onChange = { shortcut in alert.buttons[0].isEnabled = shortcut != nil }
        alert.beginSheetModal(for: window) { [weak self, weak window] response in
            guard let self else { return }
            let shortcut: AppShortcut?
            if response == .alertFirstButtonReturn { shortcut = recorder.shortcut }
            else if response == .alertSecondButtonReturn { shortcut = nil }
            else { return }
            if let error = self.onSetShortcut?(application, shortcut) {
                DispatchQueue.main.async { self.showError(error, on: window) }
            }
        }
        DispatchQueue.main.async { alert.window.makeFirstResponder(recorder) }
    }

    private func showError(_ message: String, on window: NSWindow?) {
        guard let window, window.isVisible else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Shortcut unavailable"
        alert.informativeText = message
        alert.beginSheetModal(for: window)
    }

    private func launch(_ application: ApplicationRecord) {
        hide()
        onLaunch?(application)
    }
}
