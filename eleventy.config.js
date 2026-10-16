import blogImages from "./src/_data/blogImages.js";

export default function (eleventyConfig) {
  eleventyConfig.addPassthroughCopy("src/css");
  eleventyConfig.addPassthroughCopy("src/images");
  // Self-hosted fonts (no requests to Google; GDPR-friendly)
  for (const [pkg, weights] of [
    ["inter", [400, 600]],
    ["literata", [400, 600, 700]],
  ]) {
    for (const w of weights) {
      for (const sub of ["latin", "cyrillic"]) {
        const f = `${pkg}-${sub}-${w}-normal.woff2`;
        eleventyConfig.addPassthroughCopy({
          [`node_modules/@fontsource/${pkg}/files/${f}`]: `fonts/${f}`,
        });
      }
    }
  }
  // Blog: posts live in src/blog/*.md, newest first. Same-day posts: higher `order` first, then file path.
  eleventyConfig.addCollection("posts", (api) =>
    api
      .getFilteredByGlob("src/blog/*.md")
      .sort(
        (a, b) =>
          b.data.published.localeCompare(a.data.published) ||
          (b.data.order ?? 0) - (a.data.order ?? 0) ||
          a.inputPath.localeCompare(b.inputPath),
      ),
  );
  // Inline picture slot for article posts: {% postImage 1 %} shows the Nth file from
  // src/images/blog/<post-slug>/ or a yellow placeholder until that file exists.
  eleventyConfig.addShortcode("postImage", function (n, alt = "") {
    const slug = this.page.fileSlug;
    const file = (blogImages()[slug] ?? [])[n - 1];
    if (!file) {
      return `<figure class="post-figure"><span class="ph">[снимка ${n} – очаква се от автора]</span></figure>`;
    }
    const safeAlt = String(alt).replaceAll('"', "&quot;");
    return `<figure class="post-figure"><img src="/images/blog/${slug}/${file}" alt="${safeAlt}" loading="lazy" decoding="async" /></figure>`;
  });
  eleventyConfig.addFilter("bgDate", (iso) =>
    new Intl.DateTimeFormat("bg-BG", {
      day: "numeric",
      month: "long",
      year: "numeric",
      timeZone: "UTC",
    }).format(new Date(`${iso}T00:00:00Z`)),
  );
  return { dir: { input: "src", output: "_site" }, templateFormats: ["njk", "md", "html"] };
}
