import { afterEach, describe, expect, test } from "bun:test";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { classifyRecord, collectAgentStatuses } from "./agent-status-lib";

const tempDirs = [];

afterEach(async () => {
	for (const dir of tempDirs.splice(0)) {
		await rm(dir, { recursive: true, force: true });
	}
});

async function createTempDir() {
	const dir = await mkdtemp(path.join(tmpdir(), "pi-agent-status-test-"));
	tempDirs.push(dir);
	return dir;
}

function baseRecord(overrides = {}) {
	const now = new Date().toISOString();
	return {
		version: 1,
		pid: process.pid,
		user: process.env.USER || process.env.LOGNAME || "unknown",
		host: "local",
		sessionId: "sess-1",
		sessionFile: null,
		cwd: "/tmp/project",
		state: "busy",
		startedAt: now,
		updatedAt: now,
		lastActivityAt: now,
		lastEvent: "agent_start",
		currentTool: "read",
		...overrides,
	};
}

describe("classifyRecord", () => {
	test("marks invalid pid as offline", () => {
		const record = baseRecord({ pid: 0, state: "idle" });
		const observed = classifyRecord(record, 30_000);
		expect(observed.observedState).toBe("offline");
	});

	test("marks stale alive record as unknown", () => {
		const old = new Date(Date.now() - 120_000).toISOString();
		const record = baseRecord({ updatedAt: old, state: "busy" });
		const observed = classifyRecord(record, 1_000);
		expect(observed.pidAlive).toBeTrue();
		expect(observed.observedState).toBe("unknown");
	});
});

describe("collectAgentStatuses", () => {
	test("collects and aggregates states", async () => {
		const dir = await createTempDir();
		await writeFile(path.join(dir, "alive.json"), `${JSON.stringify(baseRecord({ state: "busy" }))}\n`, "utf8");
		await writeFile(path.join(dir, "offline.json"), `${JSON.stringify(baseRecord({ pid: 0, state: "idle", sessionId: "sess-2" }))}\n`, "utf8");

		const result = await collectAgentStatuses({
			statusDir: dir,
			staleAfterMs: 30_000,
			allUsers: true,
		});

		expect(result.errors).toEqual([]);
		expect(result.counts.total).toBe(2);
		expect(result.counts.busy).toBe(1);
		expect(result.counts.offline).toBe(1);
	});

	test("tracks invalid files as errors", async () => {
		const dir = await createTempDir();
		await writeFile(path.join(dir, "broken.json"), "{not-json}\n", "utf8");

		const result = await collectAgentStatuses({
			statusDir: dir,
			staleAfterMs: 30_000,
			allUsers: true,
		});

		expect(result.counts.total).toBe(0);
		expect(result.errors.length).toBe(1);
		expect(result.errors[0]).toContain("invalid JSON");
	});
});
