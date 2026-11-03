export const features = [
  {
    title: "Named",
    subtitle: "docks",
    label: "Named docks",
    icon: "docks",
  },
  {
    title: "One-click",
    subtitle: "apply",
    label: "One-click apply",
    icon: "apply",
  },
  {
    title: "Menu bar",
    subtitle: "switch",
    label: "Menu bar switch",
    icon: "menubar",
  },
  {
    title: "Dock",
    subtitle: "spacers",
    label: "Dock spacers",
    icon: "spacers",
  },
  {
    title: "Drag to",
    subtitle: "reorder",
    label: "Drag to reorder",
    icon: "reorder",
  },
  {
    title: "Folders",
    subtitle: "and links",
    label: "Folders and links",
    icon: "folders",
  },
  {
    title: "Dock settings",
    subtitle: "per dock",
    label: "Dock settings per dock",
    icon: "appearance",
  },
  {
    title: "Display",
    subtitle: "rules",
    label: "Display rules",
    icon: "displays",
  },
  {
    title: "Open and",
    subtitle: "quit apps",
    label: "Open and quit apps",
    icon: "launch",
  },
  {
    title: "Global",
    subtitle: "hotkeys",
    label: "Global hotkeys",
    icon: "hotkeys",
  },
  {
    title: "Shortcuts",
    subtitle: "actions",
    label: "Shortcuts actions",
    icon: "shortcuts",
  },
  {
    title: "Focus",
    subtitle: "filters",
    label: "Focus filters",
    icon: "focus",
  },
  {
    title: "Save the",
    subtitle: "current Dock",
    label: "Save the current Dock",
    icon: "capture",
  },
  {
    title: "Export",
    subtitle: "and import",
    label: "Export and import",
    icon: "export",
  },
  {
    title: "7-day",
    subtitle: "trial",
    label: "7-day trial",
    icon: "trial",
  },
  {
    title: "Native",
    subtitle: "Mac app",
    label: "Native Mac app",
    icon: "native",
  },
] as const;

export type FeatureIcon = (typeof features)[number]["icon"];
