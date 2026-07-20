<!--ai-->
# Development Workflow

## Source and build tools

- `apply_patch` makes deliberate file edits while preserving unrelated changes.
- Swift Package Manager compiles the executable and runs the `Testing` framework suite through `swift test`.
- `swift build -c release -Xswiftc -warnings-as-errors` checks the production configuration and turns every compiler warning into a failure.
- `scripts/build-app.sh` assembles the Swift executable and `Info.plist` into a macOS application bundle.

## Signing and installation

The build script checks Keychain for the stable local signing identity, signs with `codesign --options runtime`, and verifies the finished bundle with `codesign --verify --deep --strict`. It never silently falls back to an ad-hoc signature.

`./scripts/build-app.sh --install` replaces the development copy at `~/Applications/Spotlight.app` and opens it. Keeping the certificate, bundle identifier and installation location stable gives macOS one persistent identity across rebuilds.

## Inspection and publishing

- `rg` finds source and configuration references quickly.
- `git diff --check`, scoped staging and `git status` catch whitespace mistakes and prevent unrelated workspace changes from entering a commit.
- `gh` and the connected GitHub app push the branch and create the review pull request.
- The parent workspace generator records Spotlight as its own public nested repository without absorbing its source into the parent repo.
<!--/ai-->
