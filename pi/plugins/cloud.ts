import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import readline from "node:readline";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Key, matchesKey, truncateToWidth } from "@mariozechner/pi-tui";

type NotifyLevel = "info" | "warning" | "error";
type RequestKind = "pickMany" | "pickOne" | "confirm";

interface WorkerEvent {
	type: "notify" | "progress" | "request" | "result" | "done" | "error";
	level?: NotifyLevel;
	text?: string;
	key?: "cloud" | "cloud-clean";
	id?: string;
	kind?: RequestKind;
	title?: string;
	options?: string[];
	summaryLines?: string[];
	attachCommand?: string;
	copiedToClipboard?: boolean;
	tmuxSessionName?: string;
	remoteWorkspace?: string;
	bookmarkName?: string;
	message?: string;
}

function scriptPath(): string {
	const here = path.dirname(fileURLToPath(import.meta.url));
	return path.resolve(here, "../scripts/cloud.ts");
}

async function pickMany(ctx: any, title: string, options: string[]): Promise<number[] | undefined> {
	if (options.length === 0) return [];
	return ctx.ui.custom((tui: any, theme: any, _kb: any, done: (value: number[] | undefined) => void) => {
		let selectedIndex = 0;
		const selected = new Set<number>();
		let cachedLines: string[] | undefined;

		function refresh() {
			cachedLines = undefined;
			tui.requestRender();
		}

		return {
			handleInput(data: string) {
				if (matchesKey(data, Key.up) || matchesKey(data, Key.ctrl("p")) || data === "k") {
					selectedIndex = Math.max(0, selectedIndex - 1);
					refresh();
					return;
				}
				if (matchesKey(data, Key.down) || matchesKey(data, Key.ctrl("n")) || data === "j") {
					selectedIndex = Math.min(options.length - 1, selectedIndex + 1);
					refresh();
					return;
				}
				if (matchesKey(data, Key.space)) {
					if (selected.has(selectedIndex)) selected.delete(selectedIndex);
					else selected.add(selectedIndex);
					refresh();
					return;
				}
				if (matchesKey(data, Key.enter)) {
					done(Array.from(selected).sort((a, b) => a - b));
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
				add(theme.fg("accent", title));
				lines.push("");
				for (let i = 0; i < options.length; i++) {
					const focused = i === selectedIndex;
					const mark = selected.has(i) ? "[x]" : "[ ]";
					const prefix = focused ? theme.fg("accent", "> ") : "  ";
					const text = `${mark} ${options[i]}`;
					add(prefix + (focused ? theme.fg("accent", text) : text));
				}
				lines.push("");
				add(theme.fg("dim", "↑/↓, j/k navigate • Space toggle • Enter confirm • Esc cancel"));
				cachedLines = lines;
				return lines;
			},
			invalidate() {
				cachedLines = undefined;
			},
		};
	});
}

async function pickOne(ctx: any, title: string, options: string[]): Promise<number | undefined> {
	if (options.length === 0) return undefined;
	return ctx.ui.custom((tui: any, theme: any, _kb: any, done: (value: number | undefined) => void) => {
		let selectedIndex = 0;
		let cachedLines: string[] | undefined;

		function refresh() {
			cachedLines = undefined;
			tui.requestRender();
		}

		return {
			handleInput(data: string) {
				if (matchesKey(data, Key.up) || matchesKey(data, Key.ctrl("p")) || data === "k") {
					selectedIndex = Math.max(0, selectedIndex - 1);
					refresh();
					return;
				}
				if (matchesKey(data, Key.down) || matchesKey(data, Key.ctrl("n")) || data === "j") {
					selectedIndex = Math.min(options.length - 1, selectedIndex + 1);
					refresh();
					return;
				}
				if (matchesKey(data, Key.enter)) {
					done(selectedIndex);
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
				add(theme.fg("accent", title));
				lines.push("");
				for (let i = 0; i < options.length; i++) {
					const focused = i === selectedIndex;
					const prefix = focused ? theme.fg("accent", "> ") : "  ";
					add(prefix + (focused ? theme.fg("accent", options[i]) : options[i]));
				}
				lines.push("");
				add(theme.fg("dim", "↑/↓, j/k navigate • Enter confirm • Esc cancel"));
				cachedLines = lines;
				return lines;
			},
			invalidate() {
				cachedLines = undefined;
			},
		};
	});
}

async function confirmCloudCleanup(ctx: any, title: string, summaryLines: string[]): Promise<boolean | undefined> {
	return ctx.ui.custom((tui: any, theme: any, _kb: any, done: (value: boolean | undefined) => void) => {
		const actions = ["Proceed with deletion", "Cancel"];
		let selectedIndex = 0;
		let cachedLines: string[] | undefined;

		function refresh() {
			cachedLines = undefined;
			tui.requestRender();
		}

		return {
			handleInput(data: string) {
				if (matchesKey(data, Key.up) || matchesKey(data, Key.ctrl("p")) || data === "k") {
					selectedIndex = Math.max(0, selectedIndex - 1);
					refresh();
					return;
				}
				if (matchesKey(data, Key.down) || matchesKey(data, Key.ctrl("n")) || data === "j") {
					selectedIndex = Math.min(actions.length - 1, selectedIndex + 1);
					refresh();
					return;
				}
				if (matchesKey(data, Key.enter)) {
					done(selectedIndex === 0);
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
				add(theme.fg("accent", title));
				lines.push("");
				for (const line of summaryLines) add(line);
				lines.push("");
				for (let i = 0; i < actions.length; i++) {
					const focused = i === selectedIndex;
					const prefix = focused ? theme.fg("accent", "> ") : "  ";
					add(prefix + (focused ? theme.fg("accent", actions[i]) : actions[i]));
				}
				lines.push("");
				add(theme.fg("dim", "↑/↓, j/k navigate • Enter confirm • Esc cancel"));
				cachedLines = lines;
				return lines;
			},
			invalidate() {
				cachedLines = undefined;
			},
		};
	});
}

async function runWorker(
	ctx: any,
	command: "run" | "clean",
	context: Record<string, unknown>,
): Promise<void> {
	const cloudScript = scriptPath();
	const contextBase64 = Buffer.from(JSON.stringify(context), "utf8").toString("base64");
	const child = spawn("bun", [cloudScript, command, "--mode", "ndjson", "--context-base64", contextBase64], {
		stdio: ["pipe", "pipe", "pipe"],
	});

	const setWidget = (key: "cloud" | "cloud-clean", text: string | undefined) => {
		const widgetKey = key === "cloud" ? "cloud-progress" : "cloud-clean-progress";
		ctx.ui.setWidget(widgetKey, text ? [text] : undefined, { placement: "belowEditor" });
	};

	const sendResponse = (id: string, value: unknown) => {
		child.stdin.write(`${JSON.stringify({ type: "response", id, value })}\n`);
	};

	const rl = readline.createInterface({ input: child.stdout });
	const stderrRl = readline.createInterface({ input: child.stderr });
	let finalError: string | undefined;

	stderrRl.on("line", (line) => {
		if (!line.trim()) return;
		if (!ctx.hasUI) process.stderr.write(`${line}\n`);
	});

	await new Promise<void>((resolve, reject) => {
		rl.on("line", async (line) => {
			const trimmed = line.trim();
			if (!trimmed) return;
			let event: WorkerEvent;
			try {
				event = JSON.parse(trimmed) as WorkerEvent;
			} catch {
				return;
			}

			if (event.type === "notify" && event.text) {
				if (ctx.hasUI) ctx.ui.notify(event.text, event.level ?? "info");
				else if ((event.level ?? "info") === "error") process.stderr.write(`${event.text}\n`);
			}

			if (event.type === "progress" && event.key) {
				setWidget(event.key, event.text || undefined);
			}

			if (event.type === "result" && event.attachCommand) {
				if (!ctx.hasUI) {
					process.stdout.write(`${event.attachCommand}\n`);
				} else {
					ctx.ui.notify(
						`Cloud started in tmux '${event.tmuxSessionName}'. Attach: ${event.attachCommand}${event.copiedToClipboard ? " (copied to clipboard)" : ""} | Remote workspace: ${event.remoteWorkspace} | Bookmark: ${event.bookmarkName} | Pull back later: jj git fetch --remote hetzner-1`,
						"info",
					);
				}
			}

			if (event.type === "request" && event.id && event.kind && event.title) {
				try {
					if (event.kind === "pickMany") {
						const value = await pickMany(ctx, event.title, event.options ?? []);
						sendResponse(event.id, value);
					}
					if (event.kind === "pickOne") {
						const value = await pickOne(ctx, event.title, event.options ?? []);
						sendResponse(event.id, value);
					}
					if (event.kind === "confirm") {
						const value = await confirmCloudCleanup(ctx, event.title, event.summaryLines ?? []);
						sendResponse(event.id, value);
					}
				} catch (error) {
					sendResponse(event.id, undefined);
					finalError = error instanceof Error ? error.message : String(error);
				}
			}

			if (event.type === "error") {
				finalError = event.message ?? "Unknown worker error";
			}

			if (event.type === "done") {
				resolve();
			}
		});

		child.on("error", (error) => {
			reject(error);
		});

		child.on("close", (code) => {
			setWidget("cloud", undefined);
			setWidget("cloud-clean", undefined);
			if (finalError) {
				reject(new Error(finalError));
				return;
			}
			if (code !== 0) {
				reject(new Error(`cloud worker exited with status ${code}`));
				return;
			}
			resolve();
		});
	});
}

export default function (pi: ExtensionAPI): void {
	pi.registerCommand("cloud", {
		description: "Move this session to hetzner-1 and run it in remote tmux",
		handler: async (args, ctx) => {
			try {
				await runWorker(ctx, "run", {
					cwd: ctx.cwd,
					sessionFile: ctx.sessionManager.getSessionFile(),
					cloudPrompt: args.trim() || "continue",
					hasUI: ctx.hasUI,
				});
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				if (!ctx.hasUI) process.stderr.write(`/cloud failed: ${message}\n`);
				else ctx.ui.notify(`/cloud failed: ${message}`, "error");
			}
		},
	});

	pi.registerCommand("cloud-clean", {
		description: "Clean up cloud workspaces on hetzner-1",
		handler: async (_args, ctx) => {
			try {
				await runWorker(ctx, "clean", {
					cwd: ctx.cwd,
					hasUI: ctx.hasUI,
				});
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				if (ctx.hasUI) ctx.ui.notify(`/cloud-clean failed: ${message}`, "error");
				else process.stderr.write(`/cloud-clean failed: ${message}\n`);
			}
		},
	});
}
