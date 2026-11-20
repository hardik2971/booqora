// Writes sitemap.xml and robots.txt into the static export (out/) from the generated pages.
import { copyFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { join, relative } from "node:path";

const OUT = "out";
const SITE = (process.env.NEXT_PUBLIC_SITE_URL ?? "https://booqora-infidec.web.app").replace(/\/$/, "");
const today = new Date().toISOString().slice(0, 10);

const pages = [];
const walk = (dir) => {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) {
      if (name.startsWith("_")) continue;
      walk(p);
    } else if (name.endsWith(".html")) {
      const route = "/" + relative(OUT, p).split("\\").join("/").replace(/(index)?\.html$/, "").replace(/\/$/, "");
      if (/^\/(404|_not-found)/.test(route)) continue;
      pages.push(route === "/" ? "/" : route.replace(/\/index$/, ""));
    }
  }
};
walk(OUT);

const priority = (r) => (r === "/" ? 1 : /^\/(pricing|features)$/.test(r) ? 0.9 : /^\/(features|industries|mobile-app)/.test(r) ? 0.8 : /^\/blog/.test(r) ? 0.6 : 0.5);
const urls = [...new Set(pages)]
  .sort((a, b) => priority(b) - priority(a) || a.localeCompare(b))
  .map((r) => `  <url><loc>${SITE}${r === "/" ? "" : r}</loc><lastmod>${today}</lastmod><priority>${priority(r)}</priority></url>`);

// The client router requests segment prefetch files with dotted names
// (e.g. /pricing/__next.pricing.__PAGE__.txt) but the export writes them nested
// (/pricing/__next.pricing/__PAGE__.txt). Mirror each nested file to its dotted name.
let mirrored = 0;
const mirror = (dir) => {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (!statSync(p).isDirectory()) continue;
    if (name.startsWith("__next.")) {
      const flatten = (sub, prefix) => {
        for (const n of readdirSync(sub)) {
          const q = join(sub, n);
          if (statSync(q).isDirectory()) flatten(q, `${prefix}.${n}`);
          else {
            copyFileSync(q, join(dir, `${prefix}.${n}`));
            mirrored++;
          }
        }
      };
      flatten(p, name);
    } else if (name !== "_next") {
      mirror(p);
    }
  }
};
mirror(OUT);
console.log(`prefetch segment files mirrored: ${mirrored}`);

writeFileSync(join(OUT, "sitemap.xml"), `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.join("\n")}\n</urlset>\n`);
writeFileSync(join(OUT, "robots.txt"), `User-agent: *\nAllow: /\n\nSitemap: ${SITE}/sitemap.xml\n`);
console.log(`sitemap.xml: ${urls.length} URLs · robots.txt written`);
