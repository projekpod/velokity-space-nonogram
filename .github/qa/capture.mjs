import assert from "node:assert/strict";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { chromium } from "playwright";

const [baseUrl, output] = process.argv.slice(2);
assert(baseUrl && output, "Usage: node .github/qa/capture.mjs <base-url> <output-dir>");
const screens = ["menu", "game", "win", "daily", "mascot", "reactions", "combo", "bonus", "album", "shop", "celebration"];
const screenAttribute = "data-velokity-qa-screen";
const engineTimeout = 30_000;

const browser = await chromium.launch({
  channel: "chromium",
  executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
  headless: true,
  args: [
    "--use-gl=angle",
    "--use-angle=swiftshader",
    "--enable-unsafe-swiftshader",
    "--autoplay-policy=no-user-gesture-required",
  ],
});

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
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  page.on("console", message => {
    if (["error", "warning"].includes(message.type())) errors.push(message.text());
  });

  try {
    if (withoutBridge) {
      await page.route("**/playgama-bridge.js", route => route.fulfill({
        contentType: "application/javascript",
        body: "",
      }));
    }
    await page.clock.setFixedTime(new Date("2026-11-25T05:00:00Z"));
    const [, response] = await Promise.all([
      page.waitForEvent("console", {
        predicate: message => message.text().includes("WebGL 2.0"),
        timeout: engineTimeout,
      }),
      page.goto(new URL(path, baseUrl).href),
    ]);
    assert(response?.ok(), `Could not load ${path}`);
    await page.locator("#status").waitFor({ state: "hidden", timeout: engineTimeout });
    if (screen !== null) {
      await page.waitForFunction(
        ({ attribute, screen }) => document.documentElement.getAttribute(attribute) === screen,
        { attribute: screenAttribute, screen },
        { timeout: engineTimeout },
      );
    }
    await page.evaluate(() => new Promise(resolve => {
      requestAnimationFrame(() => requestAnimationFrame(resolve));
    }));
    const renderer = await page.locator("canvas").evaluate(canvas => {
      const gl = canvas.getContext("webgl2");
      const info = gl?.getExtension("WEBGL_debug_renderer_info");
      return info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : null;
    });
    assert.match(renderer ?? "", /SwiftShader/i, `${path} must run on SwiftShader WebGL2`);
    assert.equal(await page.locator("html").getAttribute(screenAttribute), screen);
    const screenshot = await page.locator("canvas").screenshot();
    assert(screenshot.length > 5000, `${path} produced a blank canvas`);
    assert(screenshot.length < 300_000, `${path} exceeds the 300 KB screenshot budget`);
    // Compare opaque menu controls so the animated mascot and starfield can keep running.
    const controls = screen === null ? Buffer.concat([
      await page.screenshot({ clip: { x: 130, y: 791, width: 460, height: 42 } }),
      await page.screenshot({ clip: { x: 130, y: 1027, width: 460, height: 42 } }),
    ]) : null;
    const balance = screen === null || screen === "menu" ? await captureBalance(page, screenshot) : [];
    if (screen === null || screen === "menu") assert(balance.length > 0, `${path} did not display its balance`);
    assert.deepEqual(errors, [], `${path} logged browser errors or warnings`);
    return { screenshot, menu: { controls, balance } };
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
  assert.deepEqual(fallback.menu, release.menu, "A missing SDK should still open the normal menu");
  const unknown = await capture("web-qa/index.html?qa=unknown");
  assert.deepEqual(unknown.menu, release.menu, "Unknown QA routes should open the normal menu");

  const screenshots = [];
  for (const screen of screens) {
    const { screenshot, menu } = await capture(`web-qa/index.html?qa=${screen}`, screen);
    if (screen === "menu") assert.notDeepEqual(menu.balance, release.menu.balance, "QA menu should display its seeded balance");
    assert(!screenshot.equals(release.screenshot), `QA ${screen} did not render its fixture`);
    assert(!screenshots.some(previous => previous.equals(screenshot)), `Duplicate rendering for QA ${screen}`);
    screenshots.push(screenshot);
    await writeFile(join(output, `${screen}.png`), screenshot);
    const queriedRelease = await capture(`web/index.html?qa=${screen}`);
    assert.deepEqual(queriedRelease.menu, release.menu, `QA ${screen} changed the release menu`);
    console.log(`Captured ${screen}.png and verified the release ignores ?qa=${screen}`);
  }
} finally {
  await browser.close();
}
