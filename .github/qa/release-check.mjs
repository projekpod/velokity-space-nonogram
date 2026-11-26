import assert from "node:assert/strict";
import { appendFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { launch, openGame, watchErrors } from "./browser.mjs";
import { button, cell, fills, levels, state, waitState } from "./gameplay.mjs";

const [baseUrl] = process.argv.slice(2);
assert(baseUrl, "Usage: node .github/qa/release-check.mjs <base-url>");
const route = "playthrough";
const url = new URL(`web-qa/index.html?qa=${route}`, baseUrl);
const fixture = fileURLToPath(new URL("./portal-fixture.js", import.meta.url));
const moon = await levels("", "moon-", 5);
const bonus = await levels("bonus/", "bonus-", 3);
const browser = await launch();

async function solve(page, level) {
  await waitState(page, snapshot => snapshot.grid && snapshot.state === 0 && snapshot.lives === 3);
  for (const [x, y] of fills(level)) {
    const { grid } = await waitState(page, snapshot => snapshot.grid && snapshot.state === 0);
    await cell(page, grid, level.size, x, y);
  }
  const result = await waitState(page, snapshot => snapshot.state === 1);
  assert.equal(result.scene, level.id);
  assert.equal(result.lives, 3);
  await waitState(page, snapshot => snapshot.tier === 0);
  return result;
}

async function waitForBrowserSave(page, { clears, helmet = null }) {
  // Godot writes to its in-memory filesystem first, then flushes to IndexedDB.
  const deadline = performance.now() + 12_000;
  do {
    if (await page.evaluate(async ({ clears, helmet }) => {
      const database = await new Promise((resolve, reject) => {
        const open = indexedDB.open("/userfs");
        open.onupgradeneeded = () => open.transaction.abort();
        open.onsuccess = () => resolve(open.result);
        open.onerror = () => reject(open.error);
      });
      try {
        const snapshot = await new Promise((resolve, reject) => {
          const store = database.transaction("FILE_DATA", "readonly").objectStore("FILE_DATA");
          const request = store.openCursor();
          request.onsuccess = () => {
            const file = request.result;
            if (!file) resolve(null);
            else if (file.key.endsWith("/qa-save.json")) {
              resolve(JSON.parse(new TextDecoder().decode(file.value.contents)));
            } else file.continue();
          };
          request.onerror = () => reject(request.error);
        });
        return snapshot?.onboarding_complete &&
          Object.keys(snapshot.nonogram).length === clears &&
          (helmet === null || snapshot.meta.equipped.helmet === helmet);
      } finally {
        database.close();
      }
    }, { clears, helmet })) return;
    await page.waitForTimeout(100);
  } while (performance.now() < deadline);
  assert.fail(`Browser save did not persist ${JSON.stringify({ clears, helmet })}`);
}

async function runFullPlaythrough(page) {
  let snapshot = await waitState(page, s => s.first && s.step === 0 && s.grid);
  assert.equal(snapshot.scene, moon[0].id);
  assert.deepEqual(await page.evaluate(() => window.velokityPortalFixture.calls), ["storage:get", "game_ready", "gameplay_started"]);
  await button(page, "TUTORIAL_NEXT");
  await waitState(page, s => s.step === 1);
  await button(page, "TUTORIAL_NEXT");
  await waitState(page, s => s.step === 2);
  await button(page, "TUTORIAL_SKIP");
  await waitState(page, s => s.step === 3 && !s.buttons.TUTORIAL_SKIP);
  await button(page, "GAME_CROSS");
  snapshot = await waitState(page, s => s.grid);
  const emptyX = moon[0].solution[0].indexOf(".");
  assert(emptyX >= 0);
  await cell(page, snapshot.grid, moon[0].size, emptyX, 0);
  await button(page, "GAME_FILL");
  await solve(page, moon[0]);
  await button(page, "GAME_DOUBLE_AD");
  await waitState(page, s => s.coins >= 120);
  await button(page, "GAME_BACK");
  await waitState(page, s => s.buttons.MENU_PLAY && !s.paused);
  assert.equal(await page.evaluate(() => window.velokityPortalFixture.minimumDelay), 90);
  assert((await page.evaluate(() => window.velokityPortalFixture.calls)).includes("interstitial"), "Bridge receives the first result");
  assert.equal(await page.evaluate(() => Object.keys(window.velokityPortalFixture.saved().nonogram).length), 1);
  await openGame(page, url, route);
  await waitState(page, s => s.buttons.MENU_PLAY && s.clears === 1);
  await button(page, "MENU_PLAY");
  await button(page, "Moon · 1/20 cleared");
  await button(page, "level2");

  const errorsBefore = await page.evaluate(() => window.velokityPortalFixture.calls.filter(call => call.startsWith("banner")));
  assert.deepEqual(errorsBefore, [], "Portrait gameplay requested a banner");
  for (const width of [599, 600, 899, 1100]) {
    const height = width === 899 ? 1000 : 580;
    await page.setViewportSize({ width, height });
    if (width < 600 || width < height) {
      await page.waitForFunction(() => !document.getElementById("banner-container"));
      continue;
    }
    const banner = page.locator("#banner-container");
    await banner.waitFor({ state: "visible" });
    for (const bannerHeight of [78, 213]) {
      await banner.evaluate((element, value) => { element.style.height = `${value}px`; }, bannerHeight);
      const bounds = await banner.boundingBox();
      assert.equal(bounds.height, bannerHeight);
      const fit = 1 - bannerHeight / height;
      const snapshot = await waitState(page, eval(`s => s.bottom <= ${fit + 0.003}`));
      if (bannerHeight === 213) assert(snapshot.bottom > fit - 0.03, "Layout reserved more space than measured");
    }
  }
  await page.setViewportSize({ width: 393, height: 851 });
  await page.waitForFunction(() => !document.getElementById("banner-container"));

  for (const level of moon.slice(1)) {
    const result = await solve(page, level);
    assert(result.combo >= 3, `No combo in ${level.id}`);
    if (level !== moon.at(-1)) await button(page, "GAME_NEXT");
  }
  await waitState(page, s => s.clears === 5);
  await button(page, "GAME_BACK_LEVELS");
  await button(page, "LEVEL_BACK");
  await button(page, "GAME_BACK");
  await button(page, "MENU_DAILY_SHORT");
  const daily = await waitState(page, s => s.scene === "daily" && s.grid);
  for (const [y, x] of daily.dailySolution.entries()) {
    await cell(page, daily.grid, daily.dailySolution.length, x, y);
  }
  await waitState(page, s => s.scene === "daily" && s.state === 1 && s.dailyClears === 1 && s.tier === 0);
  await button(page, "GAME_BACK");
  await button(page, "META_ALBUM");
  await waitState(page, s => s.scene === "album" && s.album === 5);
  await button(page, "META_ACHIEVEMENTS");
  await waitState(page, s => s.scene === "achievements");
  await button(page, "META_BACK_ALBUM");
  await button(page, "GAME_BACK");
  await button(page, "MENU_PLAY");
  await button(page, "BONUS_TITLE");
  for (const level of bonus) {
    await solve(page, level);
    if (level !== bonus.at(-1)) await button(page, "GAME_NEXT");
  }
  await waitState(page, s => s.bonusClears === 3);
  await button(page, "LEVEL_BACK");
  await button(page, "GAME_BACK");
  await button(page, "META_SHOP");
  await button(page, "SHOP_TAB_COSTUME");
  await button(page, "COSTUME_MINT_VISOR");
  await waitState(page, s => s.scene === "shop" && s.preview === "mint_visor" && !s.owned.mint_visor);
  for (let remaining = 5; (await state(page)).coins < 425 && remaining > 0; remaining--) {
    const before = (await state(page)).coins;
    await button(page, `Free coins · +25 (${remaining} left)`);
    await page.waitForFunction(previous => {
      const data = JSON.parse(document.documentElement.getAttribute("data-velokity-playthrough"));
      return data.coins === previous + 25;
    }, before);
  }
  await button(page, "Buy · 425 coins");
  await waitState(page, s => s.owned.mint_visor);
  await button(page, "COSTUME_EQUIP");
  await waitState(page, s => s.equipped.helmet === "mint_visor");
  await button(page, "GAME_BACK");
  assert.equal(await page.evaluate(() => window.velokityPortalFixture.saved().meta.equipped.helmet), "mint_visor");
  await openGame(page, url, route);
  await waitState(page, s => s.buttons.MENU_PLAY && s.clears === 5 && s.dailyClears === 1 && s.bonusClears === 3 && s.equipped.helmet === "mint_visor");
  console.log("Playthrough passed: tutorial, resizing, Moon 01–05, daily, album, Bonus Round x3, shop purchase/equip and reload.");
}

async function checkBridgeMigration() {
  const page = await browser.newPage({ viewport: { width: 720, height: 1280 }, locale: "en-US" });
  let bridgeEnabled = false;
  try {
    const errors = watchErrors(page);
    await page.addInitScript(() => {
      window.velokityPortalOptions = { language: "id", audio: false, rewarded: false };
    });
    await page.route("**/playgama-bridge.js", request => bridgeEnabled
      ? request.fulfill({ path: fixture, contentType: "application/javascript" })
      : request.fulfill({ body: "", contentType: "application/javascript" }));
    await openGame(page, url, route);
    await button(page, "TUTORIAL_SKIP");
    await solve(page, moon[0]);
    await button(page, "GAME_BACK");
    await waitForBrowserSave(page, { clears: 1 });
    await openGame(page, url, route);
    await waitState(page, s => s.buttons.MENU_PLAY && s.clears === 1);

    bridgeEnabled = true;
    await openGame(page, url, route);
    await waitState(page, s => s.buttons.MENU_PLAY && s.clears === 1 && s.locale.startsWith("id") && s.muted);
    assert.equal(await page.evaluate(() => window.velokityPortalFixture.saved().coins), 60);
    const migrationWrites = await page.evaluate(() => window.velokityPortalFixture.calls.filter(call => call.startsWith("storage:set:")));
    assert.deepEqual(migrationWrites, ["storage:set:velokity-save-qa"]);
    await openGame(page, url, route);
    await waitState(page, s => s.buttons.MENU_PLAY && s.clears === 1 && s.muted);
    assert.equal(await page.evaluate(() => window.velokityPortalFixture.calls.filter(call => call.startsWith("storage:set:")).length), 0);
    await page.evaluate(() => window.velokityPortalFixture.setAudio(true));
    await waitState(page, s => !s.muted);
    await page.evaluate(() => window.velokityPortalFixture.setPaused(true));
    await waitState(page, s => s.paused && s.muted);
    await page.evaluate(() => {
      Object.defineProperty(document, "hidden", { configurable: true, value: true });
      document.dispatchEvent(new Event("visibilitychange"));
      window.velokityPortalFixture.setPaused(false);
    });
    await waitState(page, s => s.paused && s.muted);
    await page.evaluate(() => {
      delete document.hidden;
      document.dispatchEvent(new Event("visibilitychange"));
    });
    await waitState(page, s => !s.paused && !s.muted);
    await button(page, "META_SHOP");
    await waitState(page, s => s.scene === "shop");
    assert(!(await state(page)).visibleButtons.some(key => key.includes("Koin gratis")));
    await page.evaluate(() => {
      const fixture = window.velokityPortalFixture;
      const saved = fixture.saved();
      saved.settings.language = "en";
      fixture.seed(JSON.stringify(saved));
    });
    await openGame(page, url, route);
    await waitState(page, s => s.buttons.MENU_PLAY && s.locale.startsWith("en"));

    await page.evaluate(() => window.velokityPortalFixture.seed("{broken"));
    await openGame(page, url, route);
    await waitState(page, s => s.first);
    assert.deepEqual(await page.evaluate(() => window.velokityPortalFixture.archives()), ["{broken"]);
    assert(!(await state(page)).visibleButtons.includes("GAME_HINT_AD"));

    await page.evaluate(() => window.velokityPortalFixture.seed('{"version":999}'));
    await openGame(page, url, route);
    await waitState(page, s => s.buttons.MENU_PLAY);
    assert.equal(await page.evaluate(() => window.velokityPortalFixture.saved().version), 999);
    assert.equal(await page.evaluate(() => window.velokityPortalFixture.calls.filter(call => call.startsWith("storage:set:")).length), 0);
    assert.deepEqual(errors, []);
    console.log("Bridge passed: file migration, SDK saves, corrupt and future saves, language, audio, nested pause and unsupported rewarded UI.");
  } finally {
    await page.close();
  }
}

async function measurePhone() {
  const page = await browser.newPage({ viewport: { width: 393, height: 851 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  try {
    const errors = watchErrors(page);
    const performanceUrl = new URL("web-qa/index.html?qa=preview", baseUrl);
    await openGame(page, performanceUrl, "preview");
    await waitState(page, s => s.grid && s.state === 0);
    const throttle = Number(process.env.VELOKITY_CPU_THROTTLE ?? 1);
    if (throttle > 1) {
      const cdp = await page.context().newCDPSession(page);
      await cdp.send("Emulation.setCPUThrottlingRate", { rate: throttle });
    }
    const animation = page.evaluate(() => new Promise(resolve => {
      const frames = [];
      let previous = performance.now();
      const start = previous;
      const tick = now => {
        frames.push(now - previous);
        previous = now;
        if (now - start < 6500) return requestAnimationFrame(tick);
        resolve({ frames, elapsed: now - start });
      };
      requestAnimationFrame(tick);
    }));
    for (const [x, y] of fills(moon[0])) {
      await cell(page, (await state(page)).grid, moon[0].size, x, y);
      await page.waitForTimeout(170);
    }
    const { frames, elapsed } = await animation;
    const last = await waitState(page, s => s.state === 1);
    const fps = frames.length * 1000 / elapsed;
    const p95 = frames.toSorted((a, b) => a - b)[Math.floor(frames.length * 0.95)];
    assert(last.frames > initial.frames && frames.length > 1, "No gameplay frames measured");
    assert.deepEqual(errors, []);
    const target = fps >= 30 && p95 <= 50 ? "met" : "missed";
    const result = `Phone profile 393×851 CSS @2×, SwiftShader, CPU throttle ${throttle}×: ${fps.toFixed(1)} FPS, p95 ${p95.toFixed(1)} ms (30 FPS / 50 ms target ${target}).`;
    console.log(result);
    if (process.env.GITHUB_STEP_SUMMARY) await appendFile(process.env.GITHUB_STEP_SUMMARY, `${result}
`);
  } finally {
    await page.close();
  }
}

try {
  const page = await browser.newPage({ viewport: { width: 393, height: 851 }, hasTouch: true, locale: "en-US", timezoneId: "Asia/Jakarta" });
  try {
    const errors = watchErrors(page);
    await page.route("**/playgama-bridge.js", request => request.fulfill({ path: fixture, contentType: "application/javascript" }));
    await openGame(page, url, route);
    try {
      await runFullPlaythrough(page);
      assert.deepEqual(errors, []);
    } catch (error) {
      console.error("Last playthrough state:", await state(page), "Browser errors:", errors);
      throw error;
    }
  } finally {
    await page.close();
  }
  await checkBridgeMigration();
  await measurePhone();
} finally {
  await browser.close();
}
