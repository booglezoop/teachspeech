export default function (eleventyConfig) {
  eleventyConfig.addPassthroughCopy("src/css");
  // Self-hosted fonts (no requests to Google; GDPR-friendly)
  for (const [pkg, weights] of [
    ["inter", [400, 600]],
    ["literata", [600, 700]],
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
  return { dir: { input: "src", output: "_site" }, templateFormats: ["njk", "md", "html"] };
}
