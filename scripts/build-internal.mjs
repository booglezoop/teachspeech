import { build } from "esbuild";
import { readFile } from "node:fs/promises";

let fileEnv = {};

try {
  const envText = await readFile(".env.local", "utf8");

  fileEnv = Object.fromEntries(
    envText
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith("#"))
      .map((line) => {
        const separator = line.indexOf("=");
        if (separator < 0) return ["", ""];

        return [line.slice(0, separator).trim(), line.slice(separator + 1).trim()];
      })
      .filter(([key]) => key),
  );
} catch (error) {
  if (error.code !== "ENOENT") throw error;
}

const url = process.env.SUPABASE_URL || fileEnv.SUPABASE_URL;
const publishableKey = process.env.SUPABASE_PUBLISHABLE_KEY || fileEnv.SUPABASE_PUBLISHABLE_KEY;

if (!url || !publishableKey) {
  throw new Error(
    "Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in the environment or .env.local.",
  );
}

await build({
  entryPoints: ["src/js/internal-entry.js"],
  outfile: "src/js/internal.js",
  bundle: true,
  format: "esm",
  platform: "browser",
  target: ["es2022"],
  define: {
    "window.TEACHSPEECH_SUPABASE": JSON.stringify({
      url,
      publishableKey,
    }),
  },
});
