import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import pkg from "../../package.json";

// Read at build time from the DMG that ships in public/, so the numbers never go stale.
function readDmg() {
  try {
    const bytes = readFileSync(join(process.cwd(), "public", "Docksly.dmg"));
    return {
      size: `${(bytes.length / 1_000_000).toFixed(1)} MB`,
      sha256: createHash("sha256").update(bytes).digest("hex"),
    };
  } catch {
    return null;
  }
}

export const release = {
  version: pkg.version,
  developer: "Faiz Intifada Julian Romli",
  github: "https://github.com/julianromli/docksly/releases",
  brew: "brew install --cask julianromli/tap/docksly",
  dmg: readDmg(),
} as const;
