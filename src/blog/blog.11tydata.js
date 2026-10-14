// Directory data for every post in src/blog/.
// Old site URLs were top-level slugs (/blog-zaekvane), so we keep them:
// the file name IS the old slug.
export default {
  layout: "post.njk",
  isPost: true,
  permalink: (data) => `/${data.page.fileSlug}/`,
  eleventyComputed: {
    description: (data) => data.lead,
    authorList: (data) =>
      data.authors.map((slug) => {
        const s = data.specialists.find((x) => x.slug === slug);
        if (!s) throw new Error(`${data.page.inputPath}: unknown author "${slug}"`);
        return s;
      }),
  },
};
