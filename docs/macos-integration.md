<!--ai-->
# macOS Integration

## Keyboard shortcut and window

Carbon's `RegisterEventHotKey` registers Command-Space or Option-Space globally. This API delivers only the configured shortcut and does not require Accessibility permission or a keyboard event tap.

The same registry can hold per-application shortcuts captured from the Command-K actions panel. Carbon rejects conflicts rather than silently replacing a macOS or third-party shortcut.

AppKit supplies the borderless `NSPanel`, search field, result table, icons, keyboard navigation and rename dialog. The panel can become the key window while Spotlight remains a menu-bar accessory rather than a Dock application.

## Applications and recent use

`FileManager` enumerates `.app` bundles in the user, local and system Applications directories. `Bundle` reads each display name, bundle identifier and version; duplicate bundle identifiers collapse to the newest installed version. `NSWorkspace` supplies icons and opens the selected bundle.

`NSMetadataItemLastUsedDateKey` reads Spotlight's last-used date. `NSWorkspace.didActivateApplicationNotification` updates that order while Spotlight remains running. Match quality stays primary; recency breaks equal scores and orders the unfiltered list.

## Persistent settings

`UserDefaults` stores the selected spotlight shortcut, per-app shortcuts, Spotlight-only aliases and excluded applications. Command-K and Command-R expose rename, shortcut and removal actions. Removal filters the application from results and unregisters its shortcut without changing the `.app` bundle; the menu-bar menu can restore excluded applications.

## Login startup

`SMAppService.mainApp.register()` asks macOS to start the signed main app at login. This needs no administrator password. macOS may show a one-time notification and exposes the entry in System Settings under Login Items.
<!--/ai-->
