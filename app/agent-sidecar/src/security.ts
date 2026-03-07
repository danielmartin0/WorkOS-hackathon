import path from "node:path";

export function resolveAppWorkdir(): string {
  const fromEnv = process.env.AGENT_WORKDIR?.trim();
  const fallback = path.resolve(process.cwd(), "..");
  return path.resolve(fromEnv && fromEnv.length > 0 ? fromEnv : fallback);
}

export function ensurePathWithinWorkdir(workdir: string, candidate: string): string {
  const resolvedWorkdir = path.resolve(workdir);
  const resolvedCandidate = path.resolve(candidate);
  const relative = path.relative(resolvedWorkdir, resolvedCandidate);
  if (relative.startsWith("..") || path.isAbsolute(relative)) {
    throw new Error("screenshotPath must be inside AGENT_WORKDIR");
  }
  return resolvedCandidate;
}
