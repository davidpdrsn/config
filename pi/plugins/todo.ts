import type { ExtensionAPI, ExtensionContext, Theme } from "@mariozechner/pi-coding-agent";
import { Text, matchesKey, truncateToWidth } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

const TODO_STATUSES = ["pending", "in_progress", "completed", "cancelled"] as const;
type TodoStatus = (typeof TODO_STATUSES)[number];

interface Todo {
	id: string;
	content: string;
	status: TodoStatus;
}

interface TodoDetails {
	action: "write" | "read";
	todos: Todo[];
	nextId: number;
	summary: string;
	error?: string;
}

const TodoItemSchema = Type.Object({
	id: Type.String({ description: "Stable todo identifier" }),
	content: Type.String({ description: "Task text" }),
	status: Type.Union([
		Type.Literal("pending"),
		Type.Literal("in_progress"),
		Type.Literal("completed"),
		Type.Literal("cancelled"),
	]),
});

const TodoWriteParams = Type.Object({
	todos: Type.Array(TodoItemSchema, {
		description:
			"Full replacement todo list in desired order. Keep exactly one item in_progress whenever practical.",
	}),
});

function isTodoStatus(value: string): value is TodoStatus {
	return (TODO_STATUSES as readonly string[]).includes(value);
}

function cloneTodos(input: Todo[]): Todo[] {
	return input.map((todo) => ({ ...todo }));
}

function nextGeneratedId(seed: number): { id: string; nextSeed: number } {
	return { id: `todo-${seed}`, nextSeed: seed + 1 };
}

function deriveNextId(todos: Todo[], fallback: number): number {
	let next = Math.max(1, fallback);
	for (const todo of todos) {
		const match = /^todo-(\d+)$/.exec(todo.id);
		if (!match) continue;
		const parsed = Number.parseInt(match[1] ?? "", 10);
		if (Number.isFinite(parsed)) {
			next = Math.max(next, parsed + 1);
		}
	}
	return next;
}

function summarizeTodos(todos: Todo[]): string {
	const total = todos.length;
	const completed = todos.filter((todo) => todo.status === "completed").length;
	const inProgress = todos.filter((todo) => todo.status === "in_progress").length;
	const pending = todos.filter((todo) => todo.status === "pending").length;
	const cancelled = todos.filter((todo) => todo.status === "cancelled").length;
	return `Todos: ${total} total (${completed} completed, ${inProgress} in progress, ${pending} pending, ${cancelled} cancelled)`;
}

function formatTodoForLLM(todo: Todo): string {
	const marker =
		todo.status === "completed"
			? "[x]"
			: todo.status === "cancelled"
				? "[-]"
				: todo.status === "in_progress"
					? "[~]"
					: "[ ]";
	return `${marker} ${todo.id}: ${todo.content}`;
}

function statusLabel(status: TodoStatus): string {
	switch (status) {
		case "pending":
			return "pending";
		case "in_progress":
			return "in progress";
		case "completed":
			return "completed";
		case "cancelled":
			return "cancelled";
	}
}

function statusIcon(status: TodoStatus, theme: Theme): string {
	switch (status) {
		case "pending":
			return theme.fg("dim", "○");
		case "in_progress":
			return theme.fg("warning", "◐");
		case "completed":
			return theme.fg("success", "✓");
		case "cancelled":
			return theme.fg("muted", "✕");
	}
}

function isExecutionStartPrompt(prompt: string): boolean {
	const trimmed = prompt.trim();
	return (
		trimmed.startsWith("Execution mode begins now. Read ") &&
		trimmed.includes("and execute that approved plan step by step.")
	);
}

function normalizeStoredTodo(raw: unknown): Todo | undefined {
	if (!raw || typeof raw !== "object") return undefined;
	const input = raw as { id?: unknown; content?: unknown; status?: unknown };
	if (typeof input.content !== "string") return undefined;
	const content = input.content.trim();
	if (!content) return undefined;

	const rawStatus = typeof input.status === "string" ? input.status : "pending";
	const status: TodoStatus = isTodoStatus(rawStatus) ? rawStatus : "pending";
	const id = typeof input.id === "string" && input.id.trim().length > 0 ? input.id.trim() : "";

	return { id, content, status };
}

function normalizeIncomingTodos(input: Todo[], seedNextId: number): { todos: Todo[]; nextId: number; error?: string } {
	const normalized: Todo[] = [];
	const seenIds = new Set<string>();
	let nextId = Math.max(1, seedNextId);

	for (let index = 0; index < input.length; index++) {
		const row = input[index];
		const content = row.content.trim();
		if (!content) {
			return {
				todos: [],
				nextId,
				error: `Todo at position ${index + 1} has empty content`,
			};
		}

		let id = row.id.trim();
		if (!id || seenIds.has(id)) {
			const generated = nextGeneratedId(nextId);
			id = generated.id;
			nextId = generated.nextSeed;
		}

		seenIds.add(id);
		normalized.push({
			id,
			content,
			status: row.status,
		});
	}

	return {
		todos: normalized,
		nextId: deriveNextId(normalized, nextId),
	};
}

class TodoListComponent {
	private readonly todos: Todo[];
	private readonly theme: Theme;
	private readonly onClose: () => void;
	private cachedWidth?: number;
	private cachedLines?: string[];

	constructor(todos: Todo[], theme: Theme, onClose: () => void) {
		this.todos = cloneTodos(todos);
		this.theme = theme;
		this.onClose = onClose;
	}

	handleInput(data: string): void {
		if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) {
			this.onClose();
		}
	}

	render(width: number): string[] {
		if (this.cachedLines && this.cachedWidth === width) return this.cachedLines;

		const lines: string[] = [];
		const theme = this.theme;
		const total = this.todos.length;
		const completed = this.todos.filter((todo) => todo.status === "completed").length;
		const inProgress = this.todos.filter((todo) => todo.status === "in_progress").length;

		lines.push("");
		const title = theme.fg("accent", " Todos ");
		const bar = Math.max(0, width - 10);
		lines.push(truncateToWidth(theme.fg("borderMuted", "─".repeat(3)) + title + theme.fg("borderMuted", "─".repeat(bar)), width));
		lines.push("");

		if (total === 0) {
			lines.push(truncateToWidth(`  ${theme.fg("dim", "No todos yet. Ask the agent to create one with todowrite.")}`, width));
		} else {
			lines.push(truncateToWidth(`  ${theme.fg("muted", `${completed}/${total} completed • ${inProgress} in progress`)}`, width));
			lines.push("");
			for (const todo of this.todos) {
				const icon = statusIcon(todo.status, theme);
				const id = theme.fg("accent", todo.id);
				const text =
					todo.status === "completed" || todo.status === "cancelled"
						? theme.fg("dim", todo.content)
						: theme.fg("text", todo.content);
				const status = theme.fg("muted", `(${statusLabel(todo.status)})`);
				lines.push(truncateToWidth(`  ${icon} ${id} ${text} ${status}`, width));
			}
		}

		lines.push("");
		lines.push(truncateToWidth(`  ${theme.fg("dim", "Press Escape to close")}`, width));
		lines.push("");

		this.cachedWidth = width;
		this.cachedLines = lines;
		return lines;
	}

	invalidate(): void {
		this.cachedWidth = undefined;
		this.cachedLines = undefined;
	}
}

function extractTextContent(result: { content?: Array<{ type?: string; text?: string }> }): string {
	const textPart = result.content?.find((part) => part?.type === "text");
	return textPart?.text ?? "";
}

export default function (pi: ExtensionAPI): void {
	let todos: Todo[] = [];
	let nextId = 1;

	const hasOpenTodos = () => todos.some((todo) => todo.status === "pending" || todo.status === "in_progress");

	const updateWidget = (ctx: ExtensionContext) => {
		if (!ctx.hasUI) return;
		if (todos.length === 0) {
			ctx.ui.setWidget("todo-progress", undefined);
			return;
		}

		const completed = todos.filter((todo) => todo.status === "completed").length;
		const inProgress = todos.filter((todo) => todo.status === "in_progress").length;
		ctx.ui.setWidget(
			"todo-progress",
			[`${completed}/${todos.length} completed • ${inProgress} in progress`],
			{ placement: "belowEditor" },
		);
	};

	const reconstructState = (ctx: ExtensionContext) => {
		todos = [];
		nextId = 1;

		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type !== "message") continue;
			const message = entry.message;
			if (message.role !== "toolResult") continue;
			if (message.toolName !== "todowrite" && message.toolName !== "todoread") continue;

			const details = message.details as Partial<TodoDetails> | undefined;
			if (!details || !Array.isArray(details.todos)) continue;

			const restored: Todo[] = [];
			for (const raw of details.todos) {
				const normalized = normalizeStoredTodo(raw);
				if (normalized) restored.push(normalized);
			}

			todos = restored;
			nextId =
				typeof details.nextId === "number" && Number.isFinite(details.nextId) && details.nextId > 0
					? Math.floor(details.nextId)
					: deriveNextId(restored, nextId);
		}

		nextId = deriveNextId(todos, nextId);
		updateWidget(ctx);
	};

	const lifecycleReconstruct = async (_event: unknown, ctx: ExtensionContext) => {
		reconstructState(ctx);
	};

	pi.on("session_start", lifecycleReconstruct);
	pi.on("session_switch", lifecycleReconstruct);
	pi.on("session_fork", lifecycleReconstruct);
	pi.on("session_tree", lifecycleReconstruct);

	pi.registerTool({
		name: "todowrite",
		label: "Todo Write",
		description:
			"Create or update the full todo list. Use this when implementing plans, keep items ordered, and prefer exactly one item in_progress.",
		parameters: TodoWriteParams,
		renderCall(args, theme) {
			const todoCount = Array.isArray(args.todos) ? args.todos.length : 0;
			const label = `${theme.fg("toolTitle", theme.bold("todowrite"))} ${theme.fg("muted", `${todoCount} item(s)`)}`;
			return new Text(label, 0, 0);
		},
		renderResult(result, { expanded }, theme) {
			const details = result.details as TodoDetails | undefined;
			if (!details) return new Text(extractTextContent(result), 0, 0);
			if (details.error) return new Text(theme.fg("error", `Error: ${details.error}`), 0, 0);

			const lines: string[] = [theme.fg("success", "✓ ") + theme.fg("muted", details.summary)];
			const display = expanded ? details.todos : details.todos.slice(0, 6);
			for (const todo of display) {
				const icon = statusIcon(todo.status, theme);
				const content =
					todo.status === "completed" || todo.status === "cancelled"
						? theme.fg("dim", todo.content)
						: theme.fg("muted", todo.content);
				lines.push(`${icon} ${theme.fg("accent", todo.id)} ${content}`);
			}
			if (!expanded && details.todos.length > display.length) {
				lines.push(theme.fg("dim", `... ${details.todos.length - display.length} more`));
			}

			return new Text(lines.join("\n"), 0, 0);
		},
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const incomingTodos = params.todos as Todo[];
			const normalized = normalizeIncomingTodos(incomingTodos, nextId);
			if (normalized.error) {
				const details: TodoDetails = {
					action: "write",
					todos: cloneTodos(todos),
					nextId,
					summary: summarizeTodos(todos),
					error: normalized.error,
				};
				return {
					content: [{ type: "text", text: `Error: ${normalized.error}` }],
					details,
				};
			}

			todos = normalized.todos;
			nextId = normalized.nextId;
			updateWidget(ctx);

			const summary = summarizeTodos(todos);
			const details: TodoDetails = {
				action: "write",
				todos: cloneTodos(todos),
				nextId,
				summary,
			};
			const preview = todos.length > 0 ? `\n${todos.map(formatTodoForLLM).join("\n")}` : "\nNo todos";
			return {
				content: [{ type: "text", text: `${summary}${preview}` }],
				details,
			};
		},
	});

	pi.registerTool({
		name: "todoread",
		label: "Todo Read",
		description: "Read the current todo list for this branch.",
		parameters: Type.Object({}),
		renderCall(_args, theme) {
			return new Text(theme.fg("toolTitle", theme.bold("todoread")), 0, 0);
		},
		renderResult(result, { expanded }, theme) {
			const details = result.details as TodoDetails | undefined;
			if (!details) return new Text(extractTextContent(result), 0, 0);

			const lines: string[] = [theme.fg("muted", details.summary)];
			if (details.todos.length === 0) {
				lines.push(theme.fg("dim", "No todos"));
				return new Text(lines.join("\n"), 0, 0);
			}

			const display = expanded ? details.todos : details.todos.slice(0, 6);
			for (const todo of display) {
				const icon = statusIcon(todo.status, theme);
				const content =
					todo.status === "completed" || todo.status === "cancelled"
						? theme.fg("dim", todo.content)
						: theme.fg("muted", todo.content);
				lines.push(`${icon} ${theme.fg("accent", todo.id)} ${content}`);
			}
			if (!expanded && details.todos.length > display.length) {
				lines.push(theme.fg("dim", `... ${details.todos.length - display.length} more`));
			}
			return new Text(lines.join("\n"), 0, 0);
		},
		async execute() {
			const summary = summarizeTodos(todos);
			const details: TodoDetails = {
				action: "read",
				todos: cloneTodos(todos),
				nextId,
				summary,
			};
			const preview = todos.length > 0 ? `\n${todos.map(formatTodoForLLM).join("\n")}` : "\nNo todos";
			return {
				content: [{ type: "text", text: `${summary}${preview}` }],
				details,
			};
		},
	});

	pi.registerCommand("todos", {
		description: "Show all todos on the current branch",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) {
				ctx.ui.notify("/todos requires interactive mode", "error");
				return;
			}

			await ctx.ui.custom<void>((_tui, theme, _kb, done) => new TodoListComponent(todos, theme, () => done()));
		},
	});

	pi.on("before_agent_start", async (event) => {
		if (!isExecutionStartPrompt(event.prompt)) return;

		const todoReminder = hasOpenTodos()
			? "[Todo checklist reminder]\n- You are entering implementation after planning (`go`). Keep the todo list current with `todowrite` as you complete steps.\n- Keep exactly one item `in_progress` whenever practical."
			: "[Todo checklist reminder]\n- You are entering implementation after planning (`go`). FIRST, call `todowrite` to create/update the plan execution checklist before making edits.\n- Then keep it updated as you progress, with at most one item `in_progress` whenever practical.";

		return {
			systemPrompt: `${event.systemPrompt}\n\n${todoReminder}`,
		};
	});
}
