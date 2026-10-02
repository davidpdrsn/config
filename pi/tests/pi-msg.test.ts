import { afterEach, beforeEach, expect, test } from "bun:test";
import { mkdtemp, realpath, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

let directory: string;
const script = path.resolve(import.meta.dir, "../scripts/pi-msg.ts");

beforeEach(async () => {
	directory = await realpath(await mkdtemp(path.join(tmpdir(), "pi-msg-test-")));
});

afterEach(async () => {
	await rm(directory, { recursive: true, force: true });
});

async function record(sessionId: string) {
	// An existing non-socket path ensures --check never attempts delivery.
	const socketPath = path.join(directory, `${sessionId}.sock`);
	await writeFile(socketPath, "");
	await writeFile(path.join(directory, `${sessionId}.json`), JSON.stringify({
		version: 1,
		pid: process.pid,
		user: "test",
		host: "test",
		cwd: directory,
		socketPath,
		sessionId,
		sessionFile: null,
		startedAt: new Date().toISOString(),
		updatedAt: new Date().toISOString(),
	}));
}

async function check(...args: string[]) {
	const child = Bun.spawn([process.execPath, script, "--check", ...args], {
		env: { ...process.env, PI_MESSAGE_AGENT_DIR: directory, PI_MSG_CALLER_CWD: directory },
		stdout: "pipe",
		stderr: "pipe",
	});
	return { code: await child.exited, stderr: await new Response(child.stderr).text() };
}

test("preflight rejects missing targets without requiring a message", async () => {
	const result = await check();
	expect(result.code).toBe(1);
	expect(result.stderr).toContain("no running pi agent found");
});

test("preflight succeeds without sending to the target", async () => {
	await record("first");
	expect(await check()).toEqual({ code: 0, stderr: "" });
});

test("preflight rejects ambiguous targets and supports session filtering", async () => {
	await record("first");
	await record("second");
	const result = await check();
	expect(result.code).toBe(1);
	expect(result.stderr).toContain("multiple running pi agents found");
	expect(await check("--session", "first")).toEqual({ code: 0, stderr: "" });
});

test("preflight honors an explicit cwd", async () => {
	await record("first");
	const result = await check("--cwd", path.join(directory, "other"));
	expect(result.code).toBe(1);
	expect(result.stderr).toContain("no running pi agent found");
});
