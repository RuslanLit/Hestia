const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const l10nDir = path.join(root, "lib/l10n");
const files = [
  ...fs
    .readdirSync(l10nDir)
    .filter((name) => /^app_.*\.(arb|dart)$/.test(name))
    .map((name) => `lib/l10n/${name}`),
  "lib/l10n/l10n.dart",
  "Landing_Hestia/content/product_content.json",
  "Landing_Hestia/JS/i18n.js",
  "Landing_Hestia/JS/og-data.js",
  "Landing_Hestia/JS/analytics.js",
];

const required = [
  "Сообщение",
  "Звонок",
  "Отмена",
  "Настройки",
  "Повідомлення",
  "Дзвінок",
  "Скасувати",
  "Налаштування",
  "Diagnóstico",
  "Domyślnie",
  "Diagnostický",
  "Standardmäßig",
  "przestrzeń",
  "vídeo",
  "důvěřujete",
  "persönlicher",
];

const mojibake = [
  "Ð",
  "Ñ",
  "Ã",
  "Â",
  "Рџ",
  "Рњ",
  "Р”",
  "РЎ",
  "Р ",
  "Гђ",
  "Г‘",
  "Р Сџ",
  "Р Сљ",
  "Р РЋ",
  "Р вЂ”",
  "Р Сњ",
  "Р С™",
  "Р Т‘",
  "РЎРѓ",
  "РЎРЉ",
  "РЎвЂ“",
  "РЎвЂ”",
  "РІР‚",
  "РІСљ",
  "Р“В©",
  "Р“С–",
  "Р“РЋ",
  "Р“В±",
  "Р•вЂљ",
  "Р•в„ў",
  "Р”в„ў",
  "пїЅпїЅпїЅ",
  "���",
  "???",
];

let combined = "";
const failures = [];

for (const relative of files) {
  const file = path.join(root, relative);
  const text = fs.readFileSync(file, "utf8");
  combined += `\n${text}`;
  for (const marker of mojibake) {
    if (text.includes(marker)) {
      failures.push(
        `${relative}: contains mojibake marker ${JSON.stringify(marker)}`,
      );
    }
  }
}

for (const sample of required) {
  if (!combined.includes(sample)) {
    failures.push(`missing readable text sample ${JSON.stringify(sample)}`);
  }
}

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log("Encoding sanity check passed.");
