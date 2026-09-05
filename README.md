# Docksly

Docksly is a small macOS utility that saves named Dock layouts and applies them in one click. Each layout stores pinned applications and spacers. Finder and Trash stay in place. Open apps stay open.

This project is an independent MVP. It is not Dockset. It does not use Dockset artwork, names, or trademarks.

Build Docksly from this repository on a Mac. You do not need a paid Apple Developer team for that path. A public `.dmg` still needs Developer ID and notarization.

## Build from source

You need a Mac with macOS 13 or later and Xcode 14.1 or later. Open Xcode once after you install it.

```bash
git clone <this-repository>
cd dockfolio
chmod +x scripts/build-from-source.sh
./scripts/build-from-source.sh
```

That builds a **Release** app (ad-hoc sign) and opens it. Settings → Developer is not in this build.

Useful options:

```bash
./scripts/build-from-source.sh --debug      # Debug build, includes Settings → Developer
./scripts/build-from-source.sh --install    # Copy the app to /Applications, then open it
```

Login at login is reliable only after `--install` (or after you drag Docksly into `/Applications`).

Private testers can use an unsigned disk image while you wait for Apple Developer approval:

```bash
./scripts/build-tester-dmg.sh
```

The file is `dist/Docksly-1.0.0-tester.dmg`. Do not commit it. Recipients who download it must use **Open Anyway** in Privacy & Security. Do not sell this file.

### Open the project in Xcode

1. Open `Docksly.xcodeproj`. You do not need CocoaPods or Swift Package Manager.
2. Select the **Docksly** scheme and **My Mac**.
3. Local ad-hoc signing (`-`) is already set. A personal run can start without a team.
4. Press Run.

Optional: if you use [XcodeGen](https://github.com/yonaskolb/XcodeGen), you can regenerate the project from `project.yml`:

```bash
xcodegen generate
```

Or regenerate the checked-in project with:

```bash
python3 scripts/generate_xcodeproj.py
python3 scripts/generate_icons.py
```

Do **not** enable App Sandbox. Docksly writes the `com.apple.dock` preference domain and restarts Dock. The sandbox blocks that path.

## What the MVP does

- **Editor window** — Horizontal icon strip for apps and spacers. Drag to reorder. Add an application, add a spacer, or remove a tile. Spacers have a context menu: Move Left, Move Right, Remove.
- **Status** — `Current · N items`, `Unsaved · N items`, or `Not active · N items`.
- **Save Changes** — Appears when the draft differs from the saved profile. If that profile is the active Dock, save also applies it.
- **Use This Dock** — Appears when you view a saved layout that is not the live Dock.
- **Multiple docks** — Named profiles with a color dot. Switch from the pill menu. Create or delete a dock. You must keep at least one.
- **Menu bar extra** — List of docks (checkmark on the active one), Manage Docks…, Settings…, Quit. A click in the menu bar applies a dock without opening the editor.
- **Local persistence** — JSON in `~/Library/Application Support/Docksly/library.json`. No account, cloud, or analytics.
- **Export / import** — JSON for one dock or the whole library (Edit Dock menu).
- **Settings** — Open at login through `SMAppService`. This is reliable after you copy the app into `/Applications`.
- **Trial and license** — First launch starts a 24-hour trial. After that, apply, save, create, delete, import, and export stay locked until you paste a Mayar software license key. Buy License opens the Mayar product page.

Out of scope: Focus Filters and cloud sync.

## How Dock switching works

macOS does not publish an AppKit API that replaces the whole pinned-apps list. Docksly isolates the work in `Docksly/Services/DockApplicator.swift`.

1. Read or write `persistent-apps` in the `com.apple.dock` preference domain with `CFPreferencesCopyAppValue` / `CFPreferencesSetAppValue` and `CFPreferencesAppSynchronize`.
2. Each application tile uses `tile-type = file-tile` and a `file-data` URL (`_CFURLString` + `_CFURLStringType` 15).
3. Each spacer uses `tile-type = spacer-tile`.
4. `persistent-others` is left alone (folders and stacks on the right).
5. Finder and Trash are not in `persistent-apps`. They stay.
6. After a successful write, Docksly runs `/usr/bin/killall Dock`. Dock relaunches. A short flicker is normal.
7. Docksly does not quit your apps. An app that is running but not pinned can still show in the Dock until you quit it. That is normal Dock behavior.

Before each apply, Docksly copies the previous `persistent-apps` array to:

`~/Library/Application Support/Docksly/backups/`

It keeps the last 10 backups.

### Risks

- A bad tile can make Dock drop that item. In rare cases Dock can reset the list. Use a backup if that happens.
- Apple can change the tile dictionary. Test after a macOS update.
- `killall Dock` is the method used by tools such as dockutil. It is not a published AppKit contract.
- The app must stay **outside** the App Sandbox.

## Permissions and caveats

- No extra Privacy permission is required for preference writes in a non-sandboxed app.
- First launch reads the current Dock and stores it as **Main**.
- Login item registration can fail when you run from Xcode DerivedData. Put Docksly in `/Applications`, then toggle the setting again. If macOS shows **requires approval**, open **System Settings → General → Login Items**.
- Missing apps show a warning badge on the tile. Apply still writes the last known path.
- Gatekeeper may block an unsigned local build. Use your team certificate, or right-click Open the first time.

## Manual test checklist (Faiz, on your Mac)

Build and run from Xcode. Then walk this list.

### First launch

- [ ] The editor window opens with a glassy chrome and traffic lights.
- [ ] Status reads `Current · N items` (or `Not active` if the live Dock could not be read).
- [ ] The strip shows the apps that were already pinned, plus any spacers.
- [ ] A Docksly glyph appears in the menu bar.

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
- [ ] Choose **Quit Docksly**. The menu extra disappears.

### Settings and files

- [ ] Toggle **Open Docksly at login**. Read the status line. If registration fails, move the app to `/Applications` and try again.
- [ ] Confirm `~/Library/Application Support/Docksly/library.json` exists and lists your docks.
- [ ] After an apply, confirm a file exists under `~/Library/Application Support/Docksly/backups/`.
- [ ] Settings → License shows `Trial · N hours left` on a new install.
- [ ] After you set `DockslyLicenseAPIURL` and deploy the Worker, Activate a valid Mayar sandbox key. Status becomes `Licensed`.
- [ ] Activate a bad key. The form shows a short error. The app does not unlock.

### Export / import

- [ ] Edit Dock → Export This Dock… Save a JSON file. Open it in a text editor. You see names and bundle IDs, not a binary plist.
- [ ] Edit Dock → Import Dock… Select that file. A new (or renamed) dock appears.

### Safety

- [ ] Apply a dock. Confirm Finder is still on the left and Trash is still on the right.
- [ ] Leave an unpinned app running. Apply a dock that does not include it. The app stays running.
- [ ] Folders or stacks on the right of the divider stay.

### License lock

- [ ] After the trial ends, the editor shows a lock sheet. You cannot dismiss it by an empty click.
- [ ] Save, Use This Dock, New Dock, import, and export stay disabled.
- [ ] Settings… from the menu bar still opens. You can paste a key there.
- [ ] Menu bar apply stays disabled. Quit still works.

## License service

Docksly does not keep a Mayar API key in the Mac app. A Cloudflare Worker in `license-api/` verifies keys.

1. Create a Mayar **Software License** product (lifetime).
2. Copy `license-api/.dev.vars.example` to `license-api/.dev.vars`.
3. Set `MAYAR_API_KEY`, `MAYAR_PRODUCT_ID`, and `MAYAR_ENV` (`sandbox` or `production`).
4. Put secrets on the Worker for deploy:
   `npx wrangler secret put MAYAR_API_KEY`
   `npx wrangler secret put MAYAR_PRODUCT_ID`
5. Deploy the Worker. Put the Worker URL in `Docksly/Info.plist` as `DockslyLicenseAPIURL`.
6. Put the Mayar product page URL in `DockslyCheckoutURL`.

The Worker calls `POST /software/v2/license/verify`. It grants access only when Mayar returns `isLicenseActive == true` and `licenseCode.status == ACTIVE`.

Sandbox (current):

- Product: Docksly Lifetime Key — Rp49.000
- Product ID: `bed86a57-d037-4ed6-b552-ec2cbcd7776c`
- Checkout: https://faizintifada.myr.wtf/pl/docksly-lifetime-key
- Coupon `F41Z` — 99% off, reusable
- License API: https://docksly-license-api.faizintifada.workers.dev
- Custom domain (attached, DNS still pending): https://docksly.faizintifada.com

Local files:

- `~/Library/Application Support/Docksly/license.json` — license record
- Keychain item `app.docksly.Docksly` / `trialStartedAt` — trial start, so a deleted JSON file does not restart the trial

## Project layout

```
Docksly.xcodeproj/     Xcode project + shared scheme
project.yml              XcodeGen spec (optional)
Docksly/
  DockslyApp.swift     SwiftUI app, window, menu extra, settings
  Models/                Dock, items, colors, library document
  Persistence/            Application Support JSON + license record
  Services/
    DockApplicator.swift Real Dock read/write + restart
    AppIconService.swift NSWorkspace icons
    LaunchAtLoginService.swift
    LicenseClient.swift  Worker verify client
  Views/                 Editor, strip, tiles, add-app sheet, settings, license
  Assets.xcassets        Original app icon + template menu-bar glyph
license-api/             Cloudflare Worker for Mayar software license verify
```

## License

Use and change this source for personal or internal work. Do not present it as Dockset.
