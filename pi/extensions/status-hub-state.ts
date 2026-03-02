import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

type StatusTone = "text" | "muted" | "dim" | "warning" | "success" | "error" | "accent";

const STATE_VERSION = 1;

export interface StatusLine {
	slot: string;
	sessionId: string;
	text: string;
	tone?: StatusTone;
}

export interface SetStatusLineOptions {
	tone?: StatusTone;
}

interface StoredSlot {
	text: string;
	tone?: StatusTone;
}

interface StoredState {
	version: 1;
	slots: Record<string, StoredSlot>;
}

function stateFile(cwd: string, sessionId: string): string {
	return join(cwd, ".pi", "tmp", "status-hub", `${sessionId}.json`);
}

function readState(cwd: string, sessionId: string): StoredState {
	try {
		const raw = readFileSync(stateFile(cwd, sessionId), "utf8");
		const parsed = JSON.parse(raw) as Partial<StoredState>;
		if (parsed.version !== STATE_VERSION || !parsed.slots || typeof parsed.slots !== "object") {
			return { version: STATE_VERSION, slots: {} };
		}
		return { version: STATE_VERSION, slots: parsed.slots as Record<string, StoredSlot> };
	} catch {
		return { version: STATE_VERSION, slots: {} };
	}
}

function writeState(cwd: string, sessionId: string, state: StoredState): void {
	const filePath = stateFile(cwd, sessionId);
	mkdirSync(dirname(filePath), { recursive: true });
	const tmp = `${filePath}.tmp-${process.pid}-${Date.now()}`;
	writeFileSync(tmp, `${JSON.stringify(state)}\n`, "utf8");
	renameSync(tmp, filePath);
}

export function setStatusLine(
	cwd: string,
	sessionId: string,
	slot: string,
	text: string,
	options?: SetStatusLineOptions,
): void {
	const normalized = text.trim();
	if (!normalized) {
		clearStatusLine(cwd, sessionId, slot);
		return;
	}
	const state = readState(cwd, sessionId);
	state.slots[slot] = { text: normalized, tone: options?.tone };
	writeState(cwd, sessionId, state);
}

export function clearStatusLine(cwd: string, sessionId: string, slot: string): void {
	const state = readState(cwd, sessionId);
	if (!(slot in state.slots)) return;
	delete state.slots[slot];
	writeState(cwd, sessionId, state);
}

export function clearSessionStatusLines(cwd: string, sessionId: string): void {
	writeState(cwd, sessionId, { version: STATE_VERSION, slots: {} });
}

export function getSessionStatusLines(cwd: string, sessionId: string): StatusLine[] {
	const state = readState(cwd, sessionId);
	return Object.entries(state.slots).map(([slot, value]) => ({
		slot,
		sessionId,
		text: value.text,
		tone: value.tone,
	}));
}

export default function (): void {
	// Intentionally empty: this file is a shared status state module.
}
