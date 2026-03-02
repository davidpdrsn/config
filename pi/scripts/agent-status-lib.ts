import { readdir, readFile, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
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

function compareUpdatedAt(a: string, b: string): number {
	const aMs = Date.parse(a);
	const bMs = Date.parse(b);
	const aValid = !Number.isNaN(aMs);
	const bValid = !Number.isNaN(bMs);

	if (aValid && bValid) return aMs - bMs;
	if (aValid) return 1;
	if (bValid) return -1;
	return 0;
}

async function isDirectory(dirPath: string): Promise<boolean> {
	try {
		const info = await stat(dirPath);
		return info.isDirectory();
	} catch {
		return false;
	}
}

function dedupeDirectories(directories: string[]): string[] {
	const seen = new Set<string>();
	const deduped: string[] = [];
	for (const dir of directories) {
		if (!dir || seen.has(dir)) continue;
		seen.add(dir);
		deduped.push(dir);
	}
	return deduped;
}

export async function discoverStatusDirs(): Promise<string[]> {
	const dirs: string[] = [];

	if (process.env.PI_AGENT_STATUS_DIR) dirs.push(process.env.PI_AGENT_STATUS_DIR);
	dirs.push(path.join(tmpdir(), "pi-agent-status"));

	const tmpEntries = await readdir("/tmp", { withFileTypes: true }).catch(() => []);
	for (const entry of tmpEntries) {
		if (!entry.isDirectory()) continue;
		if (!entry.name.startsWith("nix-shell.")) continue;
		const nixStatusDir = path.join("/tmp", entry.name, "pi-agent-status");
		if (await isDirectory(nixStatusDir)) dirs.push(nixStatusDir);
	}

	return dedupeDirectories(dirs);
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
	const statusDirs = await discoverStatusDirs();
	const latestByPid = new Map<number, AgentStatusRecord>();

	for (const statusDir of statusDirs) {
		const entries = await readdir(statusDir, { withFileTypes: true }).catch(() => []);
		for (const entry of entries) {
			if (!entry.isFile()) continue;
			if (!entry.name.endsWith(".json")) continue;
			const filePath = path.join(statusDir, entry.name);

			let raw = "";
			try {
				raw = await readFile(filePath, "utf8");
			} catch (error) {
				errors.push(`${filePath}: failed to read (${String(error)})`);
				continue;
			}

			let parsed: unknown;
			try {
				parsed = JSON.parse(raw);
			} catch {
				errors.push(`${filePath}: invalid JSON`);
				continue;
			}

			const record = parseRecord(parsed);
			if (!record) {
				errors.push(`${filePath}: invalid status schema`);
				continue;
			}

			const existing = latestByPid.get(record.pid);
			if (!existing || compareUpdatedAt(record.updatedAt, existing.updatedAt) > 0) {
				latestByPid.set(record.pid, record);
			}
		}
	}

	const currentUser = process.env.USER || process.env.LOGNAME;
	const agents: AgentObservedRecord[] = [];
	for (const record of latestByPid.values()) {
		if (!options.allUsers && currentUser && record.user !== currentUser) continue;
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
