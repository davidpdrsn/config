/**
 * Subagents: lets the agent spawn other pi agents, talk to them, and collect their results.
 *
 * Each subagent is a separate `pi --mode rpc --no-session` process with its own context window,
 * optionally on a different model. Subagents run in the background. A widget above the editor
 * lists them with their status, and `/agents` opens a manager with each agent's transcript.
 *
 * When a run finishes and no `subagent_wait` call is waiting on it, the result is sent to the
 * parent as a message that starts a turn (or steers the current one).
 *
 * Subagents load the same extensions, but this one does not register its tools inside them,
 * so they cannot spawn agents of their own. Set PI_SUBAGENT_MAX_DEPTH to allow deeper nesting.
 */
import { existsSync, statSync } from "node:fs";
import path from "node:path";
import type { ExtensionAPI, ExtensionContext, ToolResultEvent } from "@earendil-works/pi-coding-agent";
import { Text, type TUI } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import {
	addUsage,
	emptyUsage,
	oneLine,
	Subagent,
	THINKING_LEVELS,
	type ThinkingLevel,
	type UiRequest,
	type UiResponse,
	type UsageTotals,
} from "./agent";
import {
	type AgentSnapshot,
	AgentsOverlay,
	createWidget,
	formatDuration,
	formatUsage,
	type OverlayAction,
	renderAgentResults,
	renderResultMessage,
	snapshot,
} from "./ui";

const DEPTH = Number(process.env.PI_SUBAGENT_DEPTH || 0);
const MAX_DEPTH = Number(process.env.PI_SUBAGENT_MAX_DEPTH || 1);
const MAX_OUTPUT_CHARS = 50_000;
const RESULT_MESSAGE_TYPE = "subagent-result";
const WIDGET_KEY = "subagents";

interface ResultDetails {
	agents: AgentSnapshot[];
}

function stringEnum<T extends readonly string[]>(values: T, description: string) {
	return Type.Unsafe<T[number]>({ type: "string", enum: [...values], description });
}

const SpawnParams = Type.Object({
	task: Type.String({
		description:
			"Complete instructions for the subagent. It cannot see this conversation, so include all context it needs and say what it should report back.",
	}),
	name: Type.Optional(Type.String({ description: "Short label shown in the UI, such as 'auth-scout'" })),
	model: Type.Optional(
		Type.String({
			description:
				"Model for the subagent: 'provider/id', a bare id, or a fuzzy pattern such as 'haiku' or 'sonnet'. Append ':<thinking>' to set the thinking level. Defaults to your current model.",
		}),
	),
	thinking: Type.Optional(stringEnum(THINKING_LEVELS, "Thinking level. Defaults to yours when the model is inherited.")),
	tools: Type.Optional(
		Type.Array(Type.String(), { description: "Allowlist of tool names for the subagent, such as ['read', 'bash']. Defaults to the normal tool set." }),
	),
	system_prompt: Type.Optional(Type.String({ description: "Extra text appended to the subagent's system prompt" })),
	cwd: Type.Optional(Type.String({ description: "Working directory, relative to yours. Defaults to your working directory." })),
	wait: Type.Optional(
		Type.Boolean({ description: "Block until the subagent finishes and return its result. Default false: it runs in the background." }),
	),
});

const WaitParams = Type.Object({
	ids: Type.Optional(
		Type.Array(Type.String(), {
			description: "Agent ids or names. Defaults to every running agent and every finished agent whose result you have not seen.",
		}),
	),
	mode: Type.Optional(stringEnum(["all", "any"] as const, "Return when all agents finish (default) or when any one finishes")),
	timeout_seconds: Type.Optional(Type.Number({ description: "Give up waiting after this many seconds. The agents keep running." })),
});

const SendParams = Type.Object({
	id: Type.String({ description: "Agent id or name" }),
	message: Type.String({ description: "Message to send" }),
	delivery: Type.Optional(
		stringEnum(
			["steer", "follow_up"] as const,
			"Only used when the agent is running. 'steer' (default) interrupts after its current tool calls; 'follow_up' waits until it finishes.",
		),
	),
	wait: Type.Optional(Type.Boolean({ description: "Block until the agent finishes and return its result. Default false." })),
});

const ListParams = Type.Object({});

const StopParams = Type.Object({
	ids: Type.Array(Type.String(), { description: "Agent ids or names, or ['all']" }),
	mode: Type.Optional(
		stringEnum(["kill", "abort"] as const, "'kill' (default) ends the process. 'abort' cancels the current run and keeps the agent for follow-ups."),
	),
});

function truncate(text: string, max = MAX_OUTPUT_CHARS): string {
	if (text.length <= max) return text;
	return `${text.slice(0, max)}\n\n[Output truncated: ${text.length - max} more characters]`;
}

function preview(text: string, max: number): string {
	const line = oneLine(text);
	return line.length > max ? `${line.slice(0, max - 1)}…` : line;
}

/** Text the parent model receives about one agent. */
function describeAgent(agent: Subagent, includeOutput: boolean): string {
	const snap = snapshot(agent);
	const facts = [agent.model ?? "default model", formatDuration(snap.durationMs), formatUsage(agent.usage)].filter(Boolean);
	let text = `Subagent ${agent.label} [${agent.status}] (${facts.join(", ")})`;
	if (agent.status === "running" && agent.activity) text += `\nCurrently: ${preview(agent.activity, 200)}`;
	if (agent.error) text += `\nError: ${agent.error}`;
	if (includeOutput && !agent.isBusy) {
		text += agent.output ? `\n\n${truncate(agent.output)}` : "\n\n(no text output)";
		if (agent.alive) text += `\n\n(The agent is idle. Use subagent_send to follow up, or subagent_stop when you no longer need it.)`;
	}
	return text;
}

type Usage = NonNullable<ToolResultEvent["usage"]>;

/** Add subagent usage to a tool result's own usage. */
function withSubagentUsage(base: Usage | undefined, usage: UsageTotals): Usage {
	const cost = base?.cost ?? { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 };
	return {
		...base,
		input: (base?.input ?? 0) + usage.input,
		output: (base?.output ?? 0) + usage.output,
		cacheRead: (base?.cacheRead ?? 0) + usage.cacheRead,
		cacheWrite: (base?.cacheWrite ?? 0) + usage.cacheWrite,
		totalTokens: (base?.totalTokens ?? 0) + usage.input + usage.output + usage.cacheRead + usage.cacheWrite,
		cost: { ...cost, total: cost.total + usage.cost },
	};
}

export default function (pi: ExtensionAPI): void {
	if (DEPTH >= MAX_DEPTH) return;

	const agents = new Map<string, Subagent>();
	const listeners = new Set<() => void>();
	/** Subagent usage not yet added to a parent tool result, which is how it reaches the session totals. */
	let unreportedUsage = emptyUsage();
	let nextId = 1;
	let uiCtx: ExtensionContext | undefined;
	let widgetTui: TUI | undefined;
	let widgetInstalled = false;
	let spinner: ReturnType<typeof setInterval> | undefined;
	let frame = 0;

	function subscribe(listener: () => void): () => void {
		listeners.add(listener);
		return () => listeners.delete(listener);
	}

	function notify(): void {
		for (const listener of [...listeners]) listener();
	}

	/** Agents worth showing in the widget: live processes, plus dead ones whose result the parent has not seen. */
	function visibleAgents(): Subagent[] {
		return [...agents.values()].filter((agent) => agent.alive || agent.hasUndeliveredResult);
	}

	function updateUi(): void {
		const anyRunning = [...agents.values()].some((agent) => agent.isBusy);
		if (anyRunning && !spinner) {
			spinner = setInterval(() => {
				frame++;
				widgetTui?.requestRender();
				notify();
			}, 120);
			spinner.unref?.();
		} else if (!anyRunning && spinner) {
			clearInterval(spinner);
			spinner = undefined;
		}

		const ctx = uiCtx;
		if (!ctx || ctx.mode !== "tui") return;
		const visible = visibleAgents().length > 0;
		if (visible && !widgetInstalled) {
			widgetInstalled = true;
			ctx.ui.setWidget(WIDGET_KEY, (tui, theme) => {
				widgetTui = tui;
				return createWidget({ agents: () => visibleAgents().map(snapshot), frame: () => frame }, theme);
			}, { placement: "belowEditor" });
		} else if (!visible && widgetInstalled) {
			widgetInstalled = false;
			widgetTui = undefined;
			ctx.ui.setWidget(WIDGET_KEY, undefined);
		} else {
			widgetTui?.requestRender();
		}
	}

	function onChange(): void {
		notify();
		updateUi();
	}

	function find(ref: string): Subagent {
		const byId = agents.get(ref);
		if (byId) return byId;
		const lower = ref.toLowerCase();
		const byName = [...agents.values()].filter((agent) => agent.name.toLowerCase() === lower);
		if (byName.length === 1) return byName[0];
		const known = [...agents.values()].map((agent) => agent.label).join(", ") || "none";
		if (byName.length > 1) throw new Error(`Several agents are named "${ref}". Use an id. Agents: ${known}`);
		throw new Error(`No subagent "${ref}". Agents: ${known}`);
	}

	function markDelivered(targets: Iterable<Subagent>): void {
		for (const agent of targets) if (!agent.isBusy) agent.deliveredRuns = agent.finishedRuns;
		updateUi();
	}

	/**
	 * Results waiting to be sent to the parent. While the parent is busy, results are held until its
	 * current turn ends. Any subagent_wait call in that turn has returned by then and marked the
	 * results it returned as delivered, so the parent does not see the same result twice.
	 */
	const pendingDelivery = new Set<Subagent>();

	function queueDelivery(agent: Subagent): void {
		pendingDelivery.add(agent);
		if (uiCtx?.isIdle() ?? true) flushDeliveries();
	}

	/** Send finished results to the parent unless a subagent_wait call has already returned them. */
	function flushDeliveries(): void {
		for (const agent of [...pendingDelivery]) {
			pendingDelivery.delete(agent);
			if (!agent.hasUndeliveredResult || agent.status === "stopped") continue;
			agent.deliveredRuns = agent.finishedRuns;
			void pi.sendMessage<AgentSnapshot>(
				{ customType: RESULT_MESSAGE_TYPE, content: describeAgent(agent, true), display: true, details: snapshot(agent) },
				{ triggerTurn: true, deliverAs: "steer" },
			);
		}
		updateUi();
	}

	async function forwardDialog(agent: Subagent, request: UiRequest): Promise<UiResponse> {
		const ctx = uiCtx;
		if (!ctx?.hasUI) return { cancelled: true };
		const title = `Subagent ${agent.label}: ${request.title ?? ""}`;
		switch (request.method) {
			case "select": {
				const value = await ctx.ui.select(title, request.options ?? []);
				return value === undefined ? { cancelled: true } : { value };
			}
			case "confirm":
				return { confirmed: await ctx.ui.confirm(title, request.message ?? "") };
			case "input": {
				const value = await ctx.ui.input(title, request.placeholder);
				return value === undefined ? { cancelled: true } : { value };
			}
			case "editor": {
				const value = await ctx.ui.editor(title, request.prefill);
				return value === undefined ? { cancelled: true } : { value };
			}
			default:
				return { cancelled: true };
		}
	}

	function resolveModel(pattern: string, ctx: ExtensionContext): { ref: string; thinking?: ThinkingLevel } {
		let base = pattern.trim();
		let thinking: ThinkingLevel | undefined;
		const colon = base.lastIndexOf(":");
		if (colon > 0 && (THINKING_LEVELS as readonly string[]).includes(base.slice(colon + 1))) {
			thinking = base.slice(colon + 1) as ThinkingLevel;
			base = base.slice(0, colon);
		}
		const available = ctx.modelRegistry.getAvailable();
		const ref = (model: { provider: string; id: string }) => `${model.provider}/${model.id}`;
		const lower = base.toLowerCase();
		const listing = () => available.map(ref).join(", ");

		const exact = available.filter((model) => ref(model).toLowerCase() === lower || model.id.toLowerCase() === lower);
		if (exact.length === 1) return { ref: ref(exact[0]), thinking };
		if (exact.length > 1) {
			throw new Error(`Model "${pattern}" exists for several providers: ${exact.map(ref).join(", ")}. Use provider/id.`);
		}

		let matches = available.filter(
			(model) => ref(model).toLowerCase().includes(lower) || model.name?.toLowerCase().includes(lower),
		);
		if (matches.length === 0) throw new Error(`No available model matches "${pattern}". Available models: ${listing()}`);
		// Prefer models the user enabled for cycling, then undated aliases, then the highest version.
		const scoped = new Set(ctx.scopedModels.map((scopedModel) => ref(scopedModel.model)));
		const inScope = matches.filter((model) => scoped.has(ref(model)));
		if (inScope.length > 0) matches = inScope;
		const aliases = matches.filter((model) => !/-\d{8}$/.test(model.id));
		const pool = aliases.length > 0 ? aliases : matches;
		pool.sort((a, b) => b.id.localeCompare(a.id, undefined, { numeric: true }));
		return { ref: ref(pool[0]), thinking };
	}

	/**
	 * Wait until all (or any) of the targets stop running. Finished targets are marked as delivered,
	 * because the caller returns their results.
	 */
	async function waitFor(
		targets: Subagent[],
		mode: "all" | "any",
		signal: AbortSignal | undefined,
		timeoutMs: number | undefined,
		onTick?: () => void,
	): Promise<"settled" | "timeout" | "aborted"> {
		const settled = () => (mode === "all" ? targets.every((a) => !a.isBusy) : targets.some((a) => !a.isBusy));
		try {
			if (settled()) return "settled";
			return await new Promise((resolve) => {
				let timer: ReturnType<typeof setTimeout> | undefined;
				let lastTick = 0;
				const finish = (outcome: "settled" | "timeout" | "aborted") => {
					unsubscribe();
					if (timer) clearTimeout(timer);
					signal?.removeEventListener("abort", onAbort);
					resolve(outcome);
				};
				const onAbort = () => finish("aborted");
				const unsubscribe = subscribe(() => {
					if (settled()) return finish("settled");
					const now = Date.now();
					if (onTick && now - lastTick > 250) {
						lastTick = now;
						onTick();
					}
				});
				if (timeoutMs && timeoutMs > 0) timer = setTimeout(() => finish("timeout"), timeoutMs);
				if (signal?.aborted) return finish("aborted");
				signal?.addEventListener("abort", onAbort, { once: true });
			});
		} finally {
			markDelivered(targets);
		}
	}

	function results(targets: Subagent[], intro?: string) {
		const body = targets.map((agent) => describeAgent(agent, true)).join("\n\n---\n\n");
		return {
			content: [{ type: "text" as const, text: intro ? `${intro}\n\n${body}` : body }],
			details: { agents: targets.map(snapshot) } satisfies ResultDetails,
		};
	}

	function progress(targets: Subagent[]) {
		const done = targets.filter((agent) => !agent.isBusy).length;
		return {
			content: [{ type: "text" as const, text: `${done}/${targets.length} subagents finished` }],
			details: { agents: targets.map(snapshot) } satisfies ResultDetails,
		};
	}

	async function stopAll(): Promise<void> {
		await Promise.all([...agents.values()].map((agent) => agent.stop()));
	}

	function renderDetailsResult(result: { content: { type: string; text?: string }[]; details?: unknown }, expanded: boolean, showOutput: boolean, theme: any) {
		const details = result.details as ResultDetails | undefined;
		if (!details?.agents?.length) {
			const first = result.content[0];
			return new Text(first?.type === "text" ? (first.text ?? "") : "", 0, 0);
		}
		return renderAgentResults(details.agents, { expanded, showOutput }, theme);
	}

	function renderCallLine(title: string, theme: any, extra: string, body?: string) {
		let text = theme.fg("toolTitle", theme.bold(title)) + (extra ? ` ${extra}` : "");
		if (body) text += `\n${theme.fg("dim", preview(body, 160))}`;
		return new Text(text, 0, 0);
	}

	pi.registerTool<typeof SpawnParams, ResultDetails>({
		name: "subagent_spawn",
		label: "Spawn subagent",
		description:
			"Start a subagent: a separate pi agent with its own context window, optionally on a different model. It runs in the background and its result is delivered to you as a message when it finishes, unless you collect it first with subagent_wait. Set wait: true to block until it finishes instead.",
		promptSnippet: "Spawn background subagents with their own context, optionally on other models",
		promptGuidelines: [
			"Use subagent_spawn to delegate self-contained work to subagents, and run several in parallel when tasks are independent. A subagent cannot see this conversation, so give it the full context and say what to report back.",
			"When the user names a model for a subagent, pass it as `model` (for example 'haiku', 'sonnet', 'anthropic/claude-opus-4-8', 'gpt-6-sol').",
			"Subagent results arrive as messages when they finish. Call subagent_wait when you need results before continuing. Stop idle subagents with subagent_stop when you no longer need them.",
		],
		parameters: SpawnParams,
		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			let model: string | undefined;
			let thinking = params.thinking;
			if (params.model) {
				const resolved = resolveModel(params.model, ctx);
				model = resolved.ref;
				thinking ??= resolved.thinking;
			} else if (ctx.model) {
				model = `${ctx.model.provider}/${ctx.model.id}`;
				thinking ??= pi.getThinkingLevel() as ThinkingLevel;
			}

			const cwd = path.resolve(ctx.cwd, params.cwd ?? ".");
			if (!existsSync(cwd) || !statSync(cwd).isDirectory()) throw new Error(`Working directory does not exist: ${cwd}`);

			const id = `a${nextId++}`;
			const name = params.name ? preview(params.name, 32) : id;
			const agent = new Subagent({
				id,
				name,
				task: params.task,
				cwd,
				model,
				thinking,
				tools: params.tools,
				systemPrompt: params.system_prompt,
				depth: DEPTH + 1,
				onChange,
				onRunFinished: queueDelivery,
				onUsage: (usage) => addUsage(unreportedUsage, usage),
				onUiRequest: forwardDialog,
			});
			agents.set(id, agent);
			onChange();

			try {
				await agent.start();
			} catch (error) {
				agent.deliveredRuns = agent.finishedRuns;
				await agent.stop();
				agents.delete(id);
				onChange();
				throw new Error(`Subagent ${agent.label} failed to start: ${error instanceof Error ? error.message : String(error)}`);
			}

			if (!params.wait) {
				return {
					content: [
						{
							type: "text",
							text: `Started subagent ${agent.label} on ${agent.model ?? "the default model"}${agent.thinking ? ` (thinking ${agent.thinking})` : ""}. It runs in the background. Its result will arrive as a message when it finishes, or call subagent_wait to block on it.`,
						},
					],
					// No snapshot: a "starting" row would sit frozen in the transcript. The widget shows live status.
					details: { agents: [] },
				};
			}

			const outcome = await waitFor([agent], "all", signal, undefined, () => onUpdate?.(progress([agent])));
			const intro = outcome === "aborted" ? "Stopped waiting. The subagent keeps running in the background." : undefined;
			return results([agent], intro);
		},
		renderCall(args, theme) {
			const extra = [args.name ? theme.fg("accent", args.name) : "", args.model ? theme.fg("muted", args.model) : "", args.wait ? theme.fg("dim", "(wait)") : ""]
				.filter(Boolean)
				.join(" ");
			return renderCallLine("subagent_spawn", theme, extra, args.task);
		},
		renderResult(result, { expanded, isPartial }, theme) {
			return renderDetailsResult(result, expanded, !isPartial, theme);
		},
	});

	pi.registerTool<typeof WaitParams, ResultDetails>({
		name: "subagent_wait",
		label: "Wait for subagents",
		description:
			"Block until subagents finish and return their results. Without ids it waits for every running subagent and also returns finished results you have not seen yet. Agents keep running if the wait times out or is interrupted.",
		promptSnippet: "Wait for subagents to finish and collect their results",
		parameters: WaitParams,
		async execute(_toolCallId, params, signal, onUpdate) {
			const targets = params.ids?.length
				? params.ids.map(find)
				: [...agents.values()].filter((agent) => agent.isBusy || agent.hasUndeliveredResult);
			if (targets.length === 0) {
				return { content: [{ type: "text", text: "No running subagents and no unseen results." }], details: { agents: [] } };
			}
			const timeoutMs = params.timeout_seconds ? params.timeout_seconds * 1000 : undefined;
			const outcome = await waitFor(targets, params.mode ?? "all", signal, timeoutMs, () => onUpdate?.(progress(targets)));
			const intro =
				outcome === "timeout"
					? "Timed out. Unfinished subagents keep running."
					: outcome === "aborted"
						? "Stopped waiting. Unfinished subagents keep running."
						: undefined;
			return results(targets, intro);
		},
		renderCall(args, theme) {
			const extra = theme.fg("accent", args.ids?.join(", ") ?? "all") + (args.mode === "any" ? theme.fg("dim", " (any)") : "");
			return renderCallLine("subagent_wait", theme, extra);
		},
		renderResult(result, { expanded, isPartial }, theme) {
			return renderDetailsResult(result, expanded, !isPartial, theme);
		},
	});

	pi.registerTool<typeof SendParams, ResultDetails>({
		name: "subagent_send",
		label: "Message subagent",
		description:
			"Send a message to a subagent. An idle agent starts a new run with the message and keeps its earlier context. A running agent gets it as a steering message (default) or a follow-up.",
		promptSnippet: "Send follow-up instructions to a subagent",
		parameters: SendParams,
		async execute(_toolCallId, params, signal, onUpdate) {
			const agent = find(params.id);
			await agent.send(params.message, params.delivery);
			if (!params.wait) {
				return {
					content: [{ type: "text", text: `Sent to subagent ${agent.label}. Its result will arrive as a message when it finishes.` }],
					details: { agents: [] },
				};
			}
			const outcome = await waitFor([agent], "all", signal, undefined, () => onUpdate?.(progress([agent])));
			return results([agent], outcome === "aborted" ? "Stopped waiting. The subagent keeps running." : undefined);
		},
		renderCall(args, theme) {
			return renderCallLine("subagent_send", theme, theme.fg("accent", args.id), args.message);
		},
		renderResult(result, { expanded, isPartial }, theme) {
			return renderDetailsResult(result, expanded, !isPartial, theme);
		},
	});

	pi.registerTool<typeof ListParams, ResultDetails>({
		name: "subagent_list",
		label: "List subagents",
		description: "List subagents with their status, model, current activity, and a preview of their last output.",
		promptSnippet: "List subagents and their status",
		parameters: ListParams,
		async execute() {
			const all = [...agents.values()];
			if (all.length === 0) return { content: [{ type: "text", text: "No subagents." }], details: { agents: [] } };
			const text = all
				.map((agent) => {
					let line = describeAgent(agent, false);
					line += `\nTask: ${preview(agent.task, 300)}`;
					if (agent.output && !agent.isBusy) line += `\nLast output: ${preview(agent.output, 300)}`;
					return line;
				})
				.join("\n\n");
			return { content: [{ type: "text", text }], details: { agents: all.map(snapshot) } };
		},
		renderCall(_args, theme) {
			return renderCallLine("subagent_list", theme, "");
		},
		renderResult(result, { expanded }, theme) {
			return renderDetailsResult(result, expanded, false, theme);
		},
	});

	pi.registerTool<typeof StopParams, ResultDetails>({
		name: "subagent_stop",
		label: "Stop subagents",
		description: "Kill subagent processes, or abort their current run and keep them for follow-ups.",
		promptSnippet: "Stop or abort subagents",
		parameters: StopParams,
		async execute(_toolCallId, params) {
			const targets = params.ids.some((ref) => ref === "all") ? [...agents.values()] : params.ids.map(find);
			if (params.mode === "abort") {
				await Promise.all(targets.filter((agent) => agent.isBusy).map((agent) => agent.abort()));
			} else {
				await Promise.all(targets.map((agent) => agent.stop()));
			}
			markDelivered(targets);
			const verb = params.mode === "abort" ? "Aborted" : "Stopped";
			return {
				content: [{ type: "text", text: `${verb}: ${targets.map((agent) => agent.label).join(", ") || "none"}` }],
				details: { agents: targets.map(snapshot) },
			};
		},
		renderCall(args, theme) {
			return renderCallLine("subagent_stop", theme, theme.fg("accent", args.ids.join(", ")) + (args.mode === "abort" ? theme.fg("dim", " (abort)") : ""));
		},
		renderResult(result, { expanded }, theme) {
			return renderDetailsResult(result, expanded, false, theme);
		},
	});

	pi.registerMessageRenderer<AgentSnapshot>(RESULT_MESSAGE_TYPE, (message, { expanded, outputPad }, theme) => {
		if (!message.details) return undefined;
		return renderResultMessage(message.details, expanded, outputPad, theme);
	});

	pi.registerCommand("agents", {
		description: "Show subagents: status, transcripts, and controls",
		handler: async (_args, ctx) => {
			if (ctx.mode !== "tui") {
				const all = [...agents.values()];
				ctx.ui.notify(all.length ? all.map((agent) => describeAgent(agent, false)).join("\n") : "No subagents.", "info");
				return;
			}
			let selectedId: string | undefined;
			while (true) {
				const action = await ctx.ui.custom<OverlayAction>(
					(tui, theme, keybindings, done) =>
						new AgentsOverlay(
							tui,
							theme,
							keybindings,
							{
								agents: () => [...agents.values()],
								frame: () => frame,
								stop: (id) => void agents.get(id)?.stop(),
								stopAll: () => void stopAll(),
								abort: (id) => void agents.get(id)?.abort().catch(() => {}),
								subscribe,
							},
							done,
							selectedId,
						),
					{ overlay: true, overlayOptions: { anchor: "center", width: "90%", maxHeight: "90%" } },
				);
				if (!action || action.type === "close") return;
				selectedId = action.id;
				const agent = agents.get(action.id);
				if (!agent?.alive) {
					ctx.ui.notify(`Subagent ${agent?.label ?? action.id} is not running`, "warning");
					continue;
				}
				const message = await ctx.ui.input(`Message to subagent ${agent.label}`, agent.isBusy ? "steers the current run" : "starts a new run");
				if (!message?.trim()) continue;
				try {
					await agent.send(message);
				} catch (error) {
					ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
				}
			}
		},
	});

	// Extensions cannot add usage entries to the session, so subagent usage is added to the parent's
	// next tool result. Usage from a turn without tool calls is reported on the next tool call.
	pi.on("tool_result", (event) => {
		if (!unreportedUsage.turns) return;
		const usage = withSubagentUsage(event.usage, unreportedUsage);
		unreportedUsage = emptyUsage();
		return { usage };
	});

	pi.on("turn_end", () => flushDeliveries());
	pi.on("agent_settled", () => flushDeliveries());

	pi.on("session_start", (_event, ctx) => {
		uiCtx = ctx;
		widgetInstalled = false;
		updateUi();
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		await stopAll();
		agents.clear();
		pendingDelivery.clear();
		unreportedUsage = emptyUsage();
		listeners.clear();
		if (spinner) clearInterval(spinner);
		spinner = undefined;
		if (widgetInstalled && ctx.mode === "tui") ctx.ui.setWidget(WIDGET_KEY, undefined);
		widgetInstalled = false;
		widgetTui = undefined;
		uiCtx = undefined;
	});
}
