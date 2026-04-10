import { mkdir, rename, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

type AgentActivityState = "busy" | "idle" | "waiting_input" | "unknown";

interface AgentStatusRecord {
	version: 1;
	pid: number;
	user: string;
	host: string;
	sessionId: string;
	sessionFile: string | null;
	cwd: string;
	state: AgentActivityState;
	startedAt: string;
	updatedAt: string;
	lastActivityAt: string;
	lastEvent: string;
	currentTool: string | null;
}

const HEARTBEAT_MS = 5_000;

function nowIso(): string {
	return new Date().toISOString();
}

function sanitizeTitle(value: string): string {
	return value.replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim();
}

function writeTerminalTitle(rawTitle: string): void {
	if (!process.stdout.isTTY) return;
	const title = sanitizeTitle(rawTitle);
	if (!title) return;

	const osc1 = `\u001b]1;${title}\u0007`;
	const osc2 = `\u001b]2;${title}\u0007`;
	process.stdout.write(osc1);
	process.stdout.write(osc2);

	if (process.env.TMUX) {
		const tmuxOsc1 = `\u001bPtmux;\u001b${osc1}\u001b\\`;
		const tmuxOsc2 = `\u001bPtmux;\u001b${osc2}\u001b\\`;
		process.stdout.write(tmuxOsc1);
		process.stdout.write(tmuxOsc2);
	}
}

function toTerminalTitle(record: AgentStatusRecord): string {
	const state = record.state === "waiting_input" ? "waiting" : record.state;
	if (record.state === "busy" && record.currentTool) return `pi · ${state} · ${record.currentTool}`;
	return `pi · ${state}`;
}

function getStatusDir(): string {
	return process.env.PI_AGENT_STATUS_DIR || path.join(tmpdir(), "pi-agent-status");
}

function getStatusFile(): string {
	return path.join(getStatusDir(), `${process.pid}.json`);
}

async function writeAtomicJson(filePath: string, data: unknown): Promise<void> {
	const dir = path.dirname(filePath);
	await mkdir(dir, { recursive: true });
	const tmpPath = `${filePath}.tmp-${process.pid}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
	await writeFile(tmpPath, `${JSON.stringify(data)}\n`, "utf8");
	await rename(tmpPath, filePath);
}

export default function (pi: ExtensionAPI): void {
	const startedAt = nowIso();
	const statusFile = getStatusFile();
	let heartbeat: NodeJS.Timeout | undefined;
	let lastPublishedTitle: string | null = null;

	let record: AgentStatusRecord = {
		version: 1,
		pid: process.pid,
		user: process.env.USER || process.env.LOGNAME || "unknown",
		host: process.env.HOSTNAME || process.env.HOST || "unknown",
		sessionId: "unknown",
		sessionFile: null,
		cwd: process.cwd(),
		state: "unknown",
		startedAt,
		updatedAt: startedAt,
		lastActivityAt: startedAt,
		lastEvent: "init",
		currentTool: null,
	};

	function publishTitle(): void {
		const next = toTerminalTitle(record);
		if (next === lastPublishedTitle) return;
		lastPublishedTitle = next;
		writeTerminalTitle(next);
	}

	async function flush(): Promise<void> {
		record.updatedAt = nowIso();
		await writeAtomicJson(statusFile, record);
		publishTitle();
	}

	async function setState(state: AgentActivityState, eventName: string, updates?: Partial<Pick<AgentStatusRecord, "currentTool" | "cwd" | "sessionFile" | "sessionId">>): Promise<void> {
		record = {
			...record,
			...updates,
			state,
			lastEvent: eventName,
			lastActivityAt: nowIso(),
		};
		await flush();
	}

	pi.on("session_start", async (_event, ctx) => {
		record = {
			...record,
			sessionId: ctx.sessionManager.getSessionId(),
			sessionFile: ctx.sessionManager.getSessionFile() ?? null,
			cwd: ctx.cwd,
			state: "idle",
			lastEvent: "session_start",
			lastActivityAt: nowIso(),
		};
		await flush();

		if (heartbeat) clearInterval(heartbeat);
		heartbeat = setInterval(() => {
			void flush();
		}, HEARTBEAT_MS);
		heartbeat.unref?.();
	});

	pi.on("input", async (event) => {
		if (event.source === "extension") return { action: "continue" };
		await setState("busy", "input", { currentTool: null });
		return { action: "continue" };
	});

	pi.on("agent_start", async () => {
		await setState("busy", "agent_start", { currentTool: null });
	});

	pi.on("turn_start", async () => {
		await setState("busy", "turn_start");
	});

	pi.on("tool_execution_start", async (event) => {
		if (event.toolName === "questionnaire") {
			await setState("idle", "tool_execution_start:questionnaire", { currentTool: event.toolName });
			return;
		}
		await setState("busy", "tool_execution_start", { currentTool: event.toolName });
	});

	pi.on("tool_execution_end", async () => {
		await setState("busy", "tool_execution_end", { currentTool: null });
	});

	pi.on("tool_call", async (event) => {
		if (event.toolName === "questionnaire") {
			await setState("idle", "tool_call:questionnaire", { currentTool: event.toolName });
		}
	});

	pi.on("tool_result", async (event) => {
		if (event.toolName === "questionnaire") {
			await setState("busy", "tool_result:questionnaire", { currentTool: null });
		}
	});

	pi.on("agent_end", async () => {
		await setState("idle", "agent_end", { currentTool: null });
	});

	pi.on("session_shutdown", async () => {
		if (heartbeat) {
			clearInterval(heartbeat);
			heartbeat = undefined;
		}
		await rm(statusFile, { force: true });
		lastPublishedTitle = null;
		writeTerminalTitle("pi");
	});
}
