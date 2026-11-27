export const TWO_HOURS_MS = 2 * 60 * 60 * 1000;
const STOP_AT = Date.parse("2026-12-10T00:00:00+07:00");

export function pastDeadline(date) {
  return date.getTime() >= STOP_AT;
}

export function decideAutopilot({
  date, branchAgeMs, lastCommentAgeMs = Infinity, taskDone, completionPosted = false,
}) {
  if (pastDeadline(date)) return "stop";

  const canComment = lastCommentAgeMs > TWO_HOURS_MS;
  if (taskDone) return !completionPosted && canComment ? "complete" : "idle";
  if (branchAgeMs > TWO_HOURS_MS && canComment) return "resume";
  return "idle";
}

export function roadmapTaskDone(roadmap, branchName) {
  const task = /^codex\/(t\d+[a-z]*)(?:[-/]|$)/i.exec(branchName)?.[1];
  if (!task) return false;
  return new RegExp(`^[-*+] +\\[[xX]\\] +${task}(?=\\s|[:.—-]|$)`, "im").test(roadmap);
}
