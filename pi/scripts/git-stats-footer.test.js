import { describe, expect, test } from "bun:test";
import { visibleWidth } from "@mariozechner/pi-tui";
import extension from "../extensions/git-stats";

async function setup(cwd = "/project") {
	const handlers = new Map();
	let footer;
	let sessionId = "01a0e740-809b-722f-bae0-7644d5ec49d8";
	extension({
		on: (event, handler) => handlers.set(event, handler),
		getThinkingLevel: () => "medium",
	});
	const ctx = {
		hasUI: true,
		cwd,
		ui: {
			setStatus() {},
			setFooter(factory) {
				footer = factory?.(
					{ requestRender() {} },
					{ fg: (_color, text) => `\x1b[90m${text}\x1b[0m` },
					{
						onBranchChange: () => () => {},
						getGitBranch: () => null,
						getAvailableProviderCount: () => 1,
						getExtensionStatuses: () => new Map(),
					},
				);
			},
		},
		sessionManager: {
			getSessionId: () => sessionId,
			getSessionName: () => undefined,
			getEntries: () => [],
		},
		model: { id: "test-model", reasoning: true, contextWindow: 272000 },
		modelRegistry: { isUsingOAuth: () => false },
		getContextUsage: () => undefined,
	};
	await handlers.get("session_start")({}, ctx);
	return {
		render: (width) => footer.render(width),
		setSessionId: (id) => { sessionId = id; },
	};
}

const plain = (text) => text.replace(/\x1b\[[0-9;]*m/g, "");

describe("session ID footer", () => {
	test("right-aligns the full resume ID above the model", async () => {
		const footer = await setup();
		const lines = footer.render(100).map(plain);
		expect(lines).toHaveLength(2);
		expect(lines[0].startsWith("/project")).toBe(true);
		expect(lines[0].endsWith("01a0e740-809b-722f-bae0-7644d5ec49d8")).toBe(true);
		expect(lines[1].endsWith("test-model • medium")).toBe(true);
		expect(visibleWidth(lines[0])).toBe(100);
	});

	test("reads the current ID on each render", async () => {
		const footer = await setup();
		footer.setSessionId("12345678-1234-1234-1234-123456789abc");
		expect(plain(footer.render(100)[0]).endsWith("12345678-1234-1234-1234-123456789abc")).toBe(true);
	});

	test("handles long Unicode paths and narrow terminals without overflowing", async () => {
		const footer = await setup(`/project/${"界".repeat(100)}`);
		for (let width = 1; width <= 120; width++) {
			for (const line of footer.render(width)) {
				expect(visibleWidth(line)).toBeLessThanOrEqual(width);
			}
		}
		expect(plain(footer.render(38)[0])).not.toContain("01a0e740");
		expect(plain(footer.render(80)[0]).endsWith("01a0e740-809b-722f-bae0-7644d5ec49d8")).toBe(true);
	});
});
