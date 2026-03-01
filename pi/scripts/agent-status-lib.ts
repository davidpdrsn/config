import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

export type AgentActivityState = "busy" | "idle" | "waiting_input" | "unknown";
export type AgentObservedState = AgentActivityState | "offline";

export interface AgentStatusRecord {
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

export interface AgentObservedRecord extends AgentStatusRecord {
	observedState: AgentObservedState;
	pidAlive: boolean;
	staleMs: number;
}

export interface AgentStatusCounts {
	total: number;
	busy: number;
	idle: number;
	waiting_input: number;
	offline: number;
	unknown: number;
}

export interface CollectOptions {
	statusDir: string;
	staleAfterMs: number;
	cwd?: string;
	sessionId?: string;
	allUsers?: boolean;
	now?: Date;
}

function isObject(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null;
}

function parseRecord(value: unknown): AgentStatusRecord | undefined {
	if (!isObject(value)) return undefined;

	const state = value.state;
	if (state !== "busy" && state !== "idle" && state !== "waiting_input" && state !== "unknown") return undefined;

	if (typeof value.pid !== "number") return undefined;
	if (typeof value.sessionId !== "string") return undefined;
	if (typeof value.cwd !== "string") return undefined;
	if (typeof value.updatedAt !== "string") return undefined;
	if (typeof value.startedAt !== "string") return undefined;
	if (typeof value.lastActivityAt !== "string") return undefined;
	if (typeof value.user !== "string") return undefined;
	if (typeof value.host !== "string") return undefined;
	if (typeof value.lastEvent !== "string") return undefined;
	if (!(typeof value.currentTool === "string" || value.currentTool === null)) return undefined;
	if (!(typeof value.sessionFile === "string" || value.sessionFile === null)) return undefined;

	return {
		version: 1,
		pid: value.pid,
		user: value.user,
		host: value.host,
		sessionId: value.sessionId,
		sessionFile: value.sessionFile,
		cwd: value.cwd,
		state,
		startedAt: value.startedAt,
		updatedAt: value.updatedAt,
		lastActivityAt: value.lastActivityAt,
		lastEvent: value.lastEvent,
		currentTool: value.currentTool,
	};
}

function dateAgeMs(isoDate: string, now: Date): number {
	const parsed = Date.parse(isoDate);
	if (Number.isNaN(parsed)) return Number.MAX_SAFE_INTEGER;
	return Math.max(0, now.getTime() - parsed);
}

export function isPidAlive(pid: number): boolean {
	if (!Number.isInteger(pid) || pid < 1) return false;
	try {
		process.kill(pid, 0);
		return true;
	} catch (error) {
		const code = (error as NodeJS.ErrnoException).code;
		if (code === "EPERM") return true;
		return false;
	}
}

export function classifyRecord(record: AgentStatusRecord, staleAfterMs: number, now = new Date()): AgentObservedRecord {
	const staleMs = dateAgeMs(record.updatedAt, now);
	const pidAlive = isPidAlive(record.pid);

	let observedState: AgentObservedState = record.state;
	if (!pidAlive) observedState = "offline";
	else if (staleMs > staleAfterMs) observedState = "unknown";

	return {
		...record,
		observedState,
		pidAlive,
		staleMs,
	};
}

export async function collectAgentStatuses(options: CollectOptions): Promise<{
	agents: AgentObservedRecord[];
	counts: AgentStatusCounts;
	errors: string[];
}> {
	const now = options.now ?? new Date();
	const errors: string[] = [];
	const entries = await readdir(options.statusDir, { withFileTypes: true }).catch(() => []);

	const agents: AgentObservedRecord[] = [];
	for (const entry of entries) {
		if (!entry.isFile()) continue;
		if (!entry.name.endsWith(".json")) continue;
		const filePath = path.join(options.statusDir, entry.name);

		let raw = "";
		try {
			raw = await readFile(filePath, "utf8");
		} catch (error) {
			errors.push(`${entry.name}: failed to read (${String(error)})`);
			continue;
		}

		let parsed: unknown;
		try {
			parsed = JSON.parse(raw);
		} catch {
			errors.push(`${entry.name}: invalid JSON`);
			continue;
		}

		const record = parseRecord(parsed);
		if (!record) {
			errors.push(`${entry.name}: invalid status schema`);
			continue;
		}

		if (!options.allUsers) {
			const currentUser = process.env.USER || process.env.LOGNAME;
			if (currentUser && record.user !== currentUser) continue;
		}

		if (options.cwd && !record.cwd.startsWith(options.cwd)) continue;
		if (options.sessionId && record.sessionId !== options.sessionId) continue;

		agents.push(classifyRecord(record, options.staleAfterMs, now));
	}

	agents.sort((a, b) => a.pid - b.pid);

	const counts: AgentStatusCounts = {
		total: agents.length,
		busy: agents.filter((agent) => agent.observedState === "busy").length,
		idle: agents.filter((agent) => agent.observedState === "idle").length,
		waiting_input: agents.filter((agent) => agent.observedState === "waiting_input").length,
		offline: agents.filter((agent) => agent.observedState === "offline").length,
		unknown: agents.filter((agent) => agent.observedState === "unknown").length,
	};

	return { agents, counts, errors };
}
