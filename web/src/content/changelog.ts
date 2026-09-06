export const changelogUpdated = "Updated September 2026";

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
