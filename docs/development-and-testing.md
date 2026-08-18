# How Launcher Is Built and Tested

Launcher is a native Swift app. I develop it from the terminal, exercise its real signed bundle against macOS and keep the search rules covered by fast automated tests.

## The short version

1. Edit Swift source and behavior notes in the repository.
2. Run `./scripts/check.sh` to test, compile, sign, exercise and install the app.
3. Inspect the reported macOS state, then commit and push the tested source.

## More detail

- [Development workflow](development-workflow.md) covers the source tree, compiler, signing, installation and version control tools.
- [macOS integration](macos-integration.md) explains how the hotkey, launcher window, application catalog, recent-use ordering, login item and aliases reach the operating system.
- [Testing](testing.md) lists the automated and signed-app checks.
- [Permissions and restrictions](permissions.md) separates permissions Launcher needs from actions that require the user's confirmation while I work.
