<!--ai-->
# Launcher

My small, typo-tolerant macOS application launcher. Results rerank by match quality and recent use with every character, match inside names as well as at their start, and the only remaining match opens immediately after two characters.

```sh
./scripts/build-app.sh --install
```

Launcher defaults to Command-Space. Use its menu-bar icon to switch between Command-Space and Option-Space or refresh the application list. It registers itself to start at login; macOS may show a one-time notification when it does.

Use the arrow keys to select an application and press Command-R to rename it inside Launcher. Names persist across restarts; leave the new name empty to restore the application's real name.

[How Launcher is built and tested](docs/development-and-testing.md) links to the development workflow, macOS interfaces, test methods and permission boundaries.

The build requires the local `Switcher Local Code Signing` identity already used by my other Mac utility. The stable signature keeps macOS's identity for the app across rebuilds; the build fails instead of falling back to ad-hoc signing.
<!--/ai-->
