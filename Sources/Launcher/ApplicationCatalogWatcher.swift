import CoreServices
import Foundation

final class ApplicationCatalogWatcher {
    private let roots: [URL]
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?
    private var debounceWorkItem: DispatchWorkItem?

    init(roots: [URL] = ApplicationCatalog.applicationRoots(), onChange: @escaping () -> Void) {
        self.roots = roots
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        guard stream == nil else { return true }
        let paths = roots.map(\.path).filter { FileManager.default.fileExists(atPath: $0) }
        guard !paths.isEmpty else { return false }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, count, _, flags, _ in
            guard let info else { return }
            let watcher = Unmanaged<ApplicationCatalogWatcher>.fromOpaque(info).takeUnretainedValue()
            for index in 0..<count {
                let relevant = flags[index] & (
                    UInt32(kFSEventStreamEventFlagMustScanSubDirs)
                        | UInt32(kFSEventStreamEventFlagRootChanged)
                        | UInt32(kFSEventStreamEventFlagItemCreated)
                        | UInt32(kFSEventStreamEventFlagItemRemoved)
                        | UInt32(kFSEventStreamEventFlagItemRenamed)
                        | UInt32(kFSEventStreamEventFlagItemInodeMetaMod)
                )
                if relevant != 0 {
                    watcher.scheduleChange()
                    return
                }
            }
        }

        guard let created = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagFileEvents
                    | kFSEventStreamCreateFlagUseCFTypes
                    | kFSEventStreamCreateFlagWatchRoot
            )
        ) else { return false }

        stream = created
        FSEventStreamSetDispatchQueue(created, DispatchQueue.global(qos: .utility))
        guard FSEventStreamStart(created) else {
            stop()
            return false
        }
        return true
    }

    func restart() {
        stop()
        _ = start()
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func scheduleChange() {
        DispatchQueue.main.async {
            self.debounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in self?.onChange() }
            self.debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: workItem)
        }
    }
}
