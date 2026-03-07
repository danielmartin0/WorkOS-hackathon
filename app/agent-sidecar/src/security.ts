import path from "node:path";
import fs from "node:fs";

export function resolveAppWorkdir(): string {
  const fromEnv = process.env.AGENT_WORKDIR?.trim();
  if (fromEnv && fromEnv.length > 0) {
    return path.resolve(fromEnv);
  }

  const cwd = process.cwd();
  const candidates = [
    cwd,
    path.resolve(cwd, ".."),
    path.resolve(cwd, "../.."),
  ];

  // Prefer the first directory that actually contains /mod.
  const withMod = candidates.find((candidate) =>
    fs.existsSync(path.join(candidate, "mod"))
  );
  return path.resolve(withMod ?? path.resolve(cwd, ".."));
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
