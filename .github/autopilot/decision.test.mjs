import assert from "node:assert/strict";
import test from "node:test";
import { decideAutopilot, roadmapTaskDone, TWO_HOURS_MS } from "./decision.mjs";

const deadline = new Date("2026-12-10T00:00:00+07:00");
const old = TWO_HOURS_MS + 1;
const date = new Date(deadline.getTime() - 1);
const run = overrides => decideAutopilot({ date, branchAgeMs: old, ...overrides });

test("resume only when the newest commit and last comment are both older than two hours", () => {
  assert.equal(run({}), "resume");
  assert.equal(run({ lastCommentAgeMs: old }), "resume");
  assert.equal(run({ branchAgeMs: TWO_HOURS_MS }), "idle");
  assert.equal(run({ lastCommentAgeMs: TWO_HOURS_MS }), "idle");
  assert.equal(run({ branchAgeMs: 0 }), "idle");
});

test("a completed task gets a note that respects the comment cooldown", () => {
  assert.equal(run({ branchAgeMs: 0, taskDone: true }), "complete");
  assert.equal(run({ taskDone: true, lastCommentAgeMs: TWO_HOURS_MS }), "idle");
  assert.equal(run({ taskDone: true, lastCommentAgeMs: old }), "complete");
  assert.equal(run({ taskDone: true, completionPosted: true }), "idle");
});

test("the deadline includes all of 9 December in Jakarta", () => {
  assert.equal(run({ date, taskDone: true }), "complete");
  assert.equal(run({ date: deadline, taskDone: true }), "stop");
  assert.equal(run({ date: new Date("2026-12-10T12:00:00+07:00") }), "stop");
});

test("the branch maps to its exact top-level task, including a letter suffix", () => {
  const roadmap = "- [x] T12 Feel & Shop\n- [ ] T12b Autopilot\n  - [x] Complete a subtask\n- [x] T12bc Another task";
  assert.equal(roadmapTaskDone(roadmap, "codex/t12-feel-shop"), true);
  assert.equal(roadmapTaskDone(roadmap, "codex/t12b-autopilot"), false);
  assert.equal(roadmapTaskDone(roadmap.replace("[ ] T12b", "[X] T12b"), "codex/t12b-autopilot"), true);
  assert.equal(roadmapTaskDone("- [x] T13: Content", "codex/t13/content"), true);
  assert.equal(roadmapTaskDone(roadmap, "codex/cleanup"), false);
});
