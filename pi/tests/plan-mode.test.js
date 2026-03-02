import { afterEach, describe, expect, test } from "bun:test";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import planModePlugin from "../extensions/plan-mode";

function createHarness(cwd) {
	const entries = [];
	const tools = new Map();
	const handlers = new Map();
	const sentUserMessages = [];
	let activeTools = [
		"read",
		"bash",
		"edit",
		"write",
		"enter_plan_mode",
		"plan_show",
		"plan_init",
		"plan_revise",
		"questionnaire",
		"set_session_topic",
	];

	const ctx = {
		cwd,
		ui: {
			notify: () => {},
		},
		sessionManager: {
			getSessionId: () => "plan-mode-test-session",
			getEntries: () => entries,
		},
	};

	const pi = {
		registerTool: (def) => {
			tools.set(def.name, def);
		},
		registerCommand: () => {},
		on: (eventName, handler) => {
			const list = handlers.get(eventName) ?? [];
			list.push(handler);
			handlers.set(eventName, list);
		},
		appendEntry: (customType, data) => {
			entries.push({ type: "custom", customType, data });
		},
		getActiveTools: () => [...activeTools],
		setActiveTools: (toolNames) => {
			activeTools = [...toolNames];
		},
		sendUserMessage: (content) => {
			sentUserMessages.push(content);
		},
	};

	planModePlugin(pi);

	const emit = async (eventName, event) => {
		const registered = handlers.get(eventName) ?? [];
		let lastResult;
		for (const handler of registered) {
			lastResult = await handler(event, ctx);
		}
		return lastResult;
	};

	return { ctx, entries, tools, sentUserMessages, emit };
}

const tempDirs = [];

afterEach(async () => {
	for (const dir of tempDirs.splice(0)) {
		await rm(dir, { recursive: true, force: true });
	}
});

describe("plan mode go transition", () => {
	test("disables plan mode and steers away from asking for go again", async () => {
		const cwd = await mkdtemp(path.join(tmpdir(), "pi-plan-mode-test-"));
		tempDirs.push(cwd);
		const harness = createHarness(cwd);

		await harness.emit("session_start", {});

		const enterPlanMode = harness.tools.get("enter_plan_mode");
		expect(enterPlanMode).toBeDefined();
		await enterPlanMode.execute("tool-call", {}, undefined, undefined, harness.ctx);

		const inputResult = await harness.emit("input", { source: "interactive", text: "go" });
		expect(inputResult).toEqual({ action: "handled" });

		expect(harness.sentUserMessages.length).toBe(1);
		expect(harness.sentUserMessages[0]).toContain("already sent exact 'go'");
		expect(harness.sentUserMessages[0]).not.toContain("Execution mode begins now");

		const latestState = [...harness.entries]
			.reverse()
			.find((entry) => entry.type === "custom" && entry.customType === "plan-mode-state");
		expect(latestState).toBeDefined();
		expect(latestState.data.enabled).toBe(false);

		const firstTurnPrompt = await harness.emit("before_agent_start", { systemPrompt: "BASE" });
		expect(firstTurnPrompt.systemPrompt).toContain("[Post-plan-mode transition]");
		expect(firstTurnPrompt.systemPrompt).toContain("Do not ask for 'go' again.");

		await harness.emit("message_end", {
			message: {
				role: "assistant",
				content: [{ type: "text", text: "Proceeding with execution." }],
			},
		});

		const secondTurnPrompt = await harness.emit("before_agent_start", { systemPrompt: "BASE" });
		expect(secondTurnPrompt.systemPrompt).not.toContain("[Post-plan-mode transition]");
	});
});
