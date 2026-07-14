<!--ai-->
# Launcher

My small, typo-tolerant macOS application launcher. Results rerank by match quality and recent use with every character, match inside names as well as at their start, and the only remaining match opens immediately after two characters.

```sh
./scripts/build-app.sh --install
```

Launcher defaults to Command-Space. Use its menu-bar icon to switch between Command-Space and Option-Space or refresh the application list. It registers itself to start at login; macOS may show a one-time notification when it does.

Use Command-1 through Command-6 to open a visible result. Select an application and press Command-K for its actions: rename it or assign a persistent global shortcut. Command-R remains a direct route to rename. Names and shortcuts persist across restarts.

[How Launcher is built and tested](docs/development-and-testing.md) links to the development workflow, macOS interfaces, test methods and permission boundaries.

The build requires the local `Switcher Local Code Signing` identity already used by my other Mac utility. The stable signature keeps macOS's identity for the app across rebuilds; the build fails instead of falling back to ad-hoc signing.
<!--/ai-->
