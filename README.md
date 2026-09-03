# Dockfolio

Dockfolio is a small macOS utility that saves named Dock layouts and applies them in one click. Each layout stores pinned applications and spacers. Finder and Trash stay in place. Open apps stay open.

This project is an independent MVP. It is not Dockset. It does not use Dockset artwork, names, or trademarks.

The source tree is a complete Xcode project. This environment is Linux, so the app was **not** built or run on macOS here. Open it on a Mac with Xcode 14.1 or later (macOS 13 Ventura or later).

## Open the project

1. Clone this repository on a Mac.
2. Open `Dockfolio.xcodeproj` in Xcode. You do not need CocoaPods or Swift Package Manager.
3. Select the **Dockfolio** scheme and **My Mac**.
4. Set your development team under **Signing & Capabilities** if Xcode asks. Local ad-hoc signing (`-`) is already set so a personal run can start.
5. Press Run.

Optional: if you use [XcodeGen](https://github.com/yonaskolb/XcodeGen), you can regenerate the project from `project.yml`:

```bash
xcodegen generate
```

Or regenerate the checked-in project with:

```bash
python3 scripts/generate_xcodeproj.py
python3 scripts/generate_icons.py
```

Do **not** enable App Sandbox. Dockfolio writes the `com.apple.dock` preference domain and restarts Dock. The sandbox blocks that path.

## What the MVP does

- **Editor window** — Horizontal icon strip for apps and spacers. Drag to reorder. Add an application, add a spacer, or remove a tile. Spacers have a context menu: Move Left, Move Right, Remove.
- **Status** — `Current · N items`, `Unsaved · N items`, or `Not active · N items`.
- **Save Changes** — Appears when the draft differs from the saved profile. If that profile is the active Dock, save also applies it.
- **Use This Dock** — Appears when you view a saved layout that is not the live Dock.
- **Multiple docks** — Named profiles with a color dot. Switch from the pill menu. Create or delete a dock. You must keep at least one.
- **Menu bar extra** — List of docks (checkmark on the active one), Manage Docks…, Settings…, Quit. A click in the menu bar applies a dock without opening the editor.
- **Local persistence** — JSON in `~/Library/Application Support/Dockfolio/library.json`. No account, cloud, or analytics.
- **Export / import** — JSON for one dock or the whole library (Edit Dock menu).
- **Settings** — Open at login through `SMAppService`. This is reliable after you copy the app into `/Applications`.

Out of scope: Focus Filters, licensing, paywall, and cloud sync.

## How Dock switching works

macOS does not publish an AppKit API that replaces the whole pinned-apps list. Dockfolio isolates the work in `Dockfolio/Services/DockApplicator.swift`.

1. Read or write `persistent-apps` in the `com.apple.dock` preference domain with `CFPreferencesCopyAppValue` / `CFPreferencesSetAppValue` and `CFPreferencesAppSynchronize`.
2. Each application tile uses `tile-type = file-tile` and a `file-data` URL (`_CFURLString` + `_CFURLStringType` 15).
3. Each spacer uses `tile-type = spacer-tile`.
4. `persistent-others` is left alone (folders and stacks on the right).
5. Finder and Trash are not in `persistent-apps`. They stay.
6. After a successful write, Dockfolio runs `/usr/bin/killall Dock`. Dock relaunches. A short flicker is normal.
7. Dockfolio does not quit your apps. An app that is running but not pinned can still show in the Dock until you quit it. That is normal Dock behavior.

Before each apply, Dockfolio copies the previous `persistent-apps` array to:

`~/Library/Application Support/Dockfolio/backups/`

It keeps the last 10 backups.

### Risks

- A bad tile can make Dock drop that item. In rare cases Dock can reset the list. Use a backup if that happens.
- Apple can change the tile dictionary. Test after a macOS update.
- `killall Dock` is the method used by tools such as dockutil. It is not a published AppKit contract.
- The app must stay **outside** the App Sandbox.

## Permissions and caveats

- No extra Privacy permission is required for preference writes in a non-sandboxed app.
- First launch reads the current Dock and stores it as **Main**.
- Login item registration can fail when you run from Xcode DerivedData. Put Dockfolio in `/Applications`, then toggle the setting again. If macOS shows **requires approval**, open **System Settings → General → Login Items**.
- Missing apps show a warning badge on the tile. Apply still writes the last known path.
- Gatekeeper may block an unsigned local build. Use your team certificate, or right-click Open the first time.

## Manual test checklist (Faiz, on your Mac)

Build and run from Xcode. Then walk this list.

### First launch

- [ ] The editor window opens with a glassy chrome and traffic lights.
- [ ] Status reads `Current · N items` (or `Not active` if the live Dock could not be read).
- [ ] The strip shows the apps that were already pinned, plus any spacers.
- [ ] A Dockfolio glyph appears in the menu bar.

### Edit a dock

- [ ] Drag an icon to a new place. Status becomes `Unsaved · N items`. **Save Changes** appears.
- [ ] Edit Dock → Add Application… Pick Safari (or any app). The icon appears.
- [ ] Edit Dock → Add Spacer. A thin gap appears.
- [ ] Right-click the spacer: Move Left, Move Right, Remove.
- [ ] Right-click an app: Remove.
- [ ] Press **Save Changes**. Status returns to `Current` if this dock is active. The real Dock matches after a flicker.

### Multiple docks

- [ ] Color+name pill → **New Dock…**. Name it `Work`. The items copy from the dock you were editing.
- [ ] Change the color dot and the title. Save.
- [ ] Add or remove apps so Work differs from Main.
- [ ] Press **Use This Dock**. The real Dock switches. Open apps stay open.
- [ ] Switch back to Main from the pill and press **Use This Dock**. The previous layout returns.
- [ ] Create a third dock (`Gaming`). Delete is disabled only when one dock remains. Delete Gaming. Confirm. At least one dock remains.

### Menu bar

- [ ] Close the editor window. The process stays. The menu extra stays.
- [ ] Open the menu extra. The active dock has a checkmark.
- [ ] Choose another dock. The real Dock switches. The editor does not need to be open.
- [ ] Choose **Manage Docks…**. The editor returns.
- [ ] Choose **Settings…**. The settings window opens.
- [ ] Choose **Quit Dockfolio**. The menu extra disappears.

### Settings and files

- [ ] Toggle **Open Dockfolio at login**. Read the status line. If registration fails, move the app to `/Applications` and try again.
- [ ] Confirm `~/Library/Application Support/Dockfolio/library.json` exists and lists your docks.
- [ ] After an apply, confirm a file exists under `~/Library/Application Support/Dockfolio/backups/`.

### Export / import

- [ ] Edit Dock → Export This Dock… Save a JSON file. Open it in a text editor. You see names and bundle IDs, not a binary plist.
- [ ] Edit Dock → Import Dock… Select that file. A new (or renamed) dock appears.

### Safety

- [ ] Apply a dock. Confirm Finder is still on the left and Trash is still on the right.
- [ ] Leave an unpinned app running. Apply a dock that does not include it. The app stays running.
- [ ] Folders or stacks on the right of the divider stay.

## Project layout

```
Dockfolio.xcodeproj/     Xcode project + shared scheme
project.yml              XcodeGen spec (optional)
Dockfolio/
  DockfolioApp.swift     SwiftUI app, window, menu extra, settings
  Models/                Dock, items, colors, library document
  Persistence/DockStore  Application Support JSON + editor draft
  Services/
    DockApplicator.swift Real Dock read/write + restart
    AppIconService.swift NSWorkspace icons
    LaunchAtLoginService.swift
  Views/                 Editor, strip, tiles, add-app sheet, settings
  Assets.xcassets        Original app icon + template menu-bar glyph
```

## License

Use and change this source for personal or internal work. Do not present it as Dockset.
