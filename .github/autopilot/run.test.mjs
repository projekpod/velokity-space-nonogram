import assert from "node:assert/strict";
import test from "node:test";
import { DONE_COMMENT, RESUME_COMMENT, runAutopilot } from "./run.mjs";

const context = { repo: { owner: "projekpod", repo: "velokity" } };
const fullName = "projekpod/velokity";
const now = new Date("2026-11-26T12:00:00Z");
const target = "codex/t12b-autopilot";
const comment = (body, created_at = "2026-11-26T09:00:00Z", id = 42) => ({ body, user: { id }, created_at });

function fixture({ done = false, open = false, draft = true, actorComments = [], stale = false, fresh = false, existingMerge = false } = {}) {
  const changes = [];
  const candidatePull = {
    number: 8, node_id: "PR_node", state: "open", draft,
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
  const core = { notice() {}, info() {} };
  const github = {
    paginate: async (method, params) => (await method(params)).data,
    graphql: async (query, params) => {
      assert.match(query, /markPullRequestReadyForReview/);
      changes.push(["ready", params.id]);
      candidatePull.draft = false;
    },
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
        list: async () => ({ data: pulls }),
        create: async ({ base, head, title, draft }) => {
          changes.push(["draft", base, head, title, draft]);
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
  return { github, context, core, now, changes };
}

test("pick the newest eligible branch, open its draft, and resume an old task", async () => {
  const run = fixture();
  await runAutopilot(run);
  assert.deepEqual(run.changes, [
    ["draft", "main", target, "T12b Autopilot", true],
    ["comment", 8, RESUME_COMMENT],
  ]);
});

test("a fresh eligible branch gets a draft without a resume comment", async () => {
  const run = fixture({ fresh: true });
  await runAutopilot(run);
  assert.deepEqual(run.changes, [["draft", "main", target, "T12b Autopilot", true]]);
});

test("new commits on a previously merged branch can become the current task", async () => {
  const run = fixture({ existingMerge: true });
  await runAutopilot(run);
  assert.deepEqual(run.changes, [
    ["draft", "main", target, "T12b Autopilot", true],
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

test("a completed task becomes ready and is announced once", async () => {
  const first = fixture({ done: true, open: true });
  await runAutopilot(first);
  assert.deepEqual(first.changes, [["ready", "PR_node"], ["comment", 8, DONE_COMMENT]]);

  const second = fixture({ done: true, open: true, draft: false, actorComments: [comment(DONE_COMMENT)] });
  await runAutopilot(second);
  assert.deepEqual(second.changes, []);
});

test("a recent ping delays the completion comment while the PR becomes ready", async () => {
  const run = fixture({ done: true, open: true, actorComments: [comment(RESUME_COMMENT, "2026-11-26T11:00:00Z")] });
  await runAutopilot(run);
  assert.deepEqual(run.changes, [["ready", "PR_node"]]);
});

test("skip a moving branch and avoid all GitHub calls after the deadline", async () => {
  const run = fixture({ stale: true });
  await runAutopilot(run);
  assert.deepEqual(run.changes, []);
  await runAutopilot({ now: new Date("2026-12-10T00:00:00+07:00"), core: { notice() {} } });
});
