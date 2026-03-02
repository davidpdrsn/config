import { access, mkdir, readdir, readlink, rm, symlink, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { basename, dirname, extname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Key, matchesKey, truncateToWidth } from "@mariozechner/pi-tui";

const RUNTIME_DIR = join(homedir(), ".pi", "agent", "extensions-runtime");
const BOOTSTRAP_MARKER = join(RUNTIME_DIR, ".initialized");
const MANAGER_FILE = basename(fileURLToPath(import.meta.url));

type NotifyLevel = "info" | "warning" | "error";

interface ExtensionRow {
	id: string;
	name: string;
	sourcePath: string;
	linkPath: string;
	enabled: boolean;
}

interface PickerResult {
	states: Map<string, boolean>;
}

function notify(ctx: ExtensionContext, text: string, level: NotifyLevel = "info"): void {
	ctx.ui.notify(text, level);
}

async function exists(path: string): Promise<boolean> {
	try {
		await access(path);
		return true;
	} catch {
		return false;
	}
}

function sourceExtensionsDir(): string {
	return dirname(fileURLToPath(import.meta.url));
}

function isExtensionFile(file: string): boolean {
	const ext = extname(file);
	return ext === ".ts" || ext === ".js";
}

async function readSourceExtensions(): Promise<string[]> {
	const dir = sourceExtensionsDir();
	const entries = await readdir(dir, { withFileTypes: true });
	return entries
		.filter((entry) => entry.isFile())
		.map((entry) => entry.name)
		.filter((name) => isExtensionFile(name) && name !== MANAGER_FILE)
		.sort((a, b) => a.localeCompare(b))
		.map((name) => join(dir, name));
}

async function isEnabledLink(sourcePath: string, linkPath: string): Promise<boolean> {
	if (!(await exists(linkPath))) return false;
	try {
		const target = await readlink(linkPath);
		const resolved = target.startsWith("/") ? target : join(dirname(linkPath), target);
		return resolved === sourcePath;
	} catch {
		return false;
	}
}

async function buildRows(): Promise<ExtensionRow[]> {
	await mkdir(RUNTIME_DIR, { recursive: true });
	const sourcePaths = await readSourceExtensions();
	const rows: ExtensionRow[] = [];

	for (const sourcePath of sourcePaths) {
		const file = basename(sourcePath);
		const id = file;
		const linkPath = join(RUNTIME_DIR, file);
		rows.push({
			id,
			name: file,
			sourcePath,
			linkPath,
			enabled: await isEnabledLink(sourcePath, linkPath),
		});
	}

	return rows;
}

async function bootstrapRuntimeIfNeeded(): Promise<boolean> {
	await mkdir(RUNTIME_DIR, { recursive: true });
	if (await exists(BOOTSTRAP_MARKER)) return false;

	const sourcePaths = await readSourceExtensions();
	for (const sourcePath of sourcePaths) {
		const linkPath = join(RUNTIME_DIR, basename(sourcePath));
		if (!(await exists(linkPath))) {
			await symlink(sourcePath, linkPath);
		}
	}

	await writeFile(BOOTSTRAP_MARKER, "initialized\n", "utf8");
	return true;
}

async function applyStates(rows: ExtensionRow[], states: Map<string, boolean>): Promise<void> {
	await mkdir(RUNTIME_DIR, { recursive: true });

	for (const row of rows) {
		const nextEnabled = states.get(row.id) ?? row.enabled;
		if (nextEnabled) {
			if (await exists(row.linkPath)) {
				await rm(row.linkPath, { force: true, recursive: true });
			}
			await symlink(row.sourcePath, row.linkPath);
		} else {
			await rm(row.linkPath, { force: true, recursive: true });
		}
	}
}

async function showPicker(ctx: ExtensionCommandContext, rows: ExtensionRow[]): Promise<PickerResult | undefined> {
	return ctx.ui.custom((tui, theme, _kb, done: (value: PickerResult | undefined) => void) => {
		let selectedIndex = 0;
		const draft = new Map<string, boolean>(rows.map((row) => [row.id, row.enabled]));
		let cachedLines: string[] | undefined;

		function refresh(): void {
			cachedLines = undefined;
			tui.requestRender();
		}

		function move(delta: number): void {
			selectedIndex = Math.min(rows.length - 1, Math.max(0, selectedIndex + delta));
			refresh();
		}

		return {
			handleInput(data: string) {
				if (matchesKey(data, Key.up) || matchesKey(data, Key.ctrl("p")) || data === "k") {
					move(-1);
					return;
				}
				if (matchesKey(data, Key.down) || matchesKey(data, Key.ctrl("n")) || data === "j") {
					move(1);
					return;
				}
				if (matchesKey(data, Key.space)) {
					const row = rows[selectedIndex];
					if (!row) return;
					draft.set(row.id, !(draft.get(row.id) ?? row.enabled));
					selectedIndex = Math.min(rows.length - 1, selectedIndex + 1);
					refresh();
					return;
				}
				if (matchesKey(data, Key.enter)) {
					done({ states: new Map(draft) });
					return;
				}
				if (matchesKey(data, Key.escape)) {
					done(undefined);
				}
			},
			render(width: number) {
				if (cachedLines) return cachedLines;

				const lines: string[] = [];
				const add = (line: string) => lines.push(truncateToWidth(line, width));

				add(theme.fg("accent", theme.bold("Extension Manager")));
				add(theme.fg("dim", `Runtime overlay: ${RUNTIME_DIR}`));
				lines.push("");

				for (let i = 0; i < rows.length; i++) {
					const row = rows[i];
					const focused = i === selectedIndex;
					const value = draft.get(row.id) ?? row.enabled;
					const mark = value ? "[x]" : "[ ]";
					const prefix = focused ? theme.fg("accent", "> ") : "  ";
					const label = `${mark} ${row.name}`;
					add(prefix + (focused ? theme.fg("accent", label) : label));
				}

				lines.push("");
				add(theme.fg("dim", "↑/↓, j/k navigate • Space toggle • Enter apply+reload • Esc cancel"));
				cachedLines = lines;
				return lines;
			},
			invalidate() {
				cachedLines = undefined;
			},
		};
	});
}

function hasChanges(rows: ExtensionRow[], states: Map<string, boolean>): boolean {
	for (const row of rows) {
		const next = states.get(row.id) ?? row.enabled;
		if (next !== row.enabled) return true;
	}
	return false;
}

export default function extensionsManager(pi: ExtensionAPI): void {
	pi.registerCommand("extensions", {
		description: "Toggle runtime-managed extensions interactively",
		handler: async (_args, ctx) => {
			await mkdir(RUNTIME_DIR, { recursive: true });
			const rows = await buildRows();
			const result = await showPicker(ctx, rows);
			if (!result) return;

			const changed = hasChanges(rows, result.states);
			if (changed) {
				await applyStates(rows, result.states);
			}

			notify(ctx, "Applying extension set and reloading runtime...", "info");
			await ctx.reload();
			return;
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		const bootstrapped = await bootstrapRuntimeIfNeeded();
		if (bootstrapped) {
			notify(ctx, "Initialized extension runtime overlay. Run /reload (or /extensions + Enter) to activate.", "info");
		}
	});
}
