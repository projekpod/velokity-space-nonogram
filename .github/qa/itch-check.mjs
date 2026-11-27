import assert from "node:assert/strict";
import { launch, openGame, watchErrors } from "./browser.mjs";
import { button, cell, fills, levels, point, state, waitState } from "./gameplay.mjs";

const [baseUrl] = process.argv.slice(2);
assert(baseUrl, "Usage: node .github/qa/itch-check.mjs <base-url>");
const qaUrl = new URL("web-qa/index.html?qa=playthrough", baseUrl);
const releaseUrl = new URL("itchio/index.html", baseUrl);
const hostUrl = new URL("itchio-test-host.html", baseUrl);
const supportUrl = "https://trakteer.id/velokity_project";
const viewport = { width: 720, height: 1280 };
const [moon] = await levels("", "moon-", 2);

async function checkMock(scope) {
  const capabilities = await scope.evaluate(() => {
    const { platform, advertisement, isInitialized } = window.bridge;
    return {
      platform: platform.id, links: platform.isExternalLinksAllowed, initialized: isInitialized,
      banner: advertisement.isBannerSupported, rewarded: advertisement.isRewardedSupported,
      interstitial: advertisement.isInterstitialSupported,
    };
  });
  assert.deepEqual(capabilities, {
    platform: "mock", links: true, initialized: true, banner: false, rewarded: false, interstitial: false,
  });
}

async function checkControls(page) {
  const errors = watchErrors(page);
  await openGame(page, qaUrl, "playthrough");
  await checkMock(page);
  await waitState(page, s => s.first && s.grid && s.buttons.TUTORIAL_SKIP);
  await button(page, "TUTORIAL_SKIP");
  const ready = await waitState(page, s => s.step === 3 && s.grid);
  assert(!ready.visibleButtons.includes("GAME_HINT_AD"));
  for (const x of [0, 1, 3]) {
    assert.equal(moon.solution[0][x], ".");
    await cell(page, (await state(page)).grid, moon.size, x, 0);
  }
  const loss = await waitState(page, s => s.state === 2 && s.result);
  assert(!loss.visibleButtons.includes("GAME_CONTINUE_AD"));
  await button(page, "GAME_RETRY");
  for (const [x, y] of fills(moon)) {
    const { grid } = await waitState(page, s => s.first && s.grid && s.state === 0);
    await cell(page, grid, moon.size, x, y);
  }
  const win = await waitState(page, s => s.state === 1 && s.result && s.tier === 0, 25_000);
  assert.equal(win.lives, 3);
  assert(!win.visibleButtons.includes("GAME_DOUBLE_AD"));
  await button(page, "GAME_BACK");
  const menu = await waitState(page, s => s.buttons.MENU_PLAY && s.buttons.MENU_SUPPORT && !s.paused);
  await button(page, "META_SHOP");
  const shop = await waitState(page, s => s.scene === "shop");
  assert(!shop.visibleButtons.some(text => text.startsWith("Free coins")));
  await button(page, "GAME_BACK");
  await button(page, "MENU_PLAY");
  await button(page, "Moon · 1/20 cleared");
  await button(page, "level2");
  await page.setViewportSize({ width: 960, height: 720 });
  await waitState(page, s => !s.first && s.grid && s.state === 0);
  assert.equal(await page.locator("#banner-container").count(), 0);
  assert.deepEqual(errors, []);

  const save = await page.evaluate(async () => {
    const [snapshot] = await window.bridge.storage.get(["velokity-save-qa"], false);
    return snapshot;
  });
  assert.equal(JSON.parse(save).onboarding_complete, true);
  return { save, support: menu.buttons.MENU_SUPPORT };
}

async function checkZip(context, page, support) {
  const errors = watchErrors(page);
  await page.route(url => url.href === hostUrl.href, route => route.fulfill({
    contentType: "text/html",
    body: `<!doctype html><body style="margin:0"><iframe name="game" allow="autoplay; fullscreen" style="display:block;width:100vw;height:100vh;border:0" src="${releaseUrl}"></iframe>`,
  }));
  const loaded = page.waitForEvent("console", {
    predicate: message => message.text().includes("WebGL 2.0"), timeout: 30_000,
  });
  await Promise.all([page.goto(hostUrl.href), loaded]);
  const game = page.frame({ name: "game" });
  assert(game);
  await game.locator("#status").waitFor({ state: "detached", timeout: 30_000 });
  await game.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  await checkMock(game);
  await context.route(supportUrl, route => route.fulfill({ status: 200, body: "Support link verified" }));
  const outbound = context.waitForEvent("request", {
    predicate: request => request.url() === supportUrl, timeout: 12_000,
  });
  await point(page, support);
  await outbound;
  assert.deepEqual(errors, []);
}

const browser = await launch();
try {
  const context = await browser.newContext({ viewport, locale: "en-US" });
  const qa = await context.newPage();
  const { save, support } = await checkControls(qa);
  await qa.evaluate(snapshot => window.bridge.storage.set("velokity-save", snapshot), save);
  await qa.close();
  await checkZip(context, await context.newPage(), support);
  console.log("itch.io passed: packaged Web iframe uses Bridge mock, unsupported ads are hidden, and Traktir opens the configured URL.");
} finally {
  await browser.close();
}
