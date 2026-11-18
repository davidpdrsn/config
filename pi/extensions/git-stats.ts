import { watch, type FSWatcher } from "node:fs";
import { copyToClipboard, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { rgbColor, truncateToWidth, visibleWidth, type TuiMouseEvent, type TuiMouseEventResult } from "@earendil-works/pi-tui";
import { getGitStats, type GitStats } from "../scripts/git-stats";
import { getLoadedSkills } from "../scripts/loaded-skills";

function formatTokens(count: number): string {
	if (count < 1000) return `${count}`;
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	return `${(count / 1000000).toFixed(1)}M`;
}

const diffAddedColor = rgbColor(80, 130, 70);
const diffRemovedColor = rgbColor(170, 70, 80);

const singleLine = (text: string) => text.replace(/[\r\n\t]/g, " ");

// Delay between a file change and the refresh it triggers. Changes during the
// delay share one refresh.
const refreshDelayMs = 300;

// Inside .git, only these paths change the diff against HEAD. Other writes,
// such as lock files, logs and GitButler metadata, would only cause extra refreshes.
function isRelevantChange(filename: string | null): boolean {
	if (!filename) return true;
	const path = filename.replaceAll("\\", "/");
	if (path !== ".git" && !path.startsWith(".git/")) return true;
	return path === ".git/HEAD" || path === ".git/index" || path === ".git/packed-refs" || path.startsWith(".git/refs/");
}

export default function (pi: ExtensionAPI): void {
	let generation = 0;
	let stats: GitStats | undefined;
	let requestRender: (() => void) | undefined;
	let watcher: FSWatcher | undefined;
	let watchedRoot: string | undefined;
	let refreshTimer: ReturnType<typeof setTimeout> | undefined;

	async function refresh(ctx: ExtensionContext): Promise<void> {
		if (!ctx.hasUI) return;
		const current = ++generation;
		const result = await getGitStats(ctx.cwd);
		if (current !== generation) return;
		stats = result;
		watchRoot(ctx, result?.root);
		requestRender?.();
	}

	function scheduleRefresh(ctx: ExtensionContext): void {
		if (refreshTimer) return;
		refreshTimer = setTimeout(() => {
			refreshTimer = undefined;
			void refresh(ctx);
		}, refreshDelayMs);
	}

	// Tool events miss edits made outside pi, such as in an editor or another
	// terminal, so the footer also refreshes when files in the repository change.
	function watchRoot(ctx: ExtensionContext, root: string | undefined): void {
		if (root === watchedRoot) return;
		stopWatching();
		if (!root) return;
		try {
			watcher = watch(root, { recursive: true }, (_event, filename) => {
				if (isRelevantChange(filename)) scheduleRefresh(ctx);
			});
			watcher.on("error", () => stopWatching());
			watchedRoot = root;
		} catch {
			// Without a watcher, the tool and agent events below still refresh the stats.
			watcher = undefined;
		}
	}

	function stopWatching(): void {
		watcher?.close();
		watcher = undefined;
		watchedRoot = undefined;
		if (refreshTimer) clearTimeout(refreshTimer);
		refreshTimer = undefined;
	}

	function installFooter(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;
		ctx.ui.setStatus("git-stats", undefined);
		// Each skill has a `/skill:name` command whose source path is its SKILL.md.
		const skillNames = new Map(
			pi
				.getCommands()
				.filter((command) => command.source === "skill")
				.map((command) => [command.sourceInfo.path, command.name.replace(/^skill:/, "")]),
		);
		ctx.ui.setFooter((tui, theme, footerData) => {
			requestRender = () => tui.requestRender();
			const unsubscribe = footerData.onBranchChange(requestRender);
			// Columns of the session ID on the first footer line, from the last render.
			let sessionColumns: { start: number; end: number } | undefined;
			return {
				invalidate() {},
				dispose() {
					unsubscribe();
					requestRender = undefined;
				},
				handleMouse(event: TuiMouseEvent): TuiMouseEventResult | undefined {
					if (event.type !== "click" || event.button !== "left" || event.y !== 0 || !sessionColumns) return undefined;
					if (event.x < sessionColumns.start || event.x >= sessionColumns.end) return undefined;
					const command = `pi --session ${ctx.sessionManager.getSessionId()}`;
					copyToClipboard(command).then(
						() => ctx.ui.notify(`Copied ${command}`, "info"),
						(error: unknown) => ctx.ui.notify(`Copy failed: ${error instanceof Error ? error.message : String(error)}`, "error"),
					);
					return { handled: true };
				},
				render(width: number): string[] {
				const home = process.env.HOME || process.env.USERPROFILE;
				let directory = ctx.cwd;
				if (home && (directory === home || directory.startsWith(`${home}/`))) {
					directory = `~${directory.slice(home.length)}`;
				}
				const branch = footerData.getGitBranch();
				if (branch && branch !== "gitbutler/workspace") directory += ` (${branch})`;
				const name = ctx.sessionManager.getSessionName();
				if (name) directory += ` • ${name}`;
				const git = stats
					? ` ${theme.style(`+${stats.added}`, { fg: diffAddedColor })} ${theme.style(`−${stats.removed}`, { fg: diffRemovedColor })}`
					: "";
				const sessionId = ctx.sessionManager.getSessionId();
				// Keep the UUID intact for copying. Hide it when the row is too narrow.
				const sessionWidth = visibleWidth(sessionId);
				const showSession = width >= sessionWidth + visibleWidth(git) + 3;
				const directoryWidth = showSession ? width - sessionWidth - 2 : width;
				const pathWidth = Math.max(0, directoryWidth - visibleWidth(git));
				let directoryLine = truncateToWidth(theme.fg("dim", truncateToWidth(singleLine(directory), pathWidth)) + git, directoryWidth);
				sessionColumns = showSession ? { start: width - sessionWidth, end: width } : undefined;
				if (showSession) {
					directoryLine += " ".repeat(width - visibleWidth(directoryLine) - sessionWidth) + theme.fg("dim", sessionId);
				}
				const lines = [directoryLine];

				let input = 0, output = 0, cacheRead = 0;
				for (const entry of ctx.sessionManager.getEntries()) {
					if (entry.type !== "message") continue;
					const message = entry.message;
					// Newer Pi versions also account for nested tool usage.
					if (!("usage" in message) || !message.usage) continue;
					const usage = message.usage;
					input += usage.input;
					output += usage.output;
					cacheRead += usage.cacheRead;
				}
				const parts = [
					`input: ${formatTokens(input)}`,
					`output: ${formatTokens(output)}`,
					`cache: ${formatTokens(cacheRead)}`,
				];
				const context = ctx.getContextUsage();
				const percent = context?.percent;
				const contextText = `context: ${percent == null ? "?" : percent.toFixed(1)}%`;
				parts.push(theme.fg((percent ?? 0) > 90 ? "error" : (percent ?? 0) > 70 ? "warning" : "dim", contextText));
				const left = theme.fg("dim", parts.join(" · "));
				let right = ctx.model?.id ?? "no-model";
				if (ctx.model?.reasoning) right += ` • ${pi.getThinkingLevel()}`;
				if (ctx.model && footerData.getAvailableProviderCount() > 1) {
					const withProvider = `(${ctx.model.provider}) ${right}`;
					if (visibleWidth(left) + 2 + visibleWidth(withProvider) <= width) right = withProvider;
				}
				const remaining = width - visibleWidth(left) - 2;
				if (remaining > 0) {
					right = truncateToWidth(right, remaining);
					lines.push(left + " ".repeat(Math.max(2, width - visibleWidth(left) - visibleWidth(right))) + theme.fg("dim", right));
				} else {
					lines.push(truncateToWidth(left, width));
				}
				const skills = getLoadedSkills(ctx.sessionManager.buildContextEntries(), ctx.cwd, skillNames);
				if (skills.length) lines.push(truncateToWidth(theme.fg("dim", `skills: ${skills.join(", ")}`), width));
				const statuses = [...footerData.getExtensionStatuses()]
					.filter(([key]) => key !== "git-stats")
					.sort(([a], [b]) => a.localeCompare(b))
					.map(([, text]) => singleLine(text));
				if (statuses.length) lines.push(truncateToWidth(statuses.join(" "), width));
				return lines;
				},
			};
		});
	}

	async function start(ctx: ExtensionContext): Promise<void> {
		stopWatching();
		stats = undefined;
		installFooter(ctx);
		await refresh(ctx);
	}

	pi.on("session_start", (_event, ctx) => start(ctx));
	pi.on("tool_execution_end", (_event, ctx) => refresh(ctx));
	pi.on("agent_end", (_event, ctx) => refresh(ctx));
	pi.on("session_shutdown", (_event, ctx) => {
		generation++;
		stopWatching();
		requestRender = undefined;
		if (ctx.hasUI) ctx.ui.setFooter(undefined);
	});
}
