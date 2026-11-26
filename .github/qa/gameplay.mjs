import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";

const stateAttribute = "data-velokity-playthrough";

export async function state(page) {
  return JSON.parse(await page.locator("html").getAttribute(stateAttribute) ?? "{}");
}

export async function waitState(page, check) {
  const match = await page.waitForFunction(
    ([attribute, expression]) => {
      const snapshot = JSON.parse(document.documentElement.getAttribute(attribute) ?? "{}");
      return Object.keys(snapshot).length && Function("s", `return (${expression})(s)`)(snapshot) && snapshot;
    },
    [stateAttribute, check.toString()],
    { timeout: 12_000 },
  );
  return match.jsonValue();
}

export async function point(page, rect, x = 0.5, y = 0.5) {
  const { width, height } = page.viewportSize();
  const px = (rect[0] + rect[2] * x) * width;
  const py = (rect[1] + rect[3] * y) * height;
  assert(px > 0 && px < width && py > 0 && py < height, `Control outside window at ${px}, ${py}`);
  if (await page.evaluate(() => navigator.maxTouchPoints > 0)) await page.touchscreen.tap(px, py);
  else await page.mouse.click(px, py);
}

export async function button(page, key) {
  const rect = await page.waitForFunction(([attribute, key]) => {
    const buttons = JSON.parse(document.documentElement.getAttribute(attribute) ?? "{}").buttons;
    return buttons?.[key];
  }, [stateAttribute, key], { timeout: 12_000 });
  await point(page, await rect.jsonValue());
}

export function cell(page, grid, size, x, y) {
  return point(page, grid, (x + 0.5) / size, (y + 0.5) / size);
}

export async function levels(folder, prefix, count) {
  const dir = new URL(`../../data/levels/${folder}`, import.meta.url);
  const paths = (await readdir(dir)).filter(name => name.startsWith(prefix)).sort().slice(0, count);
  assert.equal(paths.length, count);
  return Promise.all(paths.map(async name => JSON.parse(await readFile(new URL(name, dir), "utf8"))));
}

export function fills(level) {
  return level.solution.flatMap((row, y) => [...row].flatMap((mark, x) => mark === "." ? [] : [[x, y]]));
}
