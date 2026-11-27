import { decideAutopilot, pastDeadline, roadmapTaskDone } from "./decision.mjs";

export const DONE_COMMENT = "Autopilot: task selesai, menunggu review Claude";
export const RESUME_COMMENT = "@codex Continue the unfinished ROADMAP task on this branch from HANDOFF.md. Follow AGENTS.md, do not redo finished parts, commit and push after each part, keep CI green, and mark the task [x] in ROADMAP.md when it is complete.";

function branchTitle(name) {
  return name.slice("codex/".length).split(/[-/]+/).filter(Boolean)
    .map(word => word[0].toUpperCase() + word.slice(1)).join(" ");
}

function findOpenPull(pulls, repo, branch) {
  const fullName = `${repo.owner}/${repo.repo}`.toLowerCase();
  const open = pulls.filter(pull => pull.state === "open" && pull.head.ref === branch
    && pull.head.repo?.full_name.toLowerCase() === fullName);
  return open.find(pull => pull.base.ref === "main") ?? open[0];
}

async function pickBranch(github, repo) {
  const branches = await github.paginate(github.rest.repos.listBranches, { ...repo, per_page: 100 });
  const main = branches.find(branch => branch.name === "main");
  if (!main) throw new Error("The main branch is missing.");

  const fullName = `${repo.owner}/${repo.repo}`.toLowerCase();
  const pulls = await github.paginate(github.rest.pulls.list, { ...repo, state: "all", per_page: 100 });
  const localPulls = pulls.filter(pull => pull.head.repo?.full_name.toLowerCase() === fullName);
  // A merged PR also covers squash merges whose head SHA is not in main's ancestry.
  const mergedHeads = new Set(localPulls.filter(pull => pull.base.ref === "main" && pull.merged_at)
    .map(pull => pull.head.sha));

  const candidates = [];
  for (const branch of branches) {
    if (!branch.name.startsWith("codex/") || mergedHeads.has(branch.commit.sha) || branch.commit.sha === main.commit.sha) continue;
    const { data } = await github.rest.repos.getCommit({ ...repo, ref: branch.commit.sha, per_page: 1 });
    candidates.push({ name: branch.name, sha: branch.commit.sha, committedAt: Date.parse(data.commit.committer.date) });
  }
  candidates.sort((a, b) => b.committedAt - a.committedAt || a.name.localeCompare(b.name));

  for (const branch of candidates) {
    const { data } = await github.rest.repos.compareCommitsWithBasehead({
      ...repo, basehead: `${main.commit.sha}...${branch.sha}`, per_page: 1,
    });
    if (data.ahead_by > 0) {
      return { branch, pull: findOpenPull(localPulls, repo, branch.name) };
    }
  }
  return {};
}

async function stillCurrent(github, repo, branch, core) {
  try {
    const { data } = await github.rest.git.getRef({ ...repo, ref: `heads/${branch.name}` });
    if (data.object.sha === branch.sha) return true;
  } catch (error) {
    if (error.status !== 404) throw error;
  }
  core.notice(`${branch.name} changed during the run. Waiting for the next check.`);
  return false;
}

export async function runAutopilot({ github, context, core, now = new Date() }) {
  if (pastDeadline(now)) {
    core.notice("Autopilot passed its 9 December 2026 deadline in Jakarta.");
    return;
  }

  const repo = context.repo;
  let { branch, pull } = await pickBranch(github, repo);
  if (!branch) {
    core.notice("No unmerged codex branch is ahead of main.");
    return;
  }

  // Read project state from the selected commit. The workflow executes code from main.
  const { data: roadmap } = await github.rest.repos.getContent({ ...repo, path: "ROADMAP.md", ref: branch.sha });
  if (roadmap.type !== "file" || roadmap.encoding !== "base64") {
    throw new Error("ROADMAP.md must be a regular UTF-8 Markdown file.");
  }
  const taskDone = roadmapTaskDone(Buffer.from(roadmap.content, "base64").toString("utf8"), branch.name);

  if (!await stillCurrent(github, repo, branch, core)) return;
  if (!pull) {
    try {
      const created = await github.rest.pulls.create({
        ...repo, base: "main", head: branch.name, title: branchTitle(branch.name), draft: false,
      });
      pull = created.data;
      core.info(`Opened PR #${pull.number} for ${branch.name}.`);
    } catch (error) {
      core.warning(`Could not open a PR for ${branch.name}: ${error.message}`);
      // A contributor may have opened the PR since branch selection.
      try {
        const open = await github.paginate(github.rest.pulls.list, {
          ...repo, state: "open", head: `${repo.owner}:${branch.name}`,
        });
        pull = findOpenPull(open, repo, branch.name);
      } catch (lookupError) {
        core.warning(`Could not refresh the PR for ${branch.name}: ${lookupError.message}`);
      }
      if (!pull) return;
    }
  }

  const { data: actor } = await github.rest.users.getAuthenticated();
  const comments = await github.paginate(github.rest.issues.listComments, { ...repo, issue_number: pull.number, per_page: 100 });
  const autopilotComments = comments.filter(comment => comment.user?.id === actor.id
    && (comment.body === RESUME_COMMENT || comment.body === DONE_COMMENT));
  const lastComment = Math.max(...autopilotComments.map(comment => Date.parse(comment.created_at)));
  const action = decideAutopilot({
    date: now,
    branchAgeMs: now.getTime() - branch.committedAt,
    lastCommentAgeMs: now.getTime() - lastComment,
    taskDone,
    completionPosted: autopilotComments.some(comment => comment.body === DONE_COMMENT),
  });

  if (action === "idle" || action === "stop") {
    core.info(`No Autopilot action is due for PR #${pull.number}.`);
    return;
  }
  if (!await stillCurrent(github, repo, branch, core)) return;

  await github.rest.issues.createComment({
    ...repo, issue_number: pull.number, body: action === "complete" ? DONE_COMMENT : RESUME_COMMENT,
  });
  core.info(`Posted the ${action} comment on PR #${pull.number}.`);
}
