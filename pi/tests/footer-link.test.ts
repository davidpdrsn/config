import { describe, expect, test } from "bun:test";
import extension from "../extensions/footer-link";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

function setup() {
	let tool: any;
	let status: string | undefined;
	const handlers = new Map<string, Function>();
	const entries: any[] = [];
	const ctx = {
		hasUI: true,
		ui: { setStatus: (key: string, value: string | undefined) => { expect(key).toBe("footer-link"); status = value; } },
		sessionManager: { getBranch: () => entries },
	};
	extension({ registerTool: (value: any) => { tool = value; }, on: (name: string, fn: Function) => handlers.set(name, fn) } as any);
	return {
		ctx, entries, handlers,
		status: () => status,
		run: (params: any) => tool.execute("id", params, undefined, undefined, ctx),
	};
}

describe("footer_link", () => {
	test("sets an OSC 8 link and clears it", async () => {
		const h = setup();
		const result = await h.run({ action: "set", url: "https://example.com", label: "PR #42" });
		expect(h.status()).toBe("\x1b]8;;https://example.com/\x07PR #42\x1b]8;;\x07");
		expect(result.details.link.label).toBe("PR #42");
		expect(visibleWidth(h.status()!)).toBe(6);
		expect(visibleWidth(truncateToWidth(h.status()!, 4))).toBeLessThanOrEqual(4);
		await h.run({ action: "clear" });
		expect(h.status()).toBeUndefined();
	});

	test("defaults label to URL and replaces existing link", async () => {
		const h = setup();
		await h.run({ action: "set", url: "https://example.com/old" });
		await h.run({ action: "set", url: "https://example.com/new" });
		expect(h.status()).toContain("\x07https://example.com/new");
		expect(h.status()).not.toContain("old");
	});

	test("rejects unsafe links and labels without changing status", async () => {
		const h = setup();
		await h.run({ action: "set", url: "https://example.com" });
		const original = h.status();
		for (const params of [
			{ action: "set" },
			{ action: "set", url: "javascript:alert(1)" },
			{ action: "set", url: "file:///tmp/test" },
			{ action: "set", url: "not a URL" },
			{ action: "set", url: "https://example.com/\x1b\\" },
			{ action: "set", url: "https://example.com", label: "\x1b[31m" },
			{ action: "set", url: "https://example.com", label: "a\nb" },
			{ action: "set", url: "https://example.com", label: " " },
		]) await expect(h.run(params)).rejects.toThrow();
		expect(h.status()).toBe(original);
	});

	test("restores active branch state, including clear and empty branches", async () => {
		const h = setup();
		const result = await h.run({ action: "set", url: "https://example.com", label: "Issue" });
		h.entries.push({ type: "message", message: { role: "toolResult", toolName: "footer_link", ...result } });
		await h.run({ action: "clear" });
		for (const name of ["session_start", "session_switch", "session_fork", "session_tree"]) {
			h.handlers.get(name)!({}, h.ctx);
			expect(h.status()).toContain("Issue");
		}
		h.entries.push({ type: "message", message: { role: "toolResult", toolName: "footer_link", details: { link: null } } });
		h.handlers.get("session_start")!({}, h.ctx);
		expect(h.status()).toBeUndefined();
		await h.run({ action: "set", url: "https://example.com" });
		h.entries.length = 0;
		h.handlers.get("session_tree")!({}, h.ctx);
		expect(h.status()).toBeUndefined();
	});

	test("works without a UI", async () => {
		const h = setup();
		h.ctx.hasUI = false;
		const result = await h.run({ action: "set", url: "https://example.com" });
		expect(result.details.link.url).toBe("https://example.com/");
		expect(h.status()).toBeUndefined();
	});
});
