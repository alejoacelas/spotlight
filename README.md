<!--ai-->
# Spotlight

My small, typo-tolerant macOS app finder. Results rerank by match quality and recent use with every character, match inside names as well as at their start, and the only remaining match opens immediately after two characters.

```sh
./scripts/build-app.sh --install
```

Spotlight defaults to Command-Space. Use its menu-bar icon to switch between Command-Space and Option-Space or refresh the application list. It registers itself to start at login; macOS may show a one-time notification when it does.

Use Command-1 through Command-6 to open a visible result. Select an application and press Command-R or Command-K to rename it, assign a persistent global shortcut or remove it from Spotlight without uninstalling it. Restore removed applications from the menu-bar icon. Names, shortcuts and removals persist across restarts.

[How Spotlight is built and tested](docs/development-and-testing.md) links to the development workflow, macOS interfaces, test methods and permission boundaries.

The build uses the stable local signing identity shared with my other Mac utility. The stable signature keeps macOS's identity for the app across rebuilds; the build fails instead of falling back to ad-hoc signing.
<!--/ai-->
