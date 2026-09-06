import rss from "@astrojs/rss";
import type { APIContext } from "astro";
import { releases } from "../../content/changelog";
import { site } from "../../content/site";

export function GET(context: APIContext) {
  return rss({
    title: `${site.name} — Changelog`,
    description: "What changed in Docksly.",
    site: context.site ?? site.url,
    items: releases.map((entry) => ({
      title: entry.version,
      pubDate: entry.date,
      description: entry.summary ?? entry.notes ?? `Docksly ${entry.version}`,
      link: `/changelog#${entry.id}`,
    })),
  });
}
