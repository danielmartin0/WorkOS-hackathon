import { randomUUID } from "node:crypto";
import { query } from "@anthropic-ai/claude-agent-sdk";
import type { AgentRequest, AgentResponse } from "./types.js";

const ALLOWED_TOOLS = ["Read", "Write"] as const;

function buildPrompt(input: AgentRequest): string {
  const screenshotNote = input.screenshotPath
    ? `\n\nLatest screenshot path (read-only context): ${input.screenshotPath}`
    : "";

  return `${input.prompt}${screenshotNote}`;
}

export async function runAgentQuery(input: AgentRequest): Promise<AgentResponse> {
  const prompt = buildPrompt(input);
  let nextSessionId = input.sessionId ?? "";
  const textParts: string[] = [];

  for await (const message of query({
    prompt,
    options: {
      allowedTools: [...ALLOWED_TOOLS],
      settingSources: ["project"],
      ...(input.sessionId ? { resume: input.sessionId } : {}),
    } as never,
  })) {
    const msg = message as Record<string, unknown>;

    if (
      msg.type === "system" &&
      msg.subtype === "init" &&
      typeof msg.session_id === "string"
    ) {
      nextSessionId = msg.session_id;
    }

    if (typeof msg.result === "string" && msg.result.trim().length > 0) {
      textParts.push(msg.result);
    }
  }

  const text = textParts.join("\n\n").trim() || "No response from Claude Agent SDK.";
  const sessionId = nextSessionId || randomUUID();

  return { text, sessionId };
}
