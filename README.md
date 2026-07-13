<!--ai-->
# Launcher

My small, typo-tolerant macOS application launcher. Results rerank with every character, match inside names as well as at their start, and a unique exact name of at least two characters opens immediately.

```sh
./scripts/build-app.sh --install
```

Launcher defaults to Command-Space. Use its menu-bar icon to switch between Command-Space and Option-Space or refresh the application list. It registers itself to start at login; macOS may show a one-time notification when it does.

The build requires the local `Switcher Local Code Signing` identity already used by my other Mac utility. The stable signature keeps macOS's identity for the app across rebuilds; the build fails instead of falling back to ad-hoc signing.
<!--/ai-->
