import { afterEach, expect, test } from "bun:test";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import activityStatus from "../extensions/activity-status";

type Handler = (event: unknown, ctx: ExtensionContext) => unknown;
let cleanup: (() => Promise<void>) | undefined;
afterEach(async () => { await cleanup?.(); cleanup = undefined; });

async function fixture(entries: { type: string }[] = [], pending = false) {
	const dir = await mkdtemp(path.join(tmpdir(), "pi-untouched-test-"));
	const previous = process.env.PI_AGENT_STATUS_DIR;
	process.env.PI_AGENT_STATUS_DIR = dir;
	const handlers = new Map<string, Handler>();
	activityStatus({ on: (name: string, handler: Handler) => handlers.set(name, handler) } as unknown as ExtensionAPI);
	const ctx = {
		cwd: dir,
		isIdle: () => true,
		hasPendingMessages: () => pending,
		sessionManager: {
			getSessionId: () => "blank",
			getSessionFile: () => path.join(dir, "not-yet-written.jsonl"),
			getEntries: () => entries,
			getBranch: () => [],
		},
	} as unknown as ExtensionContext;
	async function emit(name: string, event: unknown = {}) { await handlers.get(name)?.(event, ctx); }
	cleanup = async () => {
		await emit("session_shutdown");
		await rm(dir, { recursive: true, force: true });
		if (previous === undefined) delete process.env.PI_AGENT_STATUS_DIR;
		else process.env.PI_AGENT_STATUS_DIR = previous;
	};
	return {
		emit,
		read: async () => JSON.parse(await readFile(path.join(dir, `${process.pid}.json`), "utf8")),
	};
}

test("new session with only model metadata is explicitly untouched", async () => {
	const status = await fixture([{ type: "model_change" }, { type: "thinking_level_change" }]);
	await status.emit("session_start");
	expect((await status.read()).untouched).toBe(true);
});

test("messages elsewhere in the tree prevent fresh recovery", async () => {
	const status = await fixture([{ type: "message" }]);
	await status.emit("session_start");
	expect((await status.read()).untouched).toBe(false);
});

test("compacted history is not an untouched session", async () => {
	const status = await fixture([{ type: "compaction" }]);
	await status.emit("session_start");
	expect((await status.read()).untouched).toBe(false);
});

test("custom conversation context is not an untouched session", async () => {
	const status = await fixture([{ type: "custom_message" }]);
	await status.emit("session_start");
	expect((await status.read()).untouched).toBe(false);
});

test("queued input prevents fresh recovery", async () => {
	const status = await fixture([], true);
	await status.emit("session_start");
	expect((await status.read()).untouched).toBe(false);
});

test("first input clears the marker even after returning to idle", async () => {
	const status = await fixture();
	await status.emit("session_start");
	await status.emit("input", { source: "interactive" });
	await status.emit("agent_end");
	const record = await status.read();
	expect(record.state).toBe("idle");
	expect(record.untouched).toBe(false);
});

test("extension input also clears the marker", async () => {
	const status = await fixture();
	await status.emit("session_start");
	await status.emit("input", { source: "extension" });
	expect((await status.read()).untouched).toBe(false);
});

test("bash commands clear the marker without an LLM turn", async () => {
	const status = await fixture();
	await status.emit("session_start");
	await status.emit("user_bash");
	expect((await status.read()).untouched).toBe(false);
});

test("injected messages clear the marker", async () => {
	const status = await fixture();
	await status.emit("session_start");
	await status.emit("message_start");
	expect((await status.read()).untouched).toBe(false);
});

test("overlapping publications cannot restore the older untouched marker", async () => {
	const status = await fixture();
	await Promise.all([
		status.emit("session_start"),
		status.emit("input", { source: "interactive" }),
	]);
	expect((await status.read()).untouched).toBe(false);
});
