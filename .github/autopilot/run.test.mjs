import assert from "node:assert/strict";
import test from "node:test";
import { DONE_COMMENT, RESUME_COMMENT, runAutopilot } from "./run.mjs";

const context = { repo: { owner: "projekpod", repo: "velokity" } };
const fullName = "projekpod/velokity";
const now = new Date("2026-11-26T12:00:00Z");
const target = "codex/t12b-autopilot";
const comment = (body, created_at = "2026-11-26T09:00:00Z", id = 42) => ({ body, user: { id }, created_at });

function fixture({ done = false, open = false, draft = true, actorComments = [], stale = false, fresh = false, existingMerge = false, createFails = false, raced = false } = {}) {
  const changes = [];
  const warnings = [];
  const candidatePull = {
    number: 8, state: "open", draft,
    head: { ref: target, repo: { full_name: fullName } }, base: { ref: "main" },
  };
  const mergedPull = {
    state: "closed", merged_at: "2026-11-26T11:45:00Z",
    head: { ref: "codex/t12-complete", sha: "2", repo: { full_name: fullName } }, base: { ref: "main" },
  };
  const pulls = [mergedPull];
  if (open) pulls.push(candidatePull);
  if (existingMerge) pulls.push({ ...mergedPull, head: { ...candidatePull.head, sha: "older" } });
  const branches = ["main", target, "codex/t12-complete", "codex/t13-behind", "other"];
  const core = { notice() {}, info() {}, warning(message) { warnings.push(message); } };
  const github = {
    paginate: async (method, params) => (await method(params)).data,
    rest: {
      repos: {
        listBranches: async () => ({ data: branches.map((name, index) => ({ name, commit: { sha: String(index) } })) }),
        getCommit: async ({ ref }) => {
          assert.notEqual(ref, "2", "exclude already merged PR branches before fetching commit data");
          const date = ref === "3" ? "2026-11-26T11:30:00Z" : fresh ? "2026-11-26T11:00:00Z" : "2026-11-26T08:00:00Z";
          return { data: { commit: { committer: { date } } } };
        },
        compareCommitsWithBasehead: async ({ basehead }) => {
          assert.ok(["0...3", "0...1"].includes(basehead));
          return { data: { ahead_by: basehead === "0...1" ? 1 : 0 } };
        },
        getContent: async ({ path, ref }) => {
          assert.equal(path, "ROADMAP.md");
          assert.equal(ref, "1", "read the selected commit, not the latest branch ref");
          const content = Buffer.from(`- [${done ? "x" : " "}] T12b Autopilot & CI hygiene\n`).toString("base64");
          return { data: { type: "file", encoding: "base64", content } };
        },
      },
      pulls: {
        list: async ({ state }) => ({ data: state === "open" && raced ? [candidatePull] : pulls }),
        create: async ({ base, head, title, draft }) => {
          if (createFails) throw new Error("PR creation failed");
          changes.push(["create", base, head, title, draft]);
          return { data: candidatePull };
        },
      },
      git: {
        getRef: async ({ ref }) => {
          assert.equal(ref, `heads/${target}`);
          return { data: { object: { sha: stale ? "moved" : "1" } } };
        },
      },
      users: { getAuthenticated: async () => ({ data: { id: 42 } }) },
      issues: {
        listComments: async ({ issue_number }) => {
          assert.equal(issue_number, candidatePull.number);
          return { data: actorComments };
        },
        createComment: async ({ issue_number, body }) => changes.push(["comment", issue_number, body]),
      },
    },
  };
  return { github, context, core, now, changes, warnings };
}

test("pick the newest eligible branch, open its regular PR, and resume an old task", async () => {
  const run = fixture();
  await runAutopilot(run);
  assert.deepEqual(run.changes, [
    ["create", "main", target, "T12b Autopilot", false],
    ["comment", 8, RESUME_COMMENT],
  ]);
});

test("a fresh eligible branch gets a regular PR without a resume comment", async () => {
  const run = fixture({ fresh: true });
  await runAutopilot(run);
  assert.deepEqual(run.changes, [["create", "main", target, "T12b Autopilot", false]]);
});

test("new commits on a previously merged branch can become the current task", async () => {
  const run = fixture({ existingMerge: true });
  await runAutopilot(run);
  assert.deepEqual(run.changes, [
    ["create", "main", target, "T12b Autopilot", false],
    ["comment", 8, RESUME_COMMENT],
  ]);
});

test("ordinary comments and copies from another author do not affect the cooldown", async () => {
  const run = fixture({ open: true, actorComments: [
    comment("Review in progress.", "2026-11-26T11:30:00Z"),
    comment(RESUME_COMMENT, "2026-11-26T11:30:00Z", 13),
  ] });
  await runAutopilot(run);
  assert.deepEqual(run.changes, [["comment", 8, RESUME_COMMENT]]);
});

test("a recent Autopilot ping prevents another ping", async () => {
  const run = fixture({ open: true, actorComments: [comment(RESUME_COMMENT, "2026-11-26T11:00:00Z")] });
  await runAutopilot(run);
  assert.deepEqual(run.changes, []);
});

test("a completed task is announced once, including on existing drafts", async () => {
  const first = fixture({ done: true, open: true });
  await runAutopilot(first);
  assert.deepEqual(first.changes, [["comment", 8, DONE_COMMENT]]);

  const second = fixture({ done: true, open: true, draft: false, actorComments: [comment(DONE_COMMENT)] });
  await runAutopilot(second);
  assert.deepEqual(second.changes, []);
});

test("a recent ping delays the completion comment", async () => {
  const run = fixture({ done: true, open: true, actorComments: [comment(RESUME_COMMENT, "2026-11-26T11:00:00Z")] });
  await runAutopilot(run);
  assert.deepEqual(run.changes, []);
});

test("skip a moving branch and avoid all GitHub calls after the deadline", async () => {
  const run = fixture({ stale: true });
  await runAutopilot(run);
  assert.deepEqual(run.changes, []);
  await runAutopilot({ now: new Date("2026-12-10T00:00:00+07:00"), core: { notice() {} } });
});

test("an optional PR creation failure warns and still posts either comment if a PR already exists", async () => {
  for (const [done, body] of [[false, RESUME_COMMENT], [true, DONE_COMMENT]]) {
    const run = fixture({ done, createFails: true, raced: true });
    await runAutopilot(run);
    assert.deepEqual(run.changes, [["comment", 8, body]]);
    assert.match(run.warnings[0], /PR creation failed/);
  }
  const missing = fixture({ createFails: true });
  await runAutopilot(missing);
  assert.deepEqual(missing.changes, []);
  assert.equal(missing.warnings.length, 1);
});
