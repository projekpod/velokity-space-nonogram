import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { fixedDate, launch, openGame, watchErrors } from "./browser.mjs";

const [baseUrl, output, only] = process.argv.slice(2);
assert(baseUrl && output, "Usage: node .github/qa/capture.mjs <base-url> <output-dir> [screen]");
const screens = ["menu", "game", "win", "daily", "mascot", "reactions", "combo", "bonus", "album", "shop", "celebration", "streak", "space", "cats", "shop-legendary", "twists"];
assert(!only || screens.includes(only), `Unknown screenshot route: ${only}`);
const browser = await launch();

async function captureBalance(page, screenshot) {
  // Solid gold belongs to the balance text in this band; moving stars are blue.
  return page.evaluate(async png => {
    const source = await fetch(`data:image/png;base64,${png}`);
    const image = await createImageBitmap(await source.blob());
    const canvas = new OffscreenCanvas(720, 32);
    const context = canvas.getContext("2d");
    context.drawImage(image, 0, -732);
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
    const gold = [];
    for (let i = 0; i < pixels.length; i += 4) {
      if (pixels[i] === 255 && pixels[i + 1] === 207 && pixels[i + 2] === 130) gold.push(i);
    }
    return gold;
  }, screenshot.toString("base64"));
}

async function capture(path, screen = null, withoutBridge = false) {
  const page = await browser.newPage({
    viewport: screen === "reactions" ? { width: 1280, height: 800 } : { width: 720, height: 1280 },
    deviceScaleFactor: 1,
    locale: "id-ID",
    timezoneId: "Asia/Jakarta",
  });
  const errors = watchErrors(page);

  try {
    if (withoutBridge) {
      await page.route("**/playgama-bridge.js", route => route.fulfill({
        contentType: "application/javascript",
        body: "",
      }));
    }
    await fixedDate(page);
    await openGame(page, new URL(path, baseUrl), screen);
    const renderer = await page.locator("canvas").evaluate(canvas => {
      const gl = canvas.getContext("webgl2");
      const info = gl?.getExtension("WEBGL_debug_renderer_info");
      return info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : null;
    });
    assert.match(renderer ?? "", /SwiftShader/i, `${path} must run on SwiftShader WebGL2`);
    const screenshot = await page.locator("canvas").screenshot();
    assert(screenshot.length > 5000, `${path} produced a blank canvas`);
    assert(screenshot.length < 300_000, `${path} exceeds the 300 KB screenshot budget`);
    // Opaque tutorial buttons and cells make stable regions while the art animates.
    const firstPuzzle = screen === null ? createHash("sha256").update(Buffer.concat([
      await page.screenshot({ clip: { x: 43, y: 253, width: 296, height: 45 } }),
      await page.screenshot({ clip: { x: 384, y: 253, width: 304, height: 45 } }),
      await page.screenshot({ clip: { x: 56, y: 410, width: 100, height: 80 } }),
    ])).digest("hex") : null;
    if (screen === "menu") assert((await captureBalance(page, screenshot)).length > 0, "QA menu did not display its seeded balance");
    assert.deepEqual(errors, [], `${path} logged browser errors or warnings`);
    return { screenshot, firstPuzzle };
  } catch (error) {
    throw new Error(`Capture failed for ${path}: ${errors.join("\n")}`, { cause: error });
  } finally {
    await page.close();
  }
}

try {
  await mkdir(output, { recursive: true });
  const release = await capture("web/index.html");
  const fallback = await capture("web/index.html", null, true);
  assert.deepEqual(fallback.firstPuzzle, release.firstPuzzle, "A missing SDK should still open Moon 01");
  const unknown = await capture("web-qa/index.html?qa=unknown");
  assert.deepEqual(unknown.firstPuzzle, release.firstPuzzle, "Unknown QA routes should open Moon 01");

  const screenshots = [];
  for (const screen of only ? [only] : screens) {
    const { screenshot } = await capture(`web-qa/index.html?qa=${screen}`, screen);
    assert(!screenshot.equals(release.screenshot), `QA ${screen} did not render its fixture`);
    assert(!screenshots.some(previous => previous.equals(screenshot)), `Duplicate rendering for QA ${screen}`);
    screenshots.push(screenshot);
    await writeFile(join(output, `${screen}.png`), screenshot);
    const queriedRelease = await capture(`web/index.html?qa=${screen}`);
    assert.deepEqual(queriedRelease.firstPuzzle, release.firstPuzzle, `QA ${screen} changed release onboarding`);
    console.log(`Captured ${screen}.png and verified the release ignores ?qa=${screen}`);
  }
  for (const route of only ? [] : ["store-icon", "store-cover", "preview", "playthrough", "zoom"]) {
    const queriedRelease = await capture(`web/index.html?qa=${route}`);
    assert.deepEqual(queriedRelease.firstPuzzle, release.firstPuzzle, `QA ${route} changed release onboarding`);
    console.log(`Verified the release ignores ?qa=${route}`);
  }
} finally {
  await browser.close();
}
