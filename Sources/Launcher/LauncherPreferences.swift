import Foundation

enum LauncherPreferences {
    struct ShortcutLoad {
        let shortcuts: [String: AppShortcut]
        let resetCorruptValue: Bool
    }

    static func loadAppShortcuts(from defaults: UserDefaults = .standard) -> ShortcutLoad {
        guard let data = defaults.data(forKey: "applicationShortcuts") else {
            return ShortcutLoad(shortcuts: [:], resetCorruptValue: false)
        }
        do {
            return ShortcutLoad(
                shortcuts: try JSONDecoder().decode([String: AppShortcut].self, from: data),
                resetCorruptValue: false
            )
        } catch {
            defaults.removeObject(forKey: "applicationShortcuts")
            return ShortcutLoad(shortcuts: [:], resetCorruptValue: true)
        }
    }

    static func saveAppShortcuts(_ shortcuts: [String: AppShortcut], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }
        defaults.set(data, forKey: "applicationShortcuts")
    }
}
