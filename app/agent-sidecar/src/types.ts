import { z } from "zod";

export const AgentRequestSchema = z.object({
  prompt: z.string().min(1),
  sessionId: z.string().optional(),
  screenshotPath: z.string().optional(),
});

export const AgentResponseSchema = z.object({
  text: z.string(),
  sessionId: z.string(),
});

export type AgentRequest = z.infer<typeof AgentRequestSchema>;
export type AgentResponse = z.infer<typeof AgentResponseSchema>;
