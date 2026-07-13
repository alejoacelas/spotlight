<!--ai-->
# macOS Integration

## Keyboard shortcut and window

Carbon's `RegisterEventHotKey` registers Command-Space or Option-Space globally. This API delivers only the configured shortcut and does not require Accessibility permission or a keyboard event tap.

AppKit supplies the borderless `NSPanel`, search field, result table, icons, keyboard navigation and rename dialog. The panel can become the key window while Launcher remains a menu-bar accessory rather than a Dock application.

## Applications and recent use

`FileManager` enumerates `.app` bundles in the user, local and system Applications directories. `Bundle` reads each display name and bundle identifier; `NSWorkspace` supplies icons and opens the selected bundle.

`NSMetadataItemLastUsedDateKey` reads Spotlight's last-used date. `NSWorkspace.didActivateApplicationNotification` updates that order while Launcher remains running. Match quality stays primary; recency breaks equal scores and orders the unfiltered list.

## Persistent settings

`UserDefaults` stores the selected shortcut and Launcher-only aliases. Command-R changes the searchable display name but never renames or edits the actual `.app` bundle. Clearing an alias restores the bundle's original name.

## Login startup

`SMAppService.mainApp.register()` asks macOS to start the signed main app at login. This needs no administrator password. macOS may show a one-time notification and exposes the entry in System Settings under Login Items.
<!--/ai-->
