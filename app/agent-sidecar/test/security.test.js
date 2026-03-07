import { describe, expect, it } from "vitest";
import { ensurePathWithinWorkdir } from "../src/security.js";
describe("ensurePathWithinWorkdir", () => {
    it("accepts files inside workdir", () => {
        const resolved = ensurePathWithinWorkdir("/tmp/app", "/tmp/app/captures/shot.png");
        expect(resolved).toBe("/tmp/app/captures/shot.png");
    });
    it("rejects files outside workdir", () => {
        expect(() => ensurePathWithinWorkdir("/tmp/app", "/tmp/other/shot.png")).toThrow(/inside AGENT_WORKDIR/);
    });
});
