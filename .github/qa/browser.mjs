import assert from "node:assert/strict";
import { chromium } from "playwright";

export const qaScreen = "data-velokity-qa-screen";

export function launch() {
  return chromium.launch({
    channel: "chromium",
    executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
    headless: true,
    args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
  });
}

export function watchErrors(page) {
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  page.on("console", message => {
    if (["error", "warning"].includes(message.type())) errors.push(message.text());
  });
  return errors;
}

export async function openGame(page, url, route = null) {
  const [response] = await Promise.all([
    page.goto(String(url)),
    page.waitForEvent("console", {
      predicate: message => message.text().includes("WebGL 2.0"),
      timeout: 30_000,
    }),
  ]);
  assert(response?.ok(), `Could not load ${url}`);
  await page.locator("#status").waitFor({ state: "detached", timeout: 30_000 });
  if (route !== null) {
    await page.waitForFunction(
      ([name, value]) => document.documentElement.getAttribute(name) === value,
      [qaScreen, route],
    );
  }
  await page.evaluate(() => new Promise(resolve => {
    requestAnimationFrame(() => requestAnimationFrame(resolve));
  }));
  assert.equal(await page.locator("html").getAttribute(qaScreen), route);
}

export function fixedDate(page) {
  return page.clock.setFixedTime(new Date("2026-11-25T05:00:00Z"));
}
