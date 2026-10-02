import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { mkdtemp, readdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join, resolve } from "node:path";
import {
	discoverAndLoadExtensions,
	type ExtensionCommandContext,
	type ExtensionToolContext,
	type LoadExtensionsResult,
	VERSION,
} from "@earendil-works/pi-coding-agent";

const extensionsDir = resolve(import.meta.dir, "../extensions");
let directory: string;
let loaded: LoadExtensionsResult;

beforeAll(async () => {
	directory = await mkdtemp(join(tmpdir(), "pi-compatibility-"));
	// Exercise Pi's actual module mapping and registration, without starting
	// session hooks, external processes, sockets, or model requests.
	loaded = await discoverAndLoadExtensions([extensionsDir], directory, directory);
}, 30_000);

afterAll(async () => {
	if (directory) await rm(directory, { recursive: true, force: true });
});

function tool(name: string) {
	const registered = loaded.extensions.flatMap(extension => [...extension.tools.values()])
		.find(tool => tool.definition.name === name);
	if (!registered) throw new Error(`Missing tool: ${name}`);
	return registered.definition;
}

describe("Pi 1.0 compatibility", () => {
	test("loads every extension with the real 1.0 loader", async () => {
		expect(VERSION).toBe("1.0.0");
		expect(loaded.errors).toEqual([]);
		expect(loaded.warnings ?? []).toEqual([]);
		const expected = (await readdir(extensionsDir)).filter(name => name.endsWith(".ts")).sort();
		expect(loaded.extensions.map(extension => basename(extension.path)).sort()).toEqual(expected);
	});

	test("uses the unified session lifecycle, not removed transition events", () => {
		for (const extension of loaded.extensions) {
			expect(extension.handlers.has("session_switch")).toBe(false);
			expect(extension.handlers.has("session_fork")).toBe(false);
		}
		for (const name of ["footer-link.ts", "git-stats.ts", "jj-auto-snapshot.ts", "status-hub.ts"]) {
			const extension = loaded.extensions.find(extension => basename(extension.path) === name);
			expect(extension?.handlers.has("session_start")).toBe(true);
		}
	});

	test("keeps interactive and branch-persisted tools out of nested codemode calls", () => {
		for (const name of ["questionnaire", "footer_link"]) {
			expect(tool(name).exposure).toBe("model-only");
			expect(tool(name).executionMode).toBe("sequential");
		}
	});

	test("questionnaire skips RPC and headless modes without opening terminal components", async () => {
		for (const mode of ["rpc", "json", "print"]) {
			const ctx = { mode, hasUI: mode === "rpc" } as ExtensionToolContext;
			const result = await tool("questionnaire").execute("question", {
				questions: [{ question: "Proceed?", options: ["Yes", "No"] }],
			}, undefined, undefined, ctx);
			expect(result.details).toEqual({ skipped: true, cancelled: false, answers: [] });
		}
	});

	test("cloud commands reject RPC before launching a worker", async () => {
		const extension = loaded.extensions.find(extension => basename(extension.path) === "cloud.ts")!;
		for (const name of ["cloud", "cloud-clean"]) {
			const notices: string[] = [];
			const ctx = {
				mode: "rpc", hasUI: true, cwd: directory,
				sessionManager: { getSessionFile: () => undefined },
				ui: { notify: (text: string) => notices.push(text) },
			} as unknown as ExtensionCommandContext;
			await extension.commands.get(name)!.handler("", ctx);
			expect(notices).toEqual([`/${name} failed: Interactive cloud commands require the terminal UI.`]);
		}
	});

	test("draft manager does not open terminal components in RPC", async () => {
		const extension = loaded.extensions.find(extension => basename(extension.path) === "draft-queue.ts")!;
		const shortcut = [...extension.shortcuts.values()]
			.find(shortcut => shortcut.description === "Open draft queue manager")!;
		// Deliberately omit ui: any accidental access fails the test.
		await shortcut.handler({ mode: "rpc", hasUI: true } as ExtensionCommandContext);
	});

	test("questionnaire still collects answers in TUI mode", async () => {
		const ctx = {
			mode: "tui", hasUI: true,
			ui: { editor: async () => "Yes" },
		} as unknown as ExtensionToolContext;
		const result = await tool("questionnaire").execute("question", {
			questions: [{ question: "Proceed?" }],
		}, undefined, undefined, ctx);
		expect(result.details).toEqual({
			skipped: false, cancelled: false,
			answers: [{ id: "q1", question: "Proceed?", answer: "Yes", kind: "text" }],
		});
	});
});
