---
human_edit_tracking:
  enabled: true
  history: []
---
# How Spotlight Is Built and Tested

Spotlight is a native Swift app. I develop it from the terminal, exercise its real signed bundle against macOS and keep the search rules covered by fast automated tests.

## The short version

1. Edit Swift source and behavior notes in the repository.
2. Run the search-model tests with Swift Package Manager.
3. compile a release build with warnings treated as errors.
4. Assemble and sign `Spotlight.app` with the existing stable local identity.
5. Install it in `~/Applications` and exercise the real hotkey, window, search, launch, recency and rename flows.
6. Inspect screenshots and macOS state, then commit and push the tested source.

## More detail

- [Development workflow](development-workflow.md) covers the source tree, compiler, signing, installation and version control tools.
- [macOS integration](macos-integration.md) explains how the hotkey, spotlight window, application catalog, recent-use ordering, login item and aliases reach the operating system.
- [Testing](testing.md) lists the automated and real-application checks, including how keyboard events and screenshots let me verify behavior without guessing from source.
- [Permissions and restrictions](permissions.md) separates permissions Spotlight needs from actions that require the user's confirmation while I work.
- [Feature ideas](feature-ideas.md) prioritizes further ways to make movement around the computer faster.
- [Faster future development](development-affordances.md) lists reusable infrastructure and inputs that would shorten future Raycast-style work.
