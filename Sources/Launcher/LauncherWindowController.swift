import AppKit

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class LauncherWindowController: NSWindowController, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let emptyLabel = NSTextField(labelWithString: "No matching applications")
    private var applications: [ApplicationRecord] = []
    private var matches: [ApplicationMatch] = []
    private var launchedForQuery: String?
    var onLaunch: ((ApplicationRecord) -> Void)?

    init() {
        let panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)
        configureWindow(panel)
        configureContent()
    }

    required init?(coder: NSCoder) { nil }

    func setApplications(_ applications: [ApplicationRecord]) {
        self.applications = applications
        updateResults()
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
              let exact = LauncherModel.uniqueExactMatch(query: query, applications: applications) else { return }
        launchedForQuery = query
        launch(exact)
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
        let cell = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView) ?? makeCell(identifier: identifier)
        let match = matches[row]
        cell.textField?.stringValue = match.application.name
        cell.imageView?.image = NSWorkspace.shared.icon(forFile: match.application.url.path)
        cell.imageView?.imageScaling = .scaleProportionallyUpOrDown
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
        effect.layer?.cornerRadius = 18
        effect.layer?.masksToBounds = true
        window.contentView = effect

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.font = .systemFont(ofSize: 26, weight: .regular)
        searchField.focusRingType = .none
        searchField.placeholderString = "Open an application"
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Application"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 46
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(doubleClicked)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = .systemFont(ofSize: 15)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.isHidden = true

        effect.addSubview(searchField)
        effect.addSubview(scrollView)
        effect.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: effect.topAnchor, constant: 18),
            searchField.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 18),
            searchField.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -18),
            searchField.heightAnchor.constraint(equalToConstant: 48),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -12),
            emptyLabel.centerXAnchor.constraint(equalTo: effect.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let icon = NSImageView()
        let label = NSTextField(labelWithString: "")
        icon.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.lineBreakMode = .byTruncatingMiddle
        cell.addSubview(icon)
        cell.addSubview(label)
        cell.imageView = icon
        cell.textField = label
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 32),
            icon.heightAnchor.constraint(equalToConstant: 32),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
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
        let newHeight = min(560, max(104, 84 + CGFloat(resultCount) * 48))
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

    private func launch(_ application: ApplicationRecord) {
        hide()
        onLaunch?(application)
    }
}
