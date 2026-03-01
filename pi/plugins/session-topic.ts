import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

const TOOL_NAME = "set_session_topic";
const STATUS_KEY = "session-topic";
const MAX_TOPIC_CHARS = 100;
const STATE_VERSION = 1;

interface TopicStateFile {
	version: 1;
	topic: string | null;
	updatedAt: string;
}

function nowIso(): string {
	return new Date().toISOString();
}

function normalizeTopic(input: string | undefined): string | null {
	if (!input) return null;
	const normalized = input.replace(/\s+/g, " ").trim();
	if (!normalized) return null;
	return normalized.slice(0, MAX_TOPIC_CHARS);
}

function getStateFilePath(ctx: ExtensionContext): string {
	const sessionId = ctx.sessionManager.getSessionId();
	return join(ctx.cwd, ".pi", "tmp", "session-topic", `${sessionId}.json`);
}

async function writeStateFile(filePath: string, topic: string | null): Promise<void> {
	await mkdir(dirname(filePath), { recursive: true });

	const payload: TopicStateFile = {
		version: STATE_VERSION,
		topic,
		updatedAt: nowIso(),
	};

	const tmpPath = `${filePath}.tmp-${process.pid}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
	await writeFile(tmpPath, `${JSON.stringify(payload)}\n`, "utf8");
	await rename(tmpPath, filePath);
}

function parseTopicState(raw: string): string | null {
	const data = JSON.parse(raw) as Partial<TopicStateFile>;
	if (data.version !== STATE_VERSION) return null;
	if (data.topic === null) return null;
	if (typeof data.topic !== "string") return null;
	return normalizeTopic(data.topic);
}

async function readStateFile(filePath: string): Promise<string | null> {
	try {
		const raw = await readFile(filePath, "utf8");
		return parseTopicState(raw);
	} catch {
		return null;
	}
}

function renderTopicStatus(ctx: ExtensionContext, topic: string | null): void {
	if (!ctx.hasUI) return;

	ctx.ui.setStatus(STATUS_KEY, undefined);
	ctx.ui.setWidget(STATUS_KEY, undefined);

	if (!topic) return;

	ctx.ui.setWidget(STATUS_KEY, (_tui, theme) => new Text(theme.fg("dim", topic), 0, 0), {
		placement: "belowEditor",
	});
}

export default function (pi: ExtensionAPI): void {
	let currentTopic: string | null = null;
	let stateFilePath = "";

	async function loadTopicForSession(ctx: ExtensionContext): Promise<void> {
		stateFilePath = getStateFilePath(ctx);
		currentTopic = await readStateFile(stateFilePath);
		renderTopicStatus(ctx, currentTopic);
	}

	function reapplyTopicAfterOtherWidgets(ctx: ExtensionContext): void {
		if (!currentTopic) return;
		setTimeout(() => {
			if (!currentTopic) return;
			renderTopicStatus(ctx, currentTopic);
		}, 0);
	}

	function clearRuntimeTopic(ctx: ExtensionContext): void {
		currentTopic = null;
		renderTopicStatus(ctx, currentTopic);
	}

	pi.registerTool({
		name: TOOL_NAME,
		label: "Set Session Topic",
		description:
			"Set or clear the current session topic shown below the prompt input. Use only when overall focus changes, not for minor subtasks.",
		parameters: Type.Object({
			topic: Type.Optional(
				Type.String({
					description:
						"Short topic sentence (about 5-10 words). Omit or pass empty string to clear the current topic.",
				}),
			),
		}),
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			if (!stateFilePath) {
				stateFilePath = getStateFilePath(ctx);
			}

			const nextTopic = normalizeTopic(params.topic);

			if (nextTopic === currentTopic) {
				return {
					content: [{ type: "text", text: `Session topic unchanged: ${currentTopic ?? "<none>"}` }],
					details: { topic: currentTopic, changed: false, action: "unchanged" as const },
				};
			}

			currentTopic = nextTopic;
			await writeStateFile(stateFilePath, currentTopic);
			renderTopicStatus(ctx, currentTopic);

			if (!currentTopic) {
				return {
					content: [{ type: "text", text: "Session topic cleared." }],
					details: { topic: null, changed: true, action: "cleared" as const },
				};
			}

			return {
				content: [{ type: "text", text: `Session topic set: ${currentTopic}` }],
				details: { topic: currentTopic, changed: true, action: "set" as const },
			};
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		await loadTopicForSession(ctx);
		reapplyTopicAfterOtherWidgets(ctx);
	});

	pi.on("session_switch", async (_event, ctx) => {
		await loadTopicForSession(ctx);
		reapplyTopicAfterOtherWidgets(ctx);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		stateFilePath = "";
		clearRuntimeTopic(ctx);
	});

	pi.on("tool_result", async (event, ctx) => {
		if (!currentTopic) return;
		if (event.toolName !== "todowrite" && event.toolName !== "todoread" && event.toolName !== "enter_plan_mode") {
			return;
		}
		// Re-apply topic widget after other below-editor widgets update so topic stays last.
		reapplyTopicAfterOtherWidgets(ctx);
	});

	pi.on("before_agent_start", async (event) => {
		return {
			systemPrompt:
				event.systemPrompt +
				`\n\n[Session topic]\n- You can call ${TOOL_NAME} to set the session topic shown below the prompt input.\n- Set a topic when work starts and whenever the OVERALL focus changes.\n- Do not update topic for minor, incremental subtasks.\n- Keep topic short: one sentence, about 5-10 words.\n- If the topic is still accurate, do not call ${TOOL_NAME}.\n- You may clear topic with ${TOOL_NAME} by omitting topic only when no topic should be shown.\n- Good topic examples: "Implement session topic widget and update flow", "Debug flaky CI test failures in auth module".\n- Too granular examples: "Read file", "Run tests", "Edit line 42".`,
		};
	});
}
