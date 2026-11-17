import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";

/**
 * One subagent: a `pi --mode rpc` child process plus the state the parent tracks about it.
 *
 * Status meanings:
 * - starting: the process is booting and has not accepted its first prompt yet.
 * - running:  a prompt was accepted and the child has not emitted `agent_settled`.
 * - done:     the last run finished normally. The process stays alive for follow-ups.
 * - failed:   the last run ended with a model error, or the process died.
 * - aborted:  the last run was aborted. The process stays alive for follow-ups.
 * - stopped:  the parent killed the process on purpose.
 */
export type AgentStatus = "starting" | "running" | "done" | "failed" | "aborted" | "stopped";

export const THINKING_LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;
export type ThinkingLevel = (typeof THINKING_LEVELS)[number];

export interface UsageTotals {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	turns: number;
}

export type TranscriptItem =
	| { kind: "user"; text: string }
	| { kind: "assistant"; text: string }
	| { kind: "tool"; name: string; summary: string }
	| { kind: "tool-error"; name: string; text: string }
	| { kind: "error"; text: string };

export interface UiRequest {
	id: string;
	method: string;
	title?: string;
	message?: string;
	options?: string[];
	placeholder?: string;
	prefill?: string;
}

export type UiResponse = { value: string } | { confirmed: boolean } | { cancelled: true };

export interface SubagentOptions {
	id: string;
	name: string;
	task: string;
	cwd: string;
	model?: string;
	thinking?: ThinkingLevel;
	tools?: string[];
	systemPrompt?: string;
	depth: number;
	onChange: (agent: Subagent) => void;
	onRunFinished: (agent: Subagent) => void;
	onUiRequest: (agent: Subagent, request: UiRequest) => Promise<UiResponse>;
}

interface PendingRequest {
	resolve: (data: unknown) => void;
	reject: (error: Error) => void;
}

const MAX_TRANSCRIPT_ITEMS = 400;
const MAX_STDERR = 8 * 1024;
const DIALOG_METHODS = new Set(["select", "confirm", "input", "editor"]);

function emptyUsage(): UsageTotals {
	return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, turns: 0 };
}

/** Run the same pi binary as the parent so the child matches its version and configuration. */
function piInvocation(args: string[]): { command: string; args: string[] } {
	const script = process.argv[1];
	const isBunVirtualScript = script?.startsWith("/$bunfs/root/");
	if (script && !isBunVirtualScript && existsSync(script)) {
		return { command: process.execPath, args: [script, ...args] };
	}
	const execName = path.basename(process.execPath).toLowerCase();
	if (!/^(node|bun)(\.exe)?$/.test(execName)) return { command: process.execPath, args };
	return { command: "pi", args };
}

function textOf(content: unknown): string {
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";
	return content
		.filter((part): part is { type: "text"; text: string } => part?.type === "text" && typeof part.text === "string")
		.map((part) => part.text)
		.join("\n");
}

export function summarizeToolCall(name: string, args: Record<string, unknown> | undefined): string {
	const a = args ?? {};
	const pick = (...keys: string[]) => {
		for (const key of keys) if (typeof a[key] === "string" && a[key]) return a[key] as string;
		return undefined;
	};
	const detail =
		name === "bash"
			? pick("command")
			: name === "codemode"
				? pick("code")
				: pick("path", "file_path", "pattern", "query", "url", "command") ?? JSON.stringify(a);
	return detail ? detail.replace(/\s+/g, " ").trim() : "";
}

export class Subagent {
	readonly id: string;
	readonly name: string;
	readonly cwd: string;
	readonly createdAt = Date.now();
	readonly requestedModel?: string;
	readonly requestedThinking?: ThinkingLevel;

	/** The most recent prompt sent to the agent. */
	task: string;
	status: AgentStatus = "starting";
	model?: string;
	thinking?: string;
	/** What the agent is doing right now, for the status widget. */
	activity?: string;
	usage: UsageTotals = emptyUsage();
	transcript: TranscriptItem[] = [];
	/** Final assistant text of the last finished run. */
	output?: string;
	error?: string;
	runStartedAt?: number;
	finishedAt?: number;
	/** Number of runs that have finished. Compared against `deliveredRuns` to know whether the parent has seen the result. */
	finishedRuns = 0;
	deliveredRuns = 0;
	stderr = "";
	alive = false;

	private readonly options: SubagentOptions;
	private proc?: ChildProcessWithoutNullStreams;
	private buffer = "";
	private nextRequestId = 0;
	private readonly pending = new Map<string, PendingRequest>();
	private lastAssistantText?: string;
	private lastStopReason?: string;
	private lastErrorMessage?: string;
	private exitPromise?: Promise<void>;
	private reportedUsage: UsageTotals = emptyUsage();

	constructor(options: SubagentOptions) {
		this.options = options;
		this.id = options.id;
		this.name = options.name;
		this.cwd = options.cwd;
		this.task = options.task;
		this.requestedModel = options.model;
		this.requestedThinking = options.thinking;
	}

	get label(): string {
		return this.name === this.id ? this.id : `${this.id} ${this.name}`;
	}

	get isBusy(): boolean {
		return this.status === "starting" || this.status === "running";
	}

	get hasUndeliveredResult(): boolean {
		return this.finishedRuns > this.deliveredRuns;
	}

	/** Usage accumulated since the last call, for reporting on the parent's tool results. */
	takeUsageDelta(): UsageTotals {
		const delta: UsageTotals = {
			input: this.usage.input - this.reportedUsage.input,
			output: this.usage.output - this.reportedUsage.output,
			cacheRead: this.usage.cacheRead - this.reportedUsage.cacheRead,
			cacheWrite: this.usage.cacheWrite - this.reportedUsage.cacheWrite,
			cost: this.usage.cost - this.reportedUsage.cost,
			turns: this.usage.turns - this.reportedUsage.turns,
		};
		this.reportedUsage = { ...this.usage };
		return delta;
	}

	/** Spawn the process, wait until it answers RPC, then send the task. */
	async start(): Promise<void> {
		const args = ["--mode", "rpc", "--no-session"];
		if (this.options.model) args.push("--model", this.options.model);
		if (this.options.thinking) args.push("--thinking", this.options.thinking);
		if (this.options.tools?.length) args.push("--tools", this.options.tools.join(","));
		if (this.options.systemPrompt?.trim()) args.push("--append-system-prompt", this.options.systemPrompt);

		const invocation = piInvocation(args);
		const proc = spawn(invocation.command, invocation.args, {
			cwd: this.cwd,
			stdio: ["pipe", "pipe", "pipe"],
			env: {
				...process.env,
				PI_SUBAGENT_DEPTH: String(this.options.depth),
				PI_SUBAGENT_ID: this.id,
			},
		});
		this.proc = proc;
		this.alive = true;

		proc.stdout.setEncoding("utf8");
		proc.stdout.on("data", (chunk: string) => this.onStdout(chunk));
		proc.stderr.setEncoding("utf8");
		proc.stderr.on("data", (chunk: string) => {
			this.stderr = (this.stderr + chunk).slice(-MAX_STDERR);
		});
		proc.stdin.on("error", () => {});
		this.exitPromise = new Promise<void>((resolve) => {
			proc.on("error", (error) => {
				this.stderr += `\n${error.message}`;
				this.onExit(null);
				resolve();
			});
			proc.on("exit", (code) => {
				this.onExit(code);
				resolve();
			});
		});

		const state = (await this.request({ type: "get_state" })) as {
			model?: { provider: string; id: string };
			thinkingLevel?: string;
		};
		if (state?.model) this.model = `${state.model.provider}/${state.model.id}`;
		this.thinking = state?.thinkingLevel;
		this.options.onChange(this);
		await this.prompt(this.task);
	}

	/** Start a new run. Only valid while the agent is not running. */
	async prompt(message: string): Promise<void> {
		this.task = message;
		this.beginRun();
		try {
			const data = (await this.request({ type: "prompt", message })) as { disposition?: string } | undefined;
			// "handled" means an extension command consumed the prompt and no run started.
			if (data?.disposition === "handled") this.finishRun();
		} catch (error) {
			this.status = "failed";
			this.error = error instanceof Error ? error.message : String(error);
			this.activity = undefined;
			this.options.onChange(this);
			throw error;
		}
	}

	/** Queue a message for a running agent. */
	async queue(message: string, delivery: "steer" | "follow_up"): Promise<void> {
		this.transcript.push({ kind: "user", text: `(${delivery === "steer" ? "steer" : "follow-up"}) ${message}` });
		await this.request({ type: delivery, message });
	}

	async abort(): Promise<void> {
		if (!this.alive) return;
		await this.request({ type: "abort" });
	}

	/** Kill the process. Closing stdin asks pi to shut down cleanly; signals follow if it does not. */
	async stop(): Promise<void> {
		if (this.status !== "failed" || this.alive) this.status = "stopped";
		this.activity = undefined;
		this.finishedAt ??= Date.now();
		const proc = this.proc;
		if (proc && this.alive) {
			proc.stdin.end();
			const term = setTimeout(() => proc.kill("SIGTERM"), 2_000);
			const kill = setTimeout(() => proc.kill("SIGKILL"), 5_000);
			await this.exitPromise;
			clearTimeout(term);
			clearTimeout(kill);
		}
		this.options.onChange(this);
	}

	private beginRun(): void {
		this.status = "running";
		this.error = undefined;
		this.output = undefined;
		this.activity = "starting";
		this.runStartedAt = Date.now();
		this.finishedAt = undefined;
		this.lastAssistantText = undefined;
		this.lastStopReason = undefined;
		this.lastErrorMessage = undefined;
		this.options.onChange(this);
	}

	private finishRun(aborted = false): void {
		this.finishedAt = Date.now();
		this.activity = undefined;
		this.output = this.lastAssistantText;
		if (this.lastStopReason === "error") {
			this.status = "failed";
			this.error = this.lastErrorMessage || "model error";
		} else if (aborted || this.lastStopReason === "aborted") {
			this.status = "aborted";
		} else {
			this.status = "done";
		}
		this.finishedRuns++;
		this.options.onChange(this);
		this.options.onRunFinished(this);
	}

	private request(command: Record<string, unknown>): Promise<unknown> {
		const proc = this.proc;
		if (!proc || !this.alive) return Promise.reject(new Error(`Subagent ${this.label} is not running`));
		const id = `req-${++this.nextRequestId}`;
		return new Promise((resolve, reject) => {
			this.pending.set(id, { resolve, reject });
			proc.stdin.write(`${JSON.stringify({ ...command, id })}\n`);
		});
	}

	private onStdout(chunk: string): void {
		this.buffer += chunk;
		let newline = this.buffer.indexOf("\n");
		while (newline !== -1) {
			const line = this.buffer.slice(0, newline).replace(/\r$/, "");
			this.buffer = this.buffer.slice(newline + 1);
			if (line.trim()) this.onRecord(line);
			newline = this.buffer.indexOf("\n");
		}
	}

	private onRecord(line: string): void {
		let record: any;
		try {
			record = JSON.parse(line);
		} catch {
			return;
		}

		switch (record.type) {
			case "response": {
				const pending = record.id ? this.pending.get(record.id) : undefined;
				if (!pending) return;
				this.pending.delete(record.id);
				if (record.success) pending.resolve(record.data);
				else pending.reject(new Error(record.error || `${record.command} failed`));
				return;
			}
			case "extension_ui_request":
				void this.onUiRequest(record as UiRequest);
				return;
			case "message_start":
				if (record.message?.role === "assistant") {
					this.activity = "thinking";
					this.options.onChange(this);
				}
				return;
			case "message_end":
				this.onMessage(record.message);
				return;
			case "tool_execution_start":
				this.activity = `${record.toolName} ${summarizeToolCall(record.toolName, record.args)}`.trim();
				this.options.onChange(this);
				return;
			case "tool_execution_end":
				if (record.isError) {
					this.push({ kind: "tool-error", name: record.toolName, text: textOf(record.result?.content).slice(0, 2_000) });
				}
				return;
			case "auto_retry_start":
				this.activity = `retrying (${record.attempt}/${record.maxAttempts}): ${record.errorMessage ?? ""}`;
				this.options.onChange(this);
				return;
			case "compaction_start":
				this.activity = "compacting context";
				this.options.onChange(this);
				return;
			case "agent_settled":
				if (this.status === "running") this.finishRun(Boolean(record.aborted));
				return;
		}
	}

	private onMessage(message: any): void {
		if (!message) return;
		if (message.role === "user") {
			this.push({ kind: "user", text: textOf(message.content) });
		} else if (message.role === "assistant") {
			const text = textOf(message.content);
			if (text.trim()) {
				this.push({ kind: "assistant", text });
				this.lastAssistantText = text;
			}
			for (const part of message.content ?? []) {
				if (part?.type === "toolCall") {
					this.push({ kind: "tool", name: part.name, summary: summarizeToolCall(part.name, part.arguments) });
				}
			}
			const usage = message.usage;
			if (usage) {
				this.usage.input += usage.input || 0;
				this.usage.output += usage.output || 0;
				this.usage.cacheRead += usage.cacheRead || 0;
				this.usage.cacheWrite += usage.cacheWrite || 0;
				this.usage.cost += usage.cost?.total || 0;
			}
			this.usage.turns++;
			if (message.provider && message.model) this.model = `${message.provider}/${message.model}`;
			this.lastStopReason = message.stopReason;
			this.lastErrorMessage = message.errorMessage;
			if (message.stopReason === "error" && message.errorMessage) {
				this.push({ kind: "error", text: message.errorMessage });
			}
		}
		this.options.onChange(this);
	}

	private async onUiRequest(request: UiRequest): Promise<void> {
		// Notifications, status text, widgets and titles from the child's extensions are dropped.
		if (!DIALOG_METHODS.has(request.method)) return;
		let response: UiResponse;
		try {
			response = await this.options.onUiRequest(this, request);
		} catch {
			response = { cancelled: true };
		}
		if (!this.alive || !this.proc) return;
		this.proc.stdin.write(`${JSON.stringify({ type: "extension_ui_response", id: request.id, ...response })}\n`);
	}

	private push(item: TranscriptItem): void {
		this.transcript.push(item);
		if (this.transcript.length > MAX_TRANSCRIPT_ITEMS) this.transcript.splice(0, this.transcript.length - MAX_TRANSCRIPT_ITEMS);
	}

	private onExit(code: number | null): void {
		if (!this.alive) return;
		this.alive = false;
		const error = new Error(this.exitMessage(code));
		for (const pending of this.pending.values()) pending.reject(error);
		this.pending.clear();
		if (this.status === "stopped") {
			this.options.onChange(this);
			return;
		}
		// A process that dies while starting never ran. start() reports that failure to its caller.
		const wasRunning = this.status === "running";
		this.status = "failed";
		this.error = error.message;
		this.activity = undefined;
		this.finishedAt = Date.now();
		this.push({ kind: "error", text: error.message });
		if (wasRunning) {
			this.output = this.lastAssistantText;
			this.finishedRuns++;
			this.options.onChange(this);
			this.options.onRunFinished(this);
		} else {
			this.options.onChange(this);
		}
	}

	private exitMessage(code: number | null): string {
		const stderr = this.stderr.trim().split("\n").slice(-10).join("\n");
		return `pi process exited${code === null ? "" : ` with code ${code}`}${stderr ? `: ${stderr}` : ""}`;
	}
}
