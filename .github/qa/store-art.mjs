import assert from "node:assert/strict";
import { mkdir, stat } from "node:fs/promises";
import { join } from "node:path";
import { fixedDate, launch, openGame, watchErrors } from "./browser.mjs";
import { waitState } from "./gameplay.mjs";

const [baseUrl, output, selection] = process.argv.slice(2);
assert(baseUrl && output && (!selection || selection === "gameplay"),
  "Usage: node .github/qa/store-art.mjs <base-url> <output-dir> [gameplay]");

const shots = [
  ["icon.png", "store-icon", 512, 512],
  ["favicon.png", "store-icon", 64, 64],
  ["crazygames-landscape.jpg", "store-cover", 1920, 1080],
  ["crazygames-portrait.jpg", "store-cover", 800, 1200],
  ["crazygames-square.jpg", "store-cover", 800, 800],
  ["itch-cover.jpg", "store-cover", 630, 500],
  ["gamedistribution-square.jpg", "store-cover", 512, 512],
  ["gamedistribution-standard.jpg", "store-cover", 512, 384],
  ["gamedistribution-small.jpg", "store-cover", 200, 120],
  ["gameplay-zoom.png", "store-zoom", 720, 1280],
  ["gameplay-twist.png", "store-twist", 720, 1280],
  ["gameplay-streak.png", "streak", 720, 1280],
  ["gameplay-shop.png", "shop-legendary", 720, 1280],
];
const expected = {
  "store-zoom": s => s.boardSize === 15 && s.zoomed && s.state === 0 && s.marks > 0,
  "store-twist": s => s.twistTip && s.buttons.TWIST_START,
  streak: s => s.holdingBoard && s.state === 0,
  "shop-legendary": s => s.scene === "shop" && s.preview === "savannah",
};

const browser = await launch();
try {
  await mkdir(output, { recursive: true });
  for (const [name, route, width, height] of shots) {
    if (selection && !name.startsWith("gameplay-")) continue;
    const page = await browser.newPage({ viewport: { width, height }, locale: "en-US", timezoneId: "Asia/Jakarta" });
    try {
      const errors = watchErrors(page);
      await fixedDate(page);
      await openGame(page, new URL(`web-qa/index.html?qa=${route}`, baseUrl), route);
      if (expected[route]) await waitState(page, expected[route]);
      const canvas = page.locator("canvas");
      const bounds = await canvas.boundingBox();
      assert.equal(bounds.width, width, name);
      assert.equal(bounds.height, height, name);
      const path = join(output, name);
      await canvas.screenshot(name.endsWith(".jpg") ? { path, type: "jpeg", quality: 92 } : { path });
      const { size } = await stat(path);
      assert(size > 500 && size < 1_000_000, `${name} is ${size} bytes`);
      assert.deepEqual(errors, [], name);
      console.log(`${name} · ${width}×${height} · ${size} bytes`);
    } finally {
      await page.close();
    }
  }
} finally {
  await browser.close();
}
