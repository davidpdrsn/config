import { afterEach, describe, expect, test } from "bun:test";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { classifyRecord, collectAgentStatuses } from "./agent-status-lib";

const tempDirs = [];
const originalEnv = {
	PI_AGENT_STATUS_DIR: process.env.PI_AGENT_STATUS_DIR,
	TMPDIR: process.env.TMPDIR,
};

afterEach(async () => {
	process.env.PI_AGENT_STATUS_DIR = originalEnv.PI_AGENT_STATUS_DIR;
	process.env.TMPDIR = originalEnv.TMPDIR;

	for (const dir of tempDirs.splice(0)) {
		await rm(dir, { recursive: true, force: true });
	}
});

async function createTempDir(prefix = "pi-agent-status-test-") {
	const dir = await mkdtemp(path.join(tmpdir(), prefix));
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

function runCommand(args, cwd) {
	return new Promise((resolve) => {
		const proc = spawn("bun", args, { cwd, stdio: ["ignore", "pipe", "pipe"] });
		let stdout = "";
		let stderr = "";
		proc.stdout.on("data", (chunk) => {
			stdout += chunk.toString();
		});
		proc.stderr.on("data", (chunk) => {
			stderr += chunk.toString();
		});
		proc.on("close", (code) => resolve({ code, stdout, stderr }));
	});
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
		const sessionId = `sess-${Date.now()}-collect`;
		process.env.PI_AGENT_STATUS_DIR = dir;
		await writeFile(path.join(dir, "alive.json"), `${JSON.stringify(baseRecord({ state: "busy", sessionId }))}\n`, "utf8");
		await writeFile(
			path.join(dir, "offline.json"),
			`${JSON.stringify(baseRecord({ pid: 0, state: "idle", sessionId }))}\n`,
			"utf8",
		);

		const result = await collectAgentStatuses({
			staleAfterMs: 30_000,
			allUsers: true,
			sessionId,
		});

		expect(result.errors).toEqual([]);
		expect(result.counts.total).toBe(2);
		expect(result.counts.busy).toBe(1);
		expect(result.counts.offline).toBe(1);
	});

	test("tracks invalid files as errors", async () => {
		const dir = await createTempDir();
		const sessionId = `sess-${Date.now()}-errors`;
		process.env.PI_AGENT_STATUS_DIR = dir;
		await writeFile(path.join(dir, "broken.json"), "{not-json}\n", "utf8");
		await writeFile(path.join(dir, "ok.json"), `${JSON.stringify(baseRecord({ sessionId }))}\n`, "utf8");

		const result = await collectAgentStatuses({
			staleAfterMs: 30_000,
			allUsers: true,
			sessionId,
		});

		expect(result.counts.total).toBe(1);
		expect(result.errors.length).toBe(1);
		expect(result.errors[0]).toContain("invalid JSON");
	});

	test("auto-discovers nix-shell dirs and dedupes duplicate pid by newest updatedAt", async () => {
		const customTmp = await createTempDir("pi-agent-status-tmp-");
		const tmpStatusDir = path.join(customTmp, "pi-agent-status");
		await mkdir(tmpStatusDir, { recursive: true });

		const nixShellRoot = await mkdtemp(path.join("/tmp", "nix-shell."));
		tempDirs.push(nixShellRoot);
		const nixStatusDir = path.join(nixShellRoot, "pi-agent-status");
		await mkdir(nixStatusDir, { recursive: true });

		delete process.env.PI_AGENT_STATUS_DIR;
		process.env.TMPDIR = customTmp;

		const sessionId = `sess-${Date.now()}-dedupe`;
		const oldTs = new Date(Date.now() - 60_000).toISOString();
		const newTs = new Date().toISOString();

		await writeFile(
			path.join(tmpStatusDir, "dup-old.json"),
			`${JSON.stringify(baseRecord({ pid: 43210, sessionId, state: "busy", updatedAt: oldTs }))}\n`,
			"utf8",
		);
		await writeFile(
			path.join(nixStatusDir, "dup-new.json"),
			`${JSON.stringify(baseRecord({ pid: 43210, sessionId, state: "idle", updatedAt: newTs }))}\n`,
			"utf8",
		);

		const result = await collectAgentStatuses({
			staleAfterMs: 30_000,
			allUsers: true,
			sessionId,
		});

		expect(result.errors).toEqual([]);
		expect(result.counts.total).toBe(1);
		expect(result.agents[0].pid).toBe(43210);
		expect(result.agents[0].state).toBe("idle");
	});
});

describe("agent-status CLI", () => {
	test("no longer accepts --status-dir", async () => {
		const piRoot = path.join(import.meta.dir, "..");
		const result = await runCommand(["./scripts/agent-status.ts", "--status-dir", "/tmp"], piRoot);
		expect(result.code).not.toBe(0);
		expect(result.stderr).toContain("statusDir");
	});
});
