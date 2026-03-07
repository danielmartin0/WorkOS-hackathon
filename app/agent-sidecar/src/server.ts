import fs from "node:fs";
import path from "node:path";
import express from "express";
import { runAgentQuery } from "./agent.js";
import { ensurePathWithinWorkdir, resolveAppWorkdir } from "./security.js";
import { AgentRequestSchema } from "./types.js";

export function createServer() {
  const app = express();
  const workdir = resolveAppWorkdir();

  app.use(express.json({ limit: "2mb" }));

  app.get("/health", (_req, res) => {
    res.json({ ok: true, workdir });
  });

  app.post("/agent/query", async (req, res) => {
    try {
      const input = AgentRequestSchema.parse(req.body);

      const sanitizedInput = {
        ...input,
        screenshotPath: normalizeScreenshotPath(workdir, input.screenshotPath),
      };

      const result = await runAgentQuery(sanitizedInput);
      res.json(result);
    } catch (error) {
      const message = error instanceof Error ? error.message : "unknown error";
      res.status(400).json({ error: message });
    }
  });

  return app;
}

function normalizeScreenshotPath(workdir: string, screenshotPath?: string): string | undefined {
  if (!screenshotPath) {
    return undefined;
  }

  const resolved = ensurePathWithinWorkdir(workdir, screenshotPath);
  if (!fs.existsSync(resolved)) {
    throw new Error("screenshotPath does not exist");
  }

  return path.resolve(resolved);
}
