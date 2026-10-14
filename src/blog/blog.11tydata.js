// Directory data for every post in src/blog/.
// Old site URLs were top-level slugs (/blog-zaekvane), so we keep them:
// the file name IS the old slug.
// Allowed categories (the two professions). A typo fails the build.
const CATEGORIES = ["Логопед", "Психолог"];

export default {
  layout: "post.njk",
  isPost: true,
  permalink: (data) => `/${data.page.fileSlug}/`,
  eleventyComputed: {
    description: (data) => data.lead,
    categoryList: (data) => {
      const list = data.categories ?? [];
      for (const c of list) {
        if (!CATEGORIES.includes(c))
          throw new Error(`${data.page.inputPath}: unknown category "${c}"`);
      }
      return list;
    },
    authorList: (data) =>
      (data.authors ?? []).map((slug) => {
        const s = data.specialists.find((x) => x.slug === slug);
        if (!s) throw new Error(`${data.page.inputPath}: unknown author "${slug}"`);
        return s;
      }),
  },
};
