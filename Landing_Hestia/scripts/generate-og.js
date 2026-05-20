const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const ogData = require(path.join(root, "JS", "og-data.js"));

const pages = ogData.pages || [];
const languages = ogData.languages || [];
const items = [];

for (const lang of languages) {
  for (const page of pages) {
    const copy = ogData.translations?.[lang]?.[page] || ogData.translations?.en?.[page];
    if (!copy) {
      throw new Error(`Missing OG copy for ${lang}/${page}`);
    }

    items.push({
      lang,
      languageName: ogData.languageNames?.[lang] || lang.toUpperCase(),
      page,
      title: copy.title,
      description: copy.description,
      output: path.join(root, "og", lang, `${page}.png`),
    });
  }
}

const tempPath = path.join(__dirname, ".og-data.tmp.json");
const rendererPath = path.join(__dirname, "generate-og.ps1");

fs.writeFileSync(tempPath, JSON.stringify({ items }, null, 2), "utf8");

try {
  const shell = process.platform === "win32" ? "powershell.exe" : "pwsh";
  execFileSync(
    shell,
    ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", rendererPath, "-DataPath", tempPath, "-Root", root],
    { stdio: "inherit" }
  );
} finally {
  fs.rmSync(tempPath, { force: true });
}

console.log(`Generated ${items.length} Open Graph images in ${path.join(root, "og")}`);
