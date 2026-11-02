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
