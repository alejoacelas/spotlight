---
human_edit_tracking:
  enabled: true
  history: []
---
# Design

- Search installed `.app` bundles in the user, local and system Applications folders.
- Rank exact, leading, word-leading, internal, acronym, subsequence and edit-distance matches in that order.
- Break equal-quality matches by macOS's last-used date and update recency while Spotlight runs.
- Open when a query of at least two characters leaves one match.
- Keep keyboard control: arrows select, Return opens and Escape closes.
- Toggle the spotlight closed by pressing its global shortcut again.
- Open visible rows with Command-1 through Command-6 and show these commands at the right edge.
- Open one actions panel with Command-K for renaming and persistent per-app global shortcuts; keep Command-R as a direct rename command.
- Persist aliases in preferences without renaming the `.app` bundle.
- Register the chosen global shortcut through Carbon, so no Accessibility permission is required.
- Register the signed main application with macOS as a login item on first launch.
- Show at most six compact result rows.
