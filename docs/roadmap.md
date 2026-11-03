# Docksly roadmap (1.1 – 1.3)

Agreed on 2026-11-02. Goal: match DockFlow's main features, add two features
it does not have (display auto-switch and Dock settings per dock), and keep
Rp49.000 for a lifetime license with all future updates.

## Rules for all releases

- Minimum macOS stays 13.
- All new features follow the license rule: free during the trial, locked
  after the trial until a license is active.
- Trial length is 7 days for everyone. A user whose trial started less than
  7 days ago gets access again until day 7.
- `library.json` and exports get optional new fields and a schema version.
  Old files and old exports open. An older app that imports a newer export
  loses only the new fields.
- An XCTest target covers Dock tile encoding, display-rule matching, the
  trial clock, and library migration. Tests do not touch the real Dock.
- Each release: build and test, then a hand test by the owner, then bump the
  version, add a changelog entry, build the notarized DMG, install it in
  `/Applications`, commit to `main`, push to `origin` and `cursor`, deploy the
  website, and update the Homebrew cask.

## 1.1 — Switch from anywhere

- One global hotkey per dock and one **Switch to Next Dock** hotkey (no
  default key). Set in Settings → Keyboard Shortcuts (color dot, name,
  recorder). Uses the `KeyboardShortcuts` package. The menu bar list shows
  each dock's shortcut.
- A HUD in the lower center of the screen for about 1 second after a switch
  (color dot and name). A Settings toggle turns it off.
- A hotkey for the dock that is already active (and has no unsaved edits)
  does not restart the Dock. It only shows the HUD.
- Shortcuts actions: **Use Dock** (pick a dock) and **Get Current Dock**
  (returns the name).
- Focus filter: pick a dock for a Focus. When the Focus turns off, switch back
  to the dock that was active before it turned on. If that dock was deleted,
  do nothing.
- **Save Current Dock as New Dock…** in the menu bar menu and in the editor's
  pill menu. It reads the live Dock and asks for a name.
- "24-hour" trial text becomes "7-day" in the app, README, and website. Old
  1.0.0 changelog lines stay as they are.
- Homebrew: a public tap repo `julianromli/homebrew-tap` with a `docksly`
  cask.

## 1.2 — Right side of the Dock and per-dock settings

- Folders, files, and web links (`persistent-others`). Each dock owns its
  right side. On the first launch of 1.2, copy the current right side into
  every existing dock.
- Editor: one strip with a divider (apps | folders, files, links). Each side
  has its own **+** (Add Application / Spacer; Add Folder / File / Link).
- Folder right-click menu: Display as (Stack / Folder), Sort by (Name, Date
  Added, Date Modified, Date Created, Kind), View content as (Fan, Grid, List,
  Automatic). New folders use the macOS defaults.
- **Add Link…** sheet: URL and an optional name. The tile shows a globe icon
  (no network calls).
- **Dock Appearance…** sheet from the editor's ⋯ menu. Opt-in toggle
  **Use these Dock settings** (off by default): icon size, magnification
  (on/off and size), position, auto-hide, show suggested and recent apps. A
  **Copy from Current Dock** button.

## 1.3 — Automation

- Display rules: an exact set of displays (matched by vendor, model, and
  serial) → a dock. Applied when the set of displays changes and at a launch
  at login. A set with no rule changes nothing. Created in Settings with
  **Use a Dock for This Display Setup**.
- Trigger conflicts: the last trigger wins. A manual switch stays until the
  next automatic trigger.
- Per app tile: **Open when this dock is used**, with an optional file,
  folder, or URL. Apps that already run come to the front.
- Per dock, off by default: **Quit apps that are not in this dock**. Ask apps
  to quit; never force. Never quit Finder, Docksly, or apps in the Settings
  **Always keep open** list. Confirm the first time it is turned on. No
  reopen later.
- ~~Lock the Dock to a display~~ Moved to Later (2026-11-03). Not tested: the
  owner has one display. Needs a two-display test before it returns.
- Website: a dated **Docksly vs DockFlow** page with facts from DockFlow's
  public site only.

## Later

- Submit the cask to the official `homebrew/cask` when Docksly has more users.
- Lock the Dock to a display (event tap, needs Accessibility permission).
  Test on two displays first: a spike that moves the cursor to the bottom
  edge of the second display and checks where the Dock appears.
