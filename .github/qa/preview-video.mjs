import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdir, mkdtemp, rm, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { launch, openGame, watchErrors } from "./browser.mjs";
import { cell, fills, levels, state, waitState } from "./gameplay.mjs";

const [baseUrl, output] = process.argv.slice(2);
assert(baseUrl && output, "Usage: node .github/qa/preview-video.mjs <base-url> <output-dir>");

const duration = 15.25;
const [moon] = await levels("", "moon-", 1);
const browser = await launch();

async function record(page, directory, name, width, height) {
  const errors = watchErrors(page);
  await page.route("**/playgama-bridge.js", route => route.fulfill({ contentType: "application/javascript", body: "" }));
  await openGame(page, new URL("web-qa/index.html?qa=preview", baseUrl), "preview");
  const initial = await waitState(page, s => s.grid && s.state === 0);
  assert.equal(initial.scene, moon.id);

  const cdp = await page.context().newCDPSession(page);
  const frames = [];
  const writes = [];
  cdp.on("Page.screencastFrame", ({ data, metadata, sessionId }) => {
    const filename = `frame-${frames.length}.jpg`;
    frames.push({ filename, time: metadata.timestamp });
    writes.push(writeFile(join(directory, filename), Buffer.from(data, "base64")));
    void cdp.send("Page.screencastFrameAck", { sessionId }).catch(() => {});
  });
  await cdp.send("Page.startScreencast", { format: "jpeg", quality: 88, maxWidth: width, maxHeight: height, everyNthFrame: 1 });
  const start = performance.now();
  const waitUntil = ms => page.waitForTimeout(Math.max(0, start + ms - performance.now()));
  const moves = fills(moon);
  const combo = waitState(page, s => s.tier === 2 && s.combo >= 3 && s.state === 0);
  for (const [index, [x, y]] of moves.entries()) {
    await waitUntil(850 + index * 690);
    await cell(page, (await state(page)).grid, moon.size, x, y);
  }
  const comboState = await combo;
  const result = await waitState(page, s => s.state === 1 && s.result && s.tier === 0);
  assert(result.combo >= comboState.combo && result.clears === 1);
  await waitUntil((duration + 0.35) * 1000);
  await cdp.send("Page.stopScreencast");
  await Promise.all(writes);
  assert(frames.length >= 45, `Too few frames captured: ${frames.length}`);
  assert.deepEqual(errors, []);

  const concat = frames.map((frame, index) => {
    const next = frames[index + 1];
    return next
      ? `file '${frame.filename}'\nduration ${Math.max(next.time - frame.time, 0.001).toFixed(6)}`
      : `file '${frame.filename}'`;
  });
  await writeFile(join(directory, "frames.txt"), concat.join("\n") + "\n");
  const target = resolve(output, `preview-${name}.mp4`);
  execFileSync("ffmpeg", [
    "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", "frames.txt",
    "-map", "0:v:0", "-vf", `scale=${width}:${height}:flags=lanczos,tpad=stop_mode=clone:stop_duration=1,fps=30`,
    "-c:v", "libx264", "-threads", "2", "-pix_fmt", "yuv420p", "-crf", "20",
    "-movflags", "+faststart", "-t", String(duration), target,
  ], { cwd: directory, stdio: "inherit" });
  const metadata = JSON.parse(execFileSync("ffprobe", [
    "-v", "error", "-show_entries", "stream=codec_name,width,height:format=duration",
    "-of", "json", target,
  ], { encoding: "utf8" }));
  assert.deepEqual(metadata.streams, [{ codec_name: "h264", width, height }]);
  const seconds = Number(metadata.format.duration);
  assert(seconds >= 15 && seconds < 16 && (await stat(target)).size < 50_000_000);
  console.log(`preview-${name}.mp4 · ${width}×${height} · ${seconds.toFixed(2)} s · ${frames.length} captured frames`);
}

try {
  await mkdir(output, { recursive: true });
  for (const [name, width, height, viewport] of [
    ["landscape", 1920, 1080, { width: 1280, height: 720 }],
    ["portrait", 1080, 1620, { width: 800, height: 1200 }],
  ]) {
    const directory = await mkdtemp(join(tmpdir(), "velokity-video-"));
    const page = await browser.newPage({ viewport, locale: "en-US" });
    try {
      await record(page, directory, name, width, height);
    } finally {
      await page.close();
      await rm(directory, { recursive: true, force: true });
    }
  }
} finally {
  await browser.close();
}
