import { describe, expect, test } from "bun:test";
import type { ExtensionAPI, ExtensionContext, SessionEntry } from "@earendil-works/pi-coding-agent";
import promptHistory, { collectPrompts } from "../extensions/prompt-history";

function message(role: string, content: unknown): SessionEntry {
	return { type: "message", message: { role, content } } as SessionEntry;
}

function setup(entries: SessionEntry[], selection?: string) {
	let handler!: (ctx: ExtensionContext) => Promise<void>;
	promptHistory({
		registerShortcut(key: string, shortcut: { handler: typeof handler }) {
			expect(key).toBe("ctrl+r");
			handler = shortcut.handler;
		},
		registerCommand() {},
	} as unknown as ExtensionAPI);
	let draft = "unfinished draft";
	let opened = 0;
	const notices: string[] = [];
	const ctx = {
		mode: "tui",
		sessionManager: { getEntries: () => entries },
		ui: {
			custom: async () => { opened++; return selection; },
			setEditorText: (text: string) => { draft = text; },
			notify: (text: string) => notices.push(text),
		},
	} as unknown as ExtensionContext;
	return { handler, ctx, get draft() { return draft; }, get opened() { return opened; }, notices };
}

describe("prompt history", () => {
	test("collects unique user text newest first without changing the original", () => {
		const entries = [message("user", "old"), message("assistant", "ignore"),
			message("user", "repeat"), message("user", "old"),
			message("user", [{ type: "text", text: "line one" }, { type: "image", data: "ignored" }, { type: "text", text: "line two" }]),
			message("user", "  "), message("user", [{ type: "image", data: "ignored" }])];
		expect(collectPrompts(entries)).toEqual(["line one\nline two", "old", "repeat"]);
		expect(entries[0]).toEqual(message("user", "old"));
	});

	test("restores the full prompt into the editor", async () => {
		const state = setup([message("user", "first\nsecond")], "first\nsecond");
		await state.handler(state.ctx);
		expect(state.draft).toBe("first\nsecond");
	});

	test("cancel preserves the draft and permits reopening", async () => {
		const state = setup([message("user", "old")]);
		await state.handler(state.ctx);
		await state.handler(state.ctx);
		expect(state.draft).toBe("unfinished draft");
		expect(state.opened).toBe(2);
	});

	test("empty history shows a notice rather than a picker", async () => {
		const state = setup([]);
		await state.handler(state.ctx);
		expect(state.opened).toBe(0);
		expect(state.notices).toEqual(["No prompts in this session yet"]);
	});

	test("ignores non-terminal modes", async () => {
		const state = setup([]);
		for (const mode of ["rpc", "print", "json"] as const) {
			await state.handler({ mode } as ExtensionContext);
		}
		expect(state.opened).toBe(0);
	});
});
