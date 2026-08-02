import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const source = process.argv[2];
if (!source) {
  throw new Error(
    "Usage: node docker/scripts/sync-master-prompt.mjs <master-prompt.txt>",
  );
}

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const target = path.join(root, "docs", "CODEX_FULL_PROGRESS.md");
const marker =
  "\n\n---\n\n## 23. BẢN MASTER PROMPT NGUYÊN VĂN TỪ ATTACHMENT";
const [master, progress] = await Promise.all([
  readFile(path.resolve(source), "utf8"),
  readFile(target, "utf8"),
]);
const current = progress.split(marker, 1)[0].trimEnd();
const updated = `${current}${marker}\n\n${master.trim()}\n`;
await writeFile(target, updated, "utf8");
console.log(
  JSON.stringify({
    source: path.resolve(source),
    target,
    masterCharacters: master.length,
  }),
);
