import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const backendOrigin = process.env.SAFEFLEET_BACKEND_ORIGIN ?? "http://localhost:8080";
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const testFiles = [
  "web_quan_ly/backend/src/test/java/com/safefleet/ApiControllerSmokeTest.java",
  "web_quan_ly/backend/src/test/java/com/safefleet/ExtendedApiControllerSmokeTest.java",
];
const methods = ["get", "post", "put", "patch", "delete"];

const response = await fetch(`${backendOrigin}/v3/api-docs`);
if (!response.ok) throw new Error(`OpenAPI returned HTTP ${response.status}`);
const spec = await response.json();
const source = (
  await Promise.all(testFiles.map((file) => readFile(path.join(root, file), "utf8")))
).join("\n");

const covered = new Set();
for (const match of source.matchAll(
  /\b(get|post|put|patch|delete|multipart)\("(\/api\/v1\/[^"?]*)/g,
)) {
  const method = match[1] === "multipart" ? "POST" : match[1].toUpperCase();
  covered.add(`${method} ${match[2]}`);
}

const operations = [];
for (const [apiPath, item] of Object.entries(spec.paths ?? {})) {
  for (const method of methods) {
    if (item[method]) operations.push(`${method.toUpperCase()} ${apiPath}`);
  }
}

const missing = operations.filter((operation) => !covered.has(operation));
const stale = [...covered].filter((operation) => !operations.includes(operation));
if (missing.length || stale.length) {
  if (missing.length) console.error(`Missing happy-path API cases:\n${missing.join("\n")}`);
  if (stale.length) console.error(`Stale API cases:\n${stale.join("\n")}`);
  process.exit(1);
}

console.log(
  `API happy-path coverage PASS: ${operations.length}/${operations.length} OpenAPI operations.`,
);
