<!--ai-->
# Design

- Search installed `.app` bundles in the user, local and system Applications folders.
- Rank exact, leading, word-leading, internal, acronym, subsequence and edit-distance matches in that order.
- Open only when a normalized full name of at least two characters identifies one installed bundle. Typo and partial matches remain visible but never auto-open.
- Keep keyboard control: arrows select, Return opens and Escape closes.
- Register the chosen global shortcut through Carbon, so no Accessibility permission is required.
- Register the signed main application with macOS as a login item on first launch.
<!--/ai-->
