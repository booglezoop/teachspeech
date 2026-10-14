// Brochure-style posts are images. Drop files into src/images/blog/<post-slug>/
// (e.g. 1.jpg, 2.jpg, ...) and they appear on that post in numeric order.
import { readdirSync, existsSync } from "node:fs";
import { join } from "node:path";

export default function () {
  const root = join(import.meta.dirname, "..", "images", "blog");
  const out = {};
  if (!existsSync(root)) return out;
  for (const d of readdirSync(root, { withFileTypes: true })) {
    if (!d.isDirectory()) continue;
    out[d.name] = readdirSync(join(root, d.name))
      .filter((f) => /\.(jpe?g|png|webp)$/i.test(f))
      .sort((a, b) => a.localeCompare(b, "en", { numeric: true }));
  }
  return out;
}
