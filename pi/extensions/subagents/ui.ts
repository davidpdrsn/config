import { getMarkdownTheme, type Theme } from "@earendil-works/pi-coding-agent";
import {
	Box,
	type Component,
	Container,
	type KeybindingsManager,
	Markdown,
	Spacer,
	Text,
	type TUI,
	truncateToWidth,
	visibleWidth,
	wrapTextWithAnsi,
} from "@earendil-works/pi-tui";
import type { AgentStatus, Subagent, UsageTotals } from "./agent";

export const SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

/** Plain data about one agent. Stored in tool result details and custom messages so old entries still render. */
export interface AgentSnapshot {
	id: string;
	label: string;
	status: AgentStatus;
	model?: string;
	task: string;
	activity?: string;
	output?: string;
	error?: string;
	durationMs: number;
	usage: UsageTotals;
	alive: boolean;
}

export function snapshot(agent: Subagent): AgentSnapshot {
	const start = agent.runStartedAt ?? agent.createdAt;
	return {
		id: agent.id,
		label: agent.label,
		status: agent.status,
		model: agent.model ?? agent.requestedModel,
		task: agent.task,
		activity: agent.activity,
		output: agent.output,
		error: agent.error,
		durationMs: (agent.finishedAt ?? Date.now()) - start,
		usage: { ...agent.usage },
		alive: agent.alive,
	};
}

export function formatDuration(ms: number): string {
	const seconds = Math.max(0, Math.round(ms / 1000));
	if (seconds < 60) return `${seconds}s`;
	const minutes = Math.floor(seconds / 60);
	if (minutes < 60) return `${minutes}m${String(seconds % 60).padStart(2, "0")}s`;
	return `${Math.floor(minutes / 60)}h${String(minutes % 60).padStart(2, "0")}m`;
}

export function formatTokens(count: number): string {
	if (count < 1000) return `${count}`;
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	return `${(count / 1000000).toFixed(1)}M`;
}

export function formatUsage(usage: UsageTotals): string {
	const parts: string[] = [];
	if (usage.turns) parts.push(`${usage.turns} turn${usage.turns === 1 ? "" : "s"}`);
	if (usage.input || usage.cacheRead) parts.push(`↑${formatTokens(usage.input + usage.cacheRead)}`);
	if (usage.output) parts.push(`↓${formatTokens(usage.output)}`);
	return parts.join(" ");
}

export function shortModel(model: string | undefined): string {
	if (!model) return "default model";
	const slash = model.indexOf("/");
	return slash === -1 ? model : model.slice(slash + 1);
}

const oneLine = (text: string) => text.replace(/\s+/g, " ").trim();

export function statusIcon(status: AgentStatus, theme: Theme, frame = 0): string {
	switch (status) {
		case "starting":
			return theme.fg("muted", "○");
		case "running":
			return theme.fg("accent", SPINNER[frame % SPINNER.length]);
		case "done":
			return theme.fg("success", "✓");
		case "failed":
			return theme.fg("error", "✗");
		case "aborted":
			return theme.fg("warning", "■");
		case "stopped":
			return theme.fg("dim", "■");
	}
}

function statusText(agent: AgentSnapshot, theme: Theme): string {
	switch (agent.status) {
		case "starting":
			return theme.fg("muted", "starting");
		case "running":
			return theme.fg("toolOutput", agent.activity ? oneLine(agent.activity) : "running");
		case "done":
			return theme.fg("success", agent.alive ? "done, idle" : "done");
		case "failed":
			return theme.fg("error", `failed: ${oneLine(agent.error ?? "unknown error")}`);
		case "aborted":
			return theme.fg("warning", "aborted");
		case "stopped":
			return theme.fg("dim", "stopped");
	}
}

/** One status row: icon, label, model, elapsed time, then what the agent is doing. */
export function agentRow(agent: AgentSnapshot, theme: Theme, width: number, frame: number, labelWidth = 0): string {
	const label = theme.bold(agent.label) + " ".repeat(Math.max(0, labelWidth - visibleWidth(agent.label)));
	const meta = theme.fg("dim", `${shortModel(agent.model)} · ${formatDuration(agent.durationMs)}`);
	const usage = agent.status === "running" || agent.usage.turns === 0 ? "" : theme.fg("dim", ` · ${formatUsage(agent.usage)}`);
	const line = `${statusIcon(agent.status, theme, frame)} ${label}  ${meta}  ${statusText(agent, theme)}${usage}`;
	return truncateToWidth(line, width);
}

export interface WidgetState {
	agents(): AgentSnapshot[];
	frame(): number;
}

const MAX_WIDGET_ROWS = 6;

/** The persistent widget above the editor that lists live agents. */
export function createWidget(state: WidgetState, theme: Theme): Component {
	return {
		invalidate() {},
		render(width: number): string[] {
			const agents = state.agents();
			if (agents.length === 0) return [];
			const running = agents.filter((a) => a.status === "running" || a.status === "starting").length;
			const idle = agents.length - running;
			const counts = [running ? `${running} running` : "", idle ? `${idle} idle` : ""].filter(Boolean).join(" · ");
			const lines = [truncateToWidth(`${theme.fg("accent", theme.bold("Subagents"))} ${theme.fg("dim", `${counts} · /agents to manage`)}`, width)];
			const labelWidth = Math.min(24, Math.max(...agents.map((a) => visibleWidth(a.label))));
			for (const agent of agents.slice(0, MAX_WIDGET_ROWS)) {
				lines.push(agentRow(agent, theme, width, state.frame(), labelWidth));
			}
			if (agents.length > MAX_WIDGET_ROWS) {
				lines.push(theme.fg("dim", `  +${agents.length - MAX_WIDGET_ROWS} more`));
			}
			return lines;
		},
	};
}

const COLLAPSED_OUTPUT_LINES = 8;

/** Results of one or more agents, used for tool results and delivered-result messages. */
export function renderAgentResults(
	agents: AgentSnapshot[],
	options: { expanded: boolean; header?: string; showOutput: boolean },
	theme: Theme,
): Component {
	const container = new Container();
	if (options.header) container.addChild(new Text(options.header, 0, 0));
	const labelWidth = Math.min(24, Math.max(0, ...agents.map((a) => visibleWidth(a.label))));
	for (const agent of agents) {
		container.addChild(new RowText((width) => agentRow(agent, theme, width, 0, labelWidth)));
		if (!options.showOutput) continue;
		const output = agent.output?.trim();
		if (!output) continue;
		if (options.expanded) {
			container.addChild(new Spacer(1));
			container.addChild(new Markdown(output, 2, 0, getMarkdownTheme()));
			container.addChild(new Spacer(1));
		} else {
			const lines = output.split("\n");
			let preview = lines.slice(0, COLLAPSED_OUTPUT_LINES).join("\n");
			if (lines.length > COLLAPSED_OUTPUT_LINES) {
				preview += `\n${theme.fg("dim", `… ${lines.length - COLLAPSED_OUTPUT_LINES} more lines (expand to see all)`)}`;
			}
			container.addChild(new Text(theme.fg("toolOutput", preview), 2, 0));
		}
	}
	return container;
}

/** A single line computed at render time, so it can use the real width. */
class RowText implements Component {
	constructor(private readonly line: (width: number) => string) {}
	invalidate() {}
	render(width: number): string[] {
		return [this.line(width)];
	}
}

export function renderResultMessage(agent: AgentSnapshot, expanded: boolean, outputPad: number, theme: Theme): Component {
	const box = new Box(outputPad, 1, (text) => theme.bg("customMessageBg", text));
	const verb = agent.status === "done" ? "finished" : agent.status;
	box.addChild(
		renderAgentResults(
			[agent],
			{ expanded, header: theme.fg("accent", theme.bold(`Subagent ${agent.label} ${verb}`)), showOutput: true },
			theme,
		),
	);
	return box;
}

export type OverlayAction = { type: "close" } | { type: "send"; id: string };

export interface OverlayController {
	agents(): Subagent[];
	frame(): number;
	stop(id: string): void;
	stopAll(): void;
	abort(id: string): void;
	subscribe(listener: () => void): () => void;
}

/**
 * `/agents` overlay. The list view shows every agent with a preview of the selected one.
 * Enter opens a scrollable transcript of the selected agent.
 */
export class AgentsOverlay implements Component {
	private selected = 0;
	private mode: "list" | "detail" = "list";
	private scroll = 0;
	private followEnd = true;
	private readonly unsubscribe: () => void;
	private transcriptCache?: { key: string; lines: string[] };

	constructor(
		private readonly tui: TUI,
		private readonly theme: Theme,
		private readonly keybindings: KeybindingsManager,
		private readonly controller: OverlayController,
		private readonly done: (action: OverlayAction) => void,
		initialId?: string,
	) {
		this.unsubscribe = controller.subscribe(() => this.tui.requestRender());
		if (initialId) {
			const index = controller.agents().findIndex((a) => a.id === initialId);
			if (index >= 0) this.selected = index;
		}
	}

	dispose(): void {
		this.unsubscribe();
	}

	invalidate(): void {
		this.transcriptCache = undefined;
	}

	private current(): Subagent | undefined {
		const agents = this.controller.agents();
		if (agents.length === 0) return undefined;
		this.selected = Math.max(0, Math.min(this.selected, agents.length - 1));
		return agents[this.selected];
	}

	private height(): number {
		return Math.max(10, Math.floor(this.tui.terminal.rows * 0.85) - 2);
	}

	handleInput(data: string): void {
		const kb = this.keybindings;
		const agent = this.current();
		if (kb.matches(data, "tui.select.cancel") || data === "q") {
			if (this.mode === "detail") {
				this.mode = "list";
				this.tui.requestRender();
			} else {
				this.done({ type: "close" });
			}
			return;
		}
		if (this.mode === "list") {
			const count = this.controller.agents().length;
			if (kb.matches(data, "tui.select.up") || data === "k") this.selected = Math.max(0, this.selected - 1);
			else if (kb.matches(data, "tui.select.down") || data === "j") this.selected = Math.min(count - 1, this.selected + 1);
			else if (kb.matches(data, "tui.select.confirm") && agent) {
				this.mode = "detail";
				this.followEnd = true;
				this.transcriptCache = undefined;
			} else this.handleAction(data, agent);
		} else {
			const page = Math.max(1, this.height() - 6);
			if (kb.matches(data, "tui.select.up") || data === "k") this.scrollBy(-1);
			else if (kb.matches(data, "tui.select.down") || data === "j") this.scrollBy(1);
			else if (kb.matches(data, "tui.select.pageUp")) this.scrollBy(-page);
			else if (kb.matches(data, "tui.select.pageDown") || data === " ") this.scrollBy(page);
			else if (data === "g") this.scrollBy(-Infinity);
			else if (data === "G") this.scrollBy(Infinity);
			else this.handleAction(data, agent);
		}
		this.tui.requestRender();
	}

	private handleAction(data: string, agent: Subagent | undefined): void {
		if (data === "X") this.controller.stopAll();
		if (!agent) return;
		if (data === "x") this.controller.stop(agent.id);
		else if (data === "a") this.controller.abort(agent.id);
		else if (data === "m") this.done({ type: "send", id: agent.id });
	}

	private scrollBy(delta: number): void {
		this.scroll += delta;
		this.followEnd = delta === Infinity;
		if (delta === -Infinity) this.scroll = 0;
	}

	render(width: number): string[] {
		const theme = this.theme;
		const inner = Math.max(20, width - 4);
		const agents = this.controller.agents();
		const agent = this.current();
		const body = this.mode === "detail" && agent ? this.renderDetail(agent, inner) : this.renderList(agents, inner);
		const hints =
			this.mode === "list"
				? "↑↓ select · enter transcript · m message · a abort run · x stop · X stop all · esc close"
				: "↑↓/pgup/pgdn scroll · g/G top/bottom · m message · a abort run · x stop · esc back";
		const lines = [...body, "", theme.fg("dim", truncateToWidth(hints, inner))];
		return frame(lines, width, theme, this.mode === "detail" && agent ? `Subagent ${agent.label}` : "Subagents");
	}

	private renderList(agents: Subagent[], width: number): string[] {
		const theme = this.theme;
		if (agents.length === 0) return [theme.fg("muted", "No subagents. Ask the agent to spawn one.")];
		const snaps = agents.map(snapshot);
		const labelWidth = Math.min(24, Math.max(...snaps.map((a) => visibleWidth(a.label))));
		const lines = snaps.map((snap, index) => {
			const marker = index === this.selected ? theme.fg("accent", "› ") : "  ";
			return marker + agentRow(snap, theme, width - 2, this.controller.frame(), labelWidth);
		});
		const selected = snaps[this.selected];
		if (selected) {
			lines.push("", theme.fg("dim", "─".repeat(width)));
			const remaining = Math.max(4, this.height() - lines.length - 3);
			const preview = [
				...wrap(`${theme.fg("muted", "Task: ")}${selected.task}`, width).slice(0, 4),
				theme.fg("muted", `Model: ${selected.model ?? "default"} · ${formatUsage(selected.usage) || "no usage yet"}`),
			];
			const output = selected.output ?? (selected.status === "running" ? undefined : selected.error);
			if (output) {
				preview.push("", ...wrap(theme.fg("toolOutput", output.trim()), width));
			}
			lines.push(...preview.slice(0, remaining));
		}
		return lines;
	}

	private renderDetail(agent: Subagent, width: number): string[] {
		const theme = this.theme;
		const snap = snapshot(agent);
		const header = [
			agentRow(snap, theme, width, this.controller.frame()),
			...wrap(theme.fg("dim", `cwd: ${agent.cwd}`), width),
			theme.fg("dim", "─".repeat(width)),
		];
		const transcript = this.transcriptLines(agent, width);
		const viewport = Math.max(3, this.height() - header.length - 2);
		const maxScroll = Math.max(0, transcript.length - viewport);
		if (this.followEnd) this.scroll = maxScroll;
		this.scroll = Math.max(0, Math.min(this.scroll, maxScroll));
		if (this.scroll === maxScroll) this.followEnd = true;
		const visible = transcript.slice(this.scroll, this.scroll + viewport);
		const position = transcript.length > viewport ? theme.fg("dim", `lines ${this.scroll + 1}-${this.scroll + visible.length} of ${transcript.length}`) : "";
		return [...header, ...visible, ...(position ? [position] : [])];
	}

	private transcriptLines(agent: Subagent, width: number): string[] {
		const key = `${width}:${agent.transcript.length}:${agent.status}`;
		if (this.transcriptCache?.key === key) return this.transcriptCache.lines;
		const theme = this.theme;
		const markdownTheme = getMarkdownTheme();
		const lines: string[] = [];
		for (const item of agent.transcript) {
			switch (item.kind) {
				case "user":
					lines.push("", ...wrap(theme.fg("accent", "▍ ") + theme.fg("text", item.text), width), "");
					break;
				case "assistant":
					lines.push(...new Markdown(item.text.trim(), 0, 0, markdownTheme).render(width));
					break;
				case "tool":
					lines.push(truncateToWidth(`${theme.fg("muted", "→ ")}${theme.fg("toolTitle", item.name)} ${theme.fg("dim", item.summary)}`, width));
					break;
				case "tool-error":
					lines.push(...wrap(theme.fg("error", `  ${item.name} failed: ${item.text}`), width).slice(0, 6));
					break;
				case "error":
					lines.push(...wrap(theme.fg("error", `Error: ${item.text}`), width));
					break;
			}
		}
		if (lines.length === 0) lines.push(theme.fg("muted", "(no messages yet)"));
		this.transcriptCache = { key, lines };
		return lines;
	}
}

function wrap(text: string, width: number): string[] {
	return text.split("\n").flatMap((line) => wrapTextWithAnsi(line, width));
}

/** Draw a rounded border around overlay content. */
function frame(lines: string[], width: number, theme: Theme, title: string): string[] {
	const inner = Math.max(1, width - 4);
	const border = (text: string) => theme.fg("borderAccent", text);
	const titleText = ` ${theme.bold(title)} `;
	const top = border("╭─") + theme.fg("accent", titleText) + border(`${"─".repeat(Math.max(0, width - 3 - visibleWidth(titleText)))}╮`);
	const out = [top];
	for (const line of lines) {
		const clipped = truncateToWidth(line, inner);
		out.push(`${border("│")} ${clipped}${" ".repeat(Math.max(0, inner - visibleWidth(clipped)))} ${border("│")}`);
	}
	out.push(border(`╰${"─".repeat(Math.max(0, width - 2))}╯`));
	return out;
}
