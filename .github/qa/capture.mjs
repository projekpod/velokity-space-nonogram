import assert from "node:assert/strict";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { chromium } from "playwright";

const [baseUrl, output] = process.argv.slice(2);
assert(baseUrl && output, "Usage: node .github/qa/capture.mjs <base-url> <output-dir>");
const screens = ["menu", "game", "win", "daily"];
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

async function capture(path, screen = null) {
  const page = await browser.newPage({
    viewport: { width: 720, height: 1280 },
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
    assert.deepEqual(errors, [], `${path} logged browser errors or warnings`);
    return screenshot;
  } catch (error) {
    throw new Error(`Capture failed for ${path}: ${errors.join("\n")}`, { cause: error });
  } finally {
    await page.close();
  }
}

try {
  await mkdir(output, { recursive: true });
  const release = await capture("web/index.html");
  assert((await capture("web-qa/index.html?qa=unknown")).equals(release), "Unknown QA routes should open the normal menu");

  const screenshots = [];
  for (const screen of screens) {
    const screenshot = await capture(`web-qa/index.html?qa=${screen}`, screen);
    assert(!screenshot.equals(release), `QA ${screen} did not render its fixture`);
    assert(!screenshots.some(previous => previous.equals(screenshot)), `Duplicate rendering for QA ${screen}`);
    screenshots.push(screenshot);
    await writeFile(join(output, `${screen}.png`), screenshot);
    assert((await capture(`web/index.html?qa=${screen}`)).equals(release), `QA ${screen} changed the release menu`);
    console.log(`Captured ${screen}.png and verified the release ignores ?qa=${screen}`);
  }
} finally {
  await browser.close();
}
