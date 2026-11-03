export const changelogUpdated = "Updated November 2026";

export type ChangelogItem = {
  version: string;
  id: string;
  date: Date;
  summary?: string;
  notes?: string;
  features?: string[];
  fixes?: string[];
};

export const releases: ChangelogItem[] = [
  {
    version: "1.3.1",
    id: "v1-3-1",
    date: new Date("2026-11-03"),
    notes: "Settings has a sidebar now, so the window stays small on any screen.",
    features: [
      "Settings sidebar with General, Shortcuts, Displays, Keep Open, License, and Data",
      "Settings opens on the pane you used last, or on License when the trial has ended",
      "Displays and Keep Open show what to do when their lists are empty",
    ],
    fixes: [
      "The Settings window no longer grows taller than the screen when you have many docks",
    ],
  },
  {
    version: "1.3.0",
    id: "v1-3-0",
    date: new Date("2026-11-03"),
    notes: "Docksly can now switch docks when your displays change, and open or quit apps when a dock is used.",
    features: [
      "Display rules: a dock for an exact set of connected displays, applied when the set changes and at a launch at login",
      "Open When This Dock Is Used for each app, with an optional file, folder, or web address to open with it",
      "Quit Apps Not in This Dock, per dock, off by default. Apps are asked to quit, never forced",
      "Keep Open list in Settings: apps that a dock switch never quits",
      "A dated comparison with DockFlow, based on its public website",
    ],
    fixes: [
      "The lock to one screen is not in this release. It needs a test on several displays first",
    ],
  },
  {
    version: "1.2.0",
    id: "v1-2-0",
    date: new Date("2026-11-02"),
    notes: "Each dock now owns the right side of the Dock, and a dock can carry its own Dock settings.",
    features: [
      "Folders, files, and web links on the right side of the Dock, for each dock",
      "Folder options: Display as, Sort by, and View content as",
      "Add Link with a web address and an optional name",
      "Dock Appearance for each dock: icon size, magnification, position, auto-hide, and recent apps (off by default)",
      "Copy from Current Dock fills in the live Dock settings",
      "Backups now also keep the right side of the Dock",
    ],
    fixes: [
      "After the update, every dock keeps the folders you have on the Dock now",
    ],
  },
  {
    version: "1.1.0",
    id: "v1-1-0",
    date: new Date("2026-11-02"),
    notes: "Switch docks from anywhere: a keyboard shortcut, the Shortcuts app, or a Focus.",
    features: [
      "A global keyboard shortcut for each dock, set in Settings → Keyboard Shortcuts",
      "A Switch to Next Dock shortcut that cycles through your docks",
      "A short notice with the dock name after a switch (you can turn it off)",
      "Shortcuts app actions: Use Dock and Get Current Dock",
      "Focus filter: a Focus can switch to a dock, and the dock from before returns when the Focus turns off",
      "Save Current Dock as New Dock, in the menu bar and the dock menu",
      "The menu bar shows the shortcut for each dock",
      "The free trial is now 7 days",
    ],
    fixes: [
      "A shortcut for the dock that is already on the Dock does not restart the Dock",
    ],
  },
  {
    version: "1.0.1",
    id: "v1-0-1",
    date: new Date("2026-11-02"),
    notes: "Docksly can now stay in the menu bar only, and Settings is easier to read.",
    features: [
      "Show Docksly in Dock setting: the icon shows only while a Docksly window is open",
      "Close the last window and Docksly keeps running in the menu bar",
      "A one-time notice tells you that Docksly is still running after you close it",
      "When macOS opens Docksly at login, it starts in the menu bar with no window",
      "Settings has General, License, and Data sections in one pane, and shows the app version",
    ],
    fixes: [
      "Settings shows the login-item status only when there is a problem",
      "Open Docksly from Finder or Spotlight while it runs, and the editor opens",
    ],
  },
  {
    version: "1.0",
    id: "v1-0",
    date: new Date("2026-09-06"),
    summary:
      "First public release. Named docks, a horizontal editor, a menu bar extra, export and import, a 24-hour trial, and a Mayar license key.",
  },
  {
    version: "1.0.0",
    id: "v1-0-0",
    date: new Date("2026-09-06"),
    notes: "The first public build.",
    features: [
      "Editor window with a horizontal icon strip for apps and spacers",
      "Drag to reorder tiles",
      "Add an application, add a spacer, or remove a tile",
      "Named docks with a color dot",
      "Save Changes when the draft differs from the saved dock",
      "Use This Dock to apply a saved layout",
      "Menu bar list with a checkmark on the active dock",
      "Export and import JSON for one dock or the whole library",
      "Open at login through SMAppService",
      "24-hour trial, then a Mayar software license key",
      "Local JSON store in Application Support — no account or cloud",
    ],
    fixes: [
      "Finder and Trash stay in place",
      "Open apps stay open when you apply a dock",
      "Folders and stacks on the right of the divider stay",
      "The last 10 Dock backups stay under Application Support",
    ],
  },
];
