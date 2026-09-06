export const site = {
  name: "Docksly",
  version: "1.0",
  headline: "Organize docks",
  headlineLine2: "for your",
  highlight: "Mac",
  description:
    "Save named Dock layouts and apply them in one click. Finder and Trash stay. Open apps stay open.",
  url: "https://docksly.faizintifada.com",
  email: "hello@docksly.app",
  twitter: "https://x.com/docksly",
  checkout: "https://faizintifada.myr.wtf/pl/docksly-lifetime-key",
  price: "Rp49.000",
  downloadPath: "/Docksly.dmg",
  macos: "macOS 13 or later",
  trial: "24-hour trial",
} as const;

export type NavId = "home" | "faqs" | "changelog" | "privacy" | "recover" | "download";
