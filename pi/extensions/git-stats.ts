import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import { getGitStats, type GitStats } from "../scripts/git-stats";

function formatTokens(count: number): string {
	if (count < 1000) return `${count}`;
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	return `${(count / 1000000).toFixed(1)}M`;
}

const singleLine = (text: string) => text.replace(/[\r\n\t]/g, " ");

export default function (pi: ExtensionAPI): void {
	let generation = 0;
	let stats: GitStats | undefined;
	let requestRender: (() => void) | undefined;

	async function refresh(ctx: ExtensionContext): Promise<void> {
		if (!ctx.hasUI) return;
		const current = ++generation;
		const result = await getGitStats(ctx.cwd);
		if (current !== generation) return;
		stats = result;
		requestRender?.();
	}

	function installFooter(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;
		ctx.ui.setStatus("git-stats", undefined);
		ctx.ui.setFooter((tui, theme, footerData) => {
			requestRender = () => tui.requestRender();
			const unsubscribe = footerData.onBranchChange(requestRender);
			return {
				invalidate() {},
				dispose() {
					unsubscribe();
					requestRender = undefined;
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
					? theme.fg("dim", ` +${stats.added} −${stats.removed}`)
					: "";
				const pathWidth = Math.max(0, width - visibleWidth(git));
				const lines = [truncateToWidth(theme.fg("dim", truncateToWidth(singleLine(directory), pathWidth)) + git, width)];

				let input = 0, output = 0, cacheRead = 0, cacheWrite = 0, cost = 0;
				for (const entry of ctx.sessionManager.getEntries()) {
					if (entry.type !== "message") continue;
					const message = entry.message;
					// Newer Pi versions also account for nested tool usage.
					if (!("usage" in message) || !message.usage) continue;
					const usage = message.usage;
					input += usage.input;
					output += usage.output;
					cacheRead += usage.cacheRead;
					cacheWrite += usage.cacheWrite;
					cost += usage.cost.total;
				}
				const parts: string[] = [];
				if (input) parts.push(`↑${formatTokens(input)}`);
				if (output) parts.push(`↓${formatTokens(output)}`);
				if (cacheRead) parts.push(`R${formatTokens(cacheRead)}`);
				if (cacheWrite) parts.push(`W${formatTokens(cacheWrite)}`);
				const totalInput = input + cacheRead + cacheWrite;
				if (cacheRead && totalInput) parts.push(`CH${(100 * cacheRead / totalInput).toFixed(1)}%`);
				const subscription = ctx.model && ctx.modelRegistry.isUsingOAuth(ctx.model);
				if (cost || subscription) parts.push(`$${cost.toFixed(3)}${subscription ? " (sub)" : ""}`);
				const context = ctx.getContextUsage();
				const percent = context?.percent;
				const contextText = `${percent == null ? "?" : percent.toFixed(1)}%/${formatTokens(context?.contextWindow ?? ctx.model?.contextWindow ?? 0)}`;
				parts.push(theme.fg((percent ?? 0) > 90 ? "error" : (percent ?? 0) > 70 ? "warning" : "dim", contextText));
				const left = theme.fg("dim", parts.join(" "));
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
		stats = undefined;
		installFooter(ctx);
		await refresh(ctx);
	}

	pi.on("session_start", (_event, ctx) => start(ctx));
	pi.on("session_switch", (_event, ctx) => start(ctx));
	pi.on("session_fork", (_event, ctx) => start(ctx));
	pi.on("tool_execution_end", (_event, ctx) => refresh(ctx));
	pi.on("agent_end", (_event, ctx) => refresh(ctx));
	pi.on("session_shutdown", (_event, ctx) => {
		generation++;
		requestRender = undefined;
		if (ctx.hasUI) ctx.ui.setFooter(undefined);
	});
}
