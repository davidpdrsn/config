import { Buffer } from "node:buffer";
import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { readdir, readFile, realpath, rm } from "node:fs/promises";
import { promisify } from "node:util";
import path from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const execFileAsync = promisify(execFile);
const REGISTRY_ROOT = process.env.PI_NVIM_SERVER_DIR ?? "/tmp/pi-nvim-servers";
const NVIM_BIN = process.env.PI_NVIM_BIN ?? "nvim";
const NOTIFY_TIMEOUT_MS = 2_000;

interface NvimMarker {
	address: string;
	cwd: string;
	pid: number;
}

function cwdHash(cwd: string): string {
	return createHash("sha256").update(cwd).digest("hex");
}

function isObject(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null;
}

function parseMarker(value: string): NvimMarker | null {
	let parsed: unknown;
	try {
		parsed = JSON.parse(value);
	} catch {
		return null;
	}

	if (!isObject(parsed)) return null;
	if (typeof parsed.address !== "string") return null;
	if (typeof parsed.cwd !== "string") return null;
	if (typeof parsed.pid !== "number") return null;
	return { address: parsed.address, cwd: parsed.cwd, pid: parsed.pid };
}

function processExists(pid: number): boolean {
	try {
		process.kill(pid, 0);
		return true;
	} catch {
		return false;
	}
}

async function matchingMarkers(cwd: string): Promise<NvimMarker[]> {
	const canonicalCwd = await realpath(cwd);
	const dir = path.join(REGISTRY_ROOT, cwdHash(canonicalCwd));
	let entries: string[];
	try {
		entries = await readdir(dir);
	} catch {
		return [];
	}

	const markers: NvimMarker[] = [];
	await Promise.all(
		entries
			.filter((entry) => entry.endsWith(".json"))
			.map(async (entry) => {
				const markerPath = path.join(dir, entry);
				const raw = await readFile(markerPath, "utf8").catch(() => null);
				if (raw === null) return;

				const marker = parseMarker(raw);
				if (marker === null || !processExists(marker.pid)) {
					await rm(markerPath, { force: true }).catch(() => undefined);
					return;
				}

				const markerCwd = await realpath(marker.cwd).catch(() => marker.cwd);
				if (markerCwd === canonicalCwd) markers.push(marker);
			}),
	);

	return markers;
}

function changedFileFromInput(input: unknown, cwd: string): string | null {
	if (!isObject(input) || typeof input.path !== "string") return null;
	return path.resolve(cwd, input.path);
}

function remoteExpression(changedFiles: string[]): string {
	const encoded = Buffer.from(JSON.stringify(changedFiles), "utf8").toString("base64");
	return `execute('lua require("pi_nvim_server").reload_files_base64("${encoded}")')`;
}

async function notifyNvim(marker: NvimMarker, changedFiles: string[]): Promise<void> {
	await execFileAsync(NVIM_BIN, ["--server", marker.address, "--remote-expr", remoteExpression(changedFiles)], {
		timeout: NOTIFY_TIMEOUT_MS,
	});
}

async function notifyMatchingNvims(cwd: string, changedFiles: string[]): Promise<void> {
	const markers = await matchingMarkers(cwd);
	await Promise.all(markers.map((marker) => notifyNvim(marker, changedFiles).catch(() => undefined)));
}

export default function (pi: ExtensionAPI): void {
	const changedFiles = new Set<string>();

	pi.on("agent_start", async () => {
		changedFiles.clear();
	});

	pi.on("tool_result", async (event, ctx) => {
		if (event.isError) return;
		if (event.toolName !== "edit" && event.toolName !== "write") return;

		const changedFile = changedFileFromInput(event.input, ctx.cwd);
		if (changedFile !== null) changedFiles.add(changedFile);
	});

	pi.on("agent_end", async (_event, ctx) => {
		const files = [...changedFiles];
		changedFiles.clear();
		if (files.length === 0) return;

		await notifyMatchingNvims(ctx.cwd, files).catch(() => undefined);
	});
}
