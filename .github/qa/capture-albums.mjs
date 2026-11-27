import assert from "node:assert/strict";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { fixedDate, launch, openGame, watchErrors } from "./browser.mjs";

const [base, output] = process.argv.slice(2);
assert(base && output, "Usage: node .github/qa/capture-albums.mjs <base-url> <output-dir>");
const planets = JSON.parse(await readFile(new URL("../../data/config/planets.json", import.meta.url), "utf8"));
await mkdir(output, { recursive: true });
const browser = await launch();
try {
  for (const { id, coins } of planets) {
    if (coins === 0) continue;
    const page = await browser.newPage({ viewport: { width: 720, height: 1280 }, locale: "id-ID" });
    try {
      const errors = watchErrors(page);
      await fixedDate(page);
      const url = new URL("web-qa/index.html", base);
      url.searchParams.set("qa", "album");
      url.searchParams.set("planet", id);
      await openGame(page, url, "album");
      assert.equal(await page.locator("html").getAttribute("data-velokity-qa-album"), id);
      const data = await page.locator("canvas").screenshot();
      assert(data.length > 5000 && data.length < 300_000, `${id} album is ${data.length} bytes`);
      assert.deepEqual(errors, [], id);
      await writeFile(join(output, `album-${id}.png`), data);
      console.log(`${id} album · ${data.length} bytes`);
    } finally {
      await page.close();
    }
  }
} finally {
  await browser.close();
}
