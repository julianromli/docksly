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
    title: "Export",
    subtitle: "and import",
    label: "Export and import",
    icon: "export",
  },
  {
    title: "24-hour",
    subtitle: "trial",
    label: "24-hour trial",
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
